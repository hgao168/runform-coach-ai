import asyncio
import os
import json
import random
import string
from datetime import datetime, timezone
from functools import wraps
from urllib.parse import urlencode

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from sqlalchemy import delete, func, select

from .analyzer import analyze_from_metrics, analyze_running_video, generate_plan
from .athletes import compare_with_athlete, get_all_athletes
from .db import check_database, get_db_session
from .db_models import InviteCode, ChallengeParticipant, CoachCode, CoachStudent, OAuthConnection, RunSession, StravaRun, StravaWeeklyStat, User, _MAX_INVITE_CODES_PER_USER, _FOURTEEN_DAY_CHALLENGE_ID
from .schemas import (
    AnalyzeProfileContext,
    AnalysisResponse,
    AthleteListItem,
    ChallengeCheckInRequest,
    ChallengeCheckInResponse,
    ChallengeInfo,
    ChallengeJoinRequest,
    ChallengeJoinResponse,
    ChallengeLeaderboardEntry,
    ChallengeNotifyRequest,
    ChallengeNotifyResponse,
    ClubLeaderboardEntry,
    ClubLeaderboardResponse,
    CoachCodeGenerateRequest,
    CoachCodeResponse,
    CoachDashboardResponse,
    CoachJoinRequest,
    CoachJoinResponse,
    CoachStudentFormSummary,
    CoachStudentResponse,
    CompareRequest,
    CompareResponse,
    FeedbackSubmitRequest,
    FeedbackSubmitResponse,
    InviteCodeGenerateRequest,
    InviteCodeGenerateResponse,
    InviteRedeemRequest,
    InviteRedeemResponse,
    InviteStatusRedeemedUser,
    InviteStatusCodeItem,
    InviteStatusResponse,
    NotificationItem,
    PoseMetricsInput,
    ProfileSaveRequest,
    ProfileSaveResponse,
    RunSessionCreate,
    RunSessionResponse,
    SessionCompareRequest,
    SessionCompareResponse,
    SessionMetricPair,
    SessionTrendsResponse,
    StravaCallbackResponse,
    StravaConnectResponse,
    StravaDisconnectRequest,
    StravaDisconnectResponse,
    StravaStatusResponse,
    StravaSummaryResponse,
    StravaSyncRequest,
    StravaSyncResponse,
    TrainingPlanInput,
    TrainingPlanResponse,
    WeeklyInsightBadge,
    WeeklyInsightMetric,
    WeeklyInsightResponse,
)
from .strava_sync import sync_strava_runs_for_user
from .strava_summary import build_strava_summary
from .strava_oauth import (
    StravaOAuthConfigError,
    StravaOAuthError,
    app_callback_url,
    build_authorize_url,
    decrypt_secret,
    deauthorize_access_token,
    exchange_code_for_token,
    get_strava_connection,
    upsert_strava_connection,
    verify_state,
)

ENVIRONMENT = os.getenv("ENVIRONMENT", "production")
API_KEY = os.getenv("API_KEY", "")

_PROFILE_FIELDS = [
    "first_name", "last_name", "nickname", "level", "weekly_mileage_km",
    "running_days_per_week", "height_cm", "weight_kg", "target", "injury_note",
    "gender", "shoe_size", "shoe_brand_model", "leg_length_cm", "date_of_birth",
    "weekly_exercise_hours",
]

# ── Rate limiter ──────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address)


async def verify_api_key(x_api_key: str | None = Header(None, alias="X-API-Key")) -> str:
    """Validate API Key from X-API-Key header when API_KEY env var is configured.

    If API_KEY is not set the check is skipped (backward compatibility / dev mode).
    Otherwise the request must carry a matching X-API-Key header.
    """
    if not API_KEY:
        return ""
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API Key")
    return x_api_key


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# Strava endpoints share the same exception-to-HTTP-status mapping. Listed in
# priority order: the first matching class wins.
_STRAVA_ERROR_MAP: tuple[tuple[type[Exception], int], ...] = (
    (LookupError, 404),
    (StravaOAuthConfigError, 503),
    (StravaOAuthError, 400),
    (RuntimeError, 503),
)


def _strava_endpoint(action: str):
    """Decorator that maps Strava-related exceptions to HTTPException.

    Behavior is identical to the previous per-endpoint try/except blocks:
      LookupError              -> 404
      StravaOAuthConfigError   -> 503
      StravaOAuthError         -> 400
      RuntimeError             -> 503
      anything else            -> 500 with "{action}: {exc}"
    HTTPException is re-raised unchanged.
    """
    def decorator(func):
        def _to_http(exc: Exception) -> HTTPException:
            for cls, status in _STRAVA_ERROR_MAP:
                if isinstance(exc, cls):
                    return HTTPException(status_code=status, detail=str(exc))
            return HTTPException(status_code=500, detail=f"{action}. Please try again.")

        if asyncio.iscoroutinefunction(func):
            @wraps(func)
            async def async_wrapper(*args, **kwargs):
                try:
                    return await func(*args, **kwargs)
                except HTTPException:
                    raise
                except Exception as exc:
                    raise _to_http(exc) from exc
            return async_wrapper

        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except HTTPException:
                raise
            except Exception as exc:
                raise _to_http(exc) from exc
        return sync_wrapper

    return decorator

app = FastAPI(title="RunForm Coach AI API", version="0.5.0")

# ── CORS ──────────────────────────────────────────────────────────────────
# Whitelist origins from env; dev includes localhost.  allow_credentials=True
# so cookie-based auth works for allowed origins, but NEVER with wildcard.
_ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "https://movenova.ai,https://runformcoach.com",
).split(",")
# In development, also allow localhost origins
if ENVIRONMENT == "development":
    _ALLOWED_ORIGINS += [
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:8080",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Rate limiter wiring ───────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.get("/health")
def health() -> dict:
    db_status = check_database()
    overall_status = "ok" if db_status.get("status") in {"ok", "not_configured"} else "degraded"
    return {
        "status": overall_status,
        "service": "runform-coach-ai",
        "version": "0.5.0",
        "environment": ENVIRONMENT,
        "db": db_status,
    }


@app.put("/profile", response_model=ProfileSaveResponse)
def save_profile(payload: ProfileSaveRequest, _api_key: str = Depends(verify_api_key)) -> ProfileSaveResponse:
    """Save or update user profile data."""
    try:
        with get_db_session() as session:
            user = session.scalar(select(User).where(User.ios_user_id == payload.ios_user_id))
            if user is None:
                user = User(ios_user_id=payload.ios_user_id)
                session.add(user)
                session.flush()
            for field in _PROFILE_FIELDS:
                value = getattr(payload, field, None)
                if value is not None:
                    setattr(user, field, value)
            session.commit()
        return ProfileSaveResponse(saved=True, ios_user_id=payload.ios_user_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to save profile: {exc}") from exc



@app.post("/training-plan", response_model=TrainingPlanResponse)
@limiter.limit("10/minute")
async def training_plan(request: Request, plan_input: TrainingPlanInput, _api_key: str = Depends(verify_api_key)) -> TrainingPlanResponse:
    """Generate a personalised one-week training plan. planned_weekly_km mirrors current_weekly_km."""
    try:
        return generate_plan(plan_input)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Plan generation error: {exc}") from exc


@app.post("/analyze-metrics", response_model=AnalysisResponse)
@limiter.limit("10/minute")
async def analyze_metrics(request: Request, pose_input: PoseMetricsInput, _api_key: str = Depends(verify_api_key)) -> AnalysisResponse:
    """Preferred path: iOS extracts pose metrics on-device; backend generates coaching advice."""
    try:
        return analyze_from_metrics(pose_input)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Analysis error: {exc}") from exc


@app.post("/analyze", response_model=AnalysisResponse)
@limiter.limit("10/minute")
async def analyze(
    request: Request,
    video: UploadFile = File(...),
    language: str = Form("en"),
    profile_context: str = Form(""),
    _api_key: str = Depends(verify_api_key),
) -> AnalysisResponse:
    """Legacy fallback: upload raw video for frame-based GPT-4o Vision analysis."""
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Please upload a valid video file.")

    parsed_profile: AnalyzeProfileContext | None = None
    if profile_context:
        try:
            parsed_profile = AnalyzeProfileContext(**json.loads(profile_context))
        except Exception as exc:
            raise HTTPException(status_code=400, detail=f"Invalid profile_context JSON: {exc}") from exc

    video_bytes = await video.read()
    return analyze_running_video(
        video_bytes,
        video.filename or "running-video.mp4",
        language=language,
        profile_context=parsed_profile,
    )


@app.get("/athletes", response_model=list[AthleteListItem])
def list_athletes() -> list[AthleteListItem]:
    """Return the list of available elite athlete benchmark profiles."""
    return get_all_athletes()


@app.post("/compare", response_model=CompareResponse)
@limiter.limit("10/minute")
async def compare_legacy(request: Request, payload: CompareRequest, _api_key: str = Depends(verify_api_key)) -> CompareResponse:
    """Backward-compat alias — forwards to /api/v1/compare."""
    return await compare(request, payload, _api_key=_api_key)


@app.post("/api/v1/compare", response_model=CompareResponse)
@limiter.limit("10/minute")
async def compare(request: Request, payload: CompareRequest, _api_key: str = Depends(verify_api_key)) -> CompareResponse:
    """Compare user running metrics against an elite athlete benchmark."""
    try:
        return compare_with_athlete(payload)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Comparison error: {exc}") from exc


@app.post("/api/v1/feedback", response_model=FeedbackSubmitResponse)
def submit_feedback(payload: FeedbackSubmitRequest, _api_key: str = Depends(verify_api_key)) -> FeedbackSubmitResponse:
    """Accept tester feedback on an analysis result for coaching-quality improvement.

    Receives a rating (Accurate / Partly accurate / Not accurate / Confusing)
    and optional comment from the iOS FeedbackView. Stores it for future
    model tuning and coaching quality analysis.
    """
    valid_ratings = {"Accurate", "Partly accurate", "Not accurate", "Confusing"}
    if payload.rating not in valid_ratings:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid rating '{payload.rating}'. Must be one of: {', '.join(sorted(valid_ratings))}",
        )
    import logging
    logger = logging.getLogger(__name__)
    logger.info(
        "Feedback received — ios_user_id=%s analysis_id=%s rating=%s comment_len=%d",
        payload.ios_user_id, payload.analysis_id, payload.rating, len(payload.comment),
    )
    return FeedbackSubmitResponse(
        accepted=True,
        message="Thank you! Your feedback helps us improve coaching accuracy.",
    )


# ── Run Session CRUD ─────────────────────────────────────────────────────────


def _resolve_user(session, ios_user_id: str):
    """Look up a User by ios_user_id or raise 404."""
    user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))
    if user is None:
        raise HTTPException(status_code=404, detail=f"User '{ios_user_id}' not found.")
    return user


def _session_to_response(session_row: RunSession, ios_user_id: str | None = None) -> RunSessionResponse:
    return RunSessionResponse(
        id=session_row.id,
        user_id=session_row.user_id,
        ios_user_id=ios_user_id,
        start_time=session_row.start_time.isoformat(),
        end_time=session_row.end_time.isoformat() if session_row.end_time else None,
        duration_sec=session_row.duration_sec,
        avg_cadence=session_row.avg_cadence,
        avg_vertical_oscillation=session_row.avg_vertical_oscillation,
        avg_gct=session_row.avg_gct,
        metrics_json=session_row.metrics_json,
        created_at=session_row.created_at.isoformat(),
    )


@app.post("/api/v1/sessions", response_model=RunSessionResponse, status_code=201)
def create_session(payload: RunSessionCreate, _api_key: str = Depends(verify_api_key)) -> RunSessionResponse:
    """Create a new run session with metrics snapshot."""
    from datetime import datetime as _dt
    from datetime import timezone as _tz

    try:
        with get_db_session() as session:
            user = _resolve_user(session, payload.ios_user_id)

            start_dt = _dt.fromisoformat(payload.start_time)
            end_dt = _dt.fromisoformat(payload.end_time) if payload.end_time else None

            run = RunSession(
                user_id=user.id,
                start_time=start_dt,
                end_time=end_dt,
                duration_sec=payload.duration_sec,
                avg_cadence=payload.avg_cadence,
                avg_vertical_oscillation=payload.avg_vertical_oscillation,
                avg_gct=payload.avg_gct,
                metrics_json=payload.metrics_json,
            )
            session.add(run)
            session.commit()
            session.refresh(run)

        return _session_to_response(run, ios_user_id=payload.ios_user_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to create session: {exc}") from exc


@app.get("/api/v1/sessions", response_model=list[RunSessionResponse])
def list_sessions(
    ios_user_id: str = Query(..., min_length=3),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    _api_key: str = Depends(verify_api_key),
) -> list[RunSessionResponse]:
    """List run sessions for a user, paginated, newest first."""
    try:
        with get_db_session() as session:
            user = _resolve_user(session, ios_user_id)
            rows = session.execute(
                select(RunSession)
                .where(RunSession.user_id == user.id)
                .order_by(RunSession.start_time.desc())
                .limit(limit)
                .offset(offset)
            ).scalars().all()
        return [_session_to_response(r, ios_user_id=ios_user_id) for r in rows]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list sessions: {exc}") from exc


@app.get("/api/v1/sessions/trends", response_model=SessionTrendsResponse)
def session_trends(
    ios_user_id: str = Query(..., min_length=3),
    metrics: str = Query("cadence,oscillation,gct"),
    limit: int = Query(20, ge=1, le=100),
    _api_key: str = Depends(verify_api_key),
) -> SessionTrendsResponse:
    """Return trend arrays for key metrics across the most recent sessions."""
    try:
        with get_db_session() as session:
            user = _resolve_user(session, ios_user_id)
            rows = session.execute(
                select(RunSession)
                .where(RunSession.user_id == user.id)
                .order_by(RunSession.start_time.desc())
                .limit(limit)
            ).scalars().all()

        requested = {m.strip().lower() for m in metrics.split(",")}
        cadence_vals = []
        osc_vals = []
        gct_vals = []

        for r in reversed(rows):  # chronological order
            if "cadence" in requested:
                cadence_vals.append(r.avg_cadence)
            if "oscillation" in requested:
                osc_vals.append(r.avg_vertical_oscillation)
            if "gct" in requested:
                gct_vals.append(r.avg_gct)

        return SessionTrendsResponse(
            ios_user_id=ios_user_id,
            session_count=len(rows),
            cadence=cadence_vals,
            vertical_oscillation=osc_vals,
            gct=gct_vals,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to compute trends: {exc}") from exc


@app.post("/api/v1/sessions/compare", response_model=SessionCompareResponse)
def compare_sessions(payload: SessionCompareRequest, _api_key: str = Depends(verify_api_key)) -> SessionCompareResponse:
    """Compare two run sessions side-by-side."""
    try:
        with get_db_session() as session:
            user = _resolve_user(session, payload.ios_user_id)

            a = session.scalar(
                select(RunSession).where(
                    RunSession.id == payload.session_id_a,
                    RunSession.user_id == user.id,
                )
            )
            b = session.scalar(
                select(RunSession).where(
                    RunSession.id == payload.session_id_b,
                    RunSession.user_id == user.id,
                )
            )

            if a is None:
                raise HTTPException(status_code=404, detail=f"Session {payload.session_id_a} not found.")
            if b is None:
                raise HTTPException(status_code=404, detail=f"Session {payload.session_id_b} not found.")

        def _delta_pct(va, vb) -> float | None:
            if va is not None and vb is not None and vb != 0:
                return round((va - vb) / abs(vb) * 100, 1)
            return None

        comparisons = [
            SessionMetricPair(
                metric="avg_cadence",
                session_a_value=a.avg_cadence,
                session_b_value=b.avg_cadence,
                delta=round(a.avg_cadence - b.avg_cadence, 1) if a.avg_cadence is not None and b.avg_cadence is not None else None,
                delta_pct=_delta_pct(a.avg_cadence, b.avg_cadence),
            ),
            SessionMetricPair(
                metric="avg_vertical_oscillation",
                session_a_value=a.avg_vertical_oscillation,
                session_b_value=b.avg_vertical_oscillation,
                delta=round(a.avg_vertical_oscillation - b.avg_vertical_oscillation, 4) if a.avg_vertical_oscillation is not None and b.avg_vertical_oscillation is not None else None,
                delta_pct=_delta_pct(a.avg_vertical_oscillation, b.avg_vertical_oscillation),
            ),
            SessionMetricPair(
                metric="avg_gct",
                session_a_value=a.avg_gct,
                session_b_value=b.avg_gct,
                delta=round(a.avg_gct - b.avg_gct, 4) if a.avg_gct is not None and b.avg_gct is not None else None,
                delta_pct=_delta_pct(a.avg_gct, b.avg_gct),
            ),
            SessionMetricPair(
                metric="duration_sec",
                session_a_value=a.duration_sec,
                session_b_value=b.duration_sec,
                delta=round(a.duration_sec - b.duration_sec, 1) if a.duration_sec is not None and b.duration_sec is not None else None,
                delta_pct=_delta_pct(a.duration_sec, b.duration_sec),
            ),
        ]

        return SessionCompareResponse(
            ios_user_id=payload.ios_user_id,
            session_a=_session_to_response(a, ios_user_id=payload.ios_user_id),
            session_b=_session_to_response(b, ios_user_id=payload.ios_user_id),
            comparisons=comparisons,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to compare sessions: {exc}") from exc


@app.get("/api/v1/sessions/{session_id}", response_model=RunSessionResponse)
def get_session(session_id: int, ios_user_id: str = Query(..., min_length=3), _api_key: str = Depends(verify_api_key)) -> RunSessionResponse:
    """Get a single run session by ID with full metrics."""
    try:
        with get_db_session() as session:
            user = _resolve_user(session, ios_user_id)
            run = session.scalar(
                select(RunSession).where(
                    RunSession.id == session_id,
                    RunSession.user_id == user.id,
                )
            )
            if run is None:
                raise HTTPException(status_code=404, detail=f"Session {session_id} not found.")
        return _session_to_response(run, ios_user_id=ios_user_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to get session: {exc}") from exc


@app.delete("/api/v1/sessions/{session_id}", status_code=204)
def delete_session(session_id: int, ios_user_id: str = Query(..., min_length=3), _api_key: str = Depends(verify_api_key)):
    """Delete a run session."""
    try:
        with get_db_session() as session:
            user = _resolve_user(session, ios_user_id)
            run = session.scalar(
                select(RunSession).where(
                    RunSession.id == session_id,
                    RunSession.user_id == user.id,
                )
            )
            if run is None:
                raise HTTPException(status_code=404, detail=f"Session {session_id} not found.")
            session.delete(run)
            session.commit()
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to delete session: {exc}") from exc


# ── Weekly Insight ────────────────────────────────────────────────────────

@app.get("/api/v1/weekly-insight", response_model=WeeklyInsightResponse)
def weekly_insight(ios_user_id: str = Query(..., min_length=3), _api_key: str = Depends(verify_api_key)) -> WeeklyInsightResponse:
    """Return this-week vs last-week comparison, AI coach advice, and badges.

    Compatible with iOS RF-911 and Android RF-912 WeeklyInsight screens.
    Aggregates session metrics over the current and previous calendar week
    (Monday–Sunday) and derives trends plus a coaching narrative.
    """
    from datetime import datetime, timedelta, timezone as _tz

    try:
        with get_db_session() as session:
            user = _resolve_user(session, ios_user_id)

            # Determine current calendar week (Monday–Sunday)
            now = datetime.now(tz=_tz.utc)
            monday = now - timedelta(days=now.weekday())
            monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
            sunday = monday + timedelta(days=6, hours=23, minutes=59, seconds=59)
            prev_monday = monday - timedelta(days=7)
            prev_sunday = monday - timedelta(seconds=1)

            # Fetch all sessions from the last 30 days (covers both weeks generously)
            cutoff = prev_monday - timedelta(days=7)
            all_rows = session.execute(
                select(RunSession)
                .where(
                    RunSession.user_id == user.id,
                    RunSession.start_time >= cutoff,
                )
                .order_by(RunSession.start_time.asc())
            ).scalars().all()

        # Split into this-week and last-week
        this_week = [r for r in all_rows if monday <= r.start_time <= sunday]
        last_week = [r for r in all_rows if prev_monday <= r.start_time <= prev_sunday]

        def _avg(values, attr):
            vals = [getattr(v, attr) for v in values if getattr(v, attr) is not None]
            return round(sum(vals) / len(vals), 2) if vals else None

        def _delta_pct(cur, prev):
            if cur is not None and prev is not None and prev != 0:
                return round((cur - prev) / abs(prev) * 100, 1)
            return None

        def _trend(delta_pct_val, metric_name):
            if delta_pct_val is None:
                return 'stable'
            # For cadence ↑ is improving; for oscillation/GCT ↓ is improving
            higher_is_better = metric_name in ('avg_cadence', 'distance', 'session_count')
            if delta_pct_val > 0:
                return 'improving' if higher_is_better else 'declining'
            elif delta_pct_val < 0:
                return 'declining' if higher_is_better else 'improving'
            return 'stable'

        # Compute this-week and last-week averages
        tw_cadence = _avg(this_week, 'avg_cadence')
        tw_osc = _avg(this_week, 'avg_vertical_oscillation')
        tw_gct = _avg(this_week, 'avg_gct')
        tw_distance = sum(r.duration_sec or 0 for r in this_week)  # proxy: total seconds
        tw_sessions = len(this_week)

        lw_cadence = _avg(last_week, 'avg_cadence')
        lw_osc = _avg(last_week, 'avg_vertical_oscillation')
        lw_gct = _avg(last_week, 'avg_gct')
        lw_distance = sum(r.duration_sec or 0 for r in last_week)
        lw_sessions = len(last_week)

        metrics = [
            WeeklyInsightMetric(
                metric='avg_cadence', label='Cadence (spm)',
                current_week_avg=tw_cadence, previous_week_avg=lw_cadence,
                delta=round(tw_cadence - lw_cadence, 1) if tw_cadence is not None and lw_cadence is not None else None,
                delta_pct=_delta_pct(tw_cadence, lw_cadence),
                trend=_trend(_delta_pct(tw_cadence, lw_cadence), 'avg_cadence'),
            ),
            WeeklyInsightMetric(
                metric='avg_vertical_oscillation', label='Vert. Osc. (cm)',
                current_week_avg=tw_osc, previous_week_avg=lw_osc,
                delta=round(tw_osc - lw_osc, 4) if tw_osc is not None and lw_osc is not None else None,
                delta_pct=_delta_pct(tw_osc, lw_osc),
                trend=_trend(_delta_pct(tw_osc, lw_osc), 'avg_vertical_oscillation'),
            ),
            WeeklyInsightMetric(
                metric='avg_gct', label='GCT (ms)',
                current_week_avg=tw_gct, previous_week_avg=lw_gct,
                delta=round(tw_gct - lw_gct, 4) if tw_gct is not None and lw_gct is not None else None,
                delta_pct=_delta_pct(tw_gct, lw_gct),
                trend=_trend(_delta_pct(tw_gct, lw_gct), 'avg_gct'),
            ),
            WeeklyInsightMetric(
                metric='session_count', label='Sessions',
                current_week_avg=float(tw_sessions), previous_week_avg=float(lw_sessions),
                delta=float(tw_sessions - lw_sessions),
                delta_pct=_delta_pct(float(tw_sessions), float(lw_sessions)),
                trend=_trend(_delta_pct(float(tw_sessions), float(lw_sessions)) if lw_sessions else None, 'session_count'),
            ),
        ]

        # AI coach advice — rule-based narrative from trends
        improving = [m for m in metrics if m.trend == 'improving']
        declining = [m for m in metrics if m.trend == 'declining']

        if not this_week:
            advice = "No sessions recorded this week. Get out there and log your first run to see your weekly insights!"
        elif not last_week:
            advice = "This is your first week with RunForm — great start! Keep logging sessions to unlock trend comparisons next week."
        elif improving and not declining:
            labels = ', '.join(m.label for m in improving)
            advice = f"Great progress this week! Your {labels} show clear improvement. Keep up the consistent training."
        elif declining and not improving:
            labels = ', '.join(m.label for m in declining)
            advice = f"Your {labels} have dipped this week. Consider adding an extra recovery day or checking your running form. Consistency beats intensity."
        elif improving and declining:
            up_labels = ', '.join(m.label for m in improving)
            down_labels = ', '.join(m.label for m in declining)
            advice = f"Mixed trends: {up_labels} are improving, but {down_labels} need attention. Focus on form drills and stay consistent with your weekly volume."
        else:
            advice = "Steady week! All metrics are holding stable. Stay consistent with your training and consider adding one quality session."

        # Badges — simple rule-based awards
        badges = []
        if tw_sessions >= 3:
            badges.append(WeeklyInsightBadge(
                id='consistency_3', name='Consistency Star', icon='⭐',
                description='Logged 3+ sessions this week',
            ))
        if tw_sessions >= 5:
            badges.append(WeeklyInsightBadge(
                id='consistency_5', name='Dedicated Runner', icon='🏃',
                description='Logged 5+ sessions this week',
            ))
        if tw_cadence and tw_cadence >= 170:
            badges.append(WeeklyInsightBadge(
                id='cadence_170', name='High Cadence', icon='⚡',
                description=f'Average cadence {tw_cadence:.0f} spm — elite territory!',
            ))
        if lw_sessions == 0 and tw_sessions >= 1:
            badges.append(WeeklyInsightBadge(
                id='first_week', name='First Week', icon='🎉',
                description='Welcome to RunForm! Your first tracked week.',
            ))

        return WeeklyInsightResponse(
            ios_user_id=ios_user_id,
            week_start=monday.date().isoformat(),
            week_end=sunday.date().isoformat(),
            current_week_session_count=tw_sessions,
            previous_week_session_count=lw_sessions,
            metrics=metrics,
            ai_coach_advice=advice,
            badges=badges,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to compute weekly insight: {exc}") from exc


# ── Strava Integration ─────────────────────────────────────────────────────

@app.get("/integrations/strava/connect", response_model=StravaConnectResponse)
@_strava_endpoint("Failed to create Strava connect URL")
def strava_connect(ios_user_id: str = Query(..., min_length=3)) -> StravaConnectResponse:
    """Build a Strava OAuth authorize URL for a specific iOS user identifier."""
    payload = build_authorize_url(ios_user_id=ios_user_id)
    return StravaConnectResponse(**payload)


@app.get("/integrations/strava/callback", response_model=StravaCallbackResponse)
@_strava_endpoint("Strava callback failed")
async def strava_callback(code: str | None = None, state: str | None = None, error: str | None = None):
    """Handle Strava OAuth callback, exchange code for tokens, and persist encrypted credentials."""
    if error:
        raise HTTPException(status_code=400, detail=f"Strava OAuth error: {error}")
    if not code or not state:
        raise HTTPException(status_code=400, detail="Missing required callback parameters: code and state.")

    ios_user_id = verify_state(state)
    token_payload = await exchange_code_for_token(code)
    provider_athlete_id = None
    with get_db_session() as session:
        connection = upsert_strava_connection(session, ios_user_id=ios_user_id, token_payload=token_payload)
        session.commit()
        provider_athlete_id = connection.provider_athlete_id

    if app_url := app_callback_url():
        query = urlencode({
            "status": "connected",
            "ios_user_id": ios_user_id,
            "provider": "strava",
            "provider_athlete_id": provider_athlete_id,
        })
        return RedirectResponse(url=f"{app_url}?{query}")

    return StravaCallbackResponse(
        connected=True,
        ios_user_id=ios_user_id,
        provider_athlete_id=provider_athlete_id,
    )


@app.get("/integrations/strava/status", response_model=StravaStatusResponse)
@_strava_endpoint("Failed to get Strava status")
def strava_status(ios_user_id: str = Query(..., min_length=3)) -> StravaStatusResponse:
    """Return Strava connection status for a given iOS user identifier."""
    with get_db_session() as session:
        conn = get_strava_connection(session, ios_user_id=ios_user_id)
        if conn is None:
            return StravaStatusResponse(connected=False)

        return StravaStatusResponse(
            connected=True,
            provider_athlete_id=conn.provider_athlete_id,
            scope=conn.scope,
            expires_at=conn.expires_at.isoformat() if conn.expires_at else None,
            last_refresh_at=conn.last_refresh_at.isoformat() if conn.last_refresh_at else None,
        )


@app.post("/integrations/strava/sync", response_model=StravaSyncResponse)
@_strava_endpoint("Failed to sync Strava")
async def strava_sync(payload: StravaSyncRequest) -> StravaSyncResponse:
    """Import recent Strava runs and refresh weekly aggregates for plan generation."""
    with get_db_session() as session:
        result = await sync_strava_runs_for_user(session, ios_user_id=payload.ios_user_id)
        session.commit()

    return StravaSyncResponse(
        connected=True,
        ios_user_id=result["ios_user_id"],
        lookback_days=result["lookback_days"],
        scanned_activity_count=result["scanned_activity_count"],
        synced_run_count=result["synced_run_count"],
        week_count=result["week_count"],
        synced_at=_utc_now_iso(),
        weekly_stats=result["weekly_stats"],
        prefilled_profile=result.get("prefilled_profile") or None,
    )


@app.get("/integrations/strava/summary", response_model=StravaSummaryResponse)
@_strava_endpoint("Failed to get Strava summary")
def strava_summary(
    ios_user_id: str = Query(..., min_length=3),
    weeks: int = Query(8, ge=1, le=12),
) -> StravaSummaryResponse:
    """Return the Strava training summary used by the plan page."""
    with get_db_session() as session:
        result = build_strava_summary(session, ios_user_id=ios_user_id, weeks=weeks)

    return StravaSummaryResponse(
        connected=True,
        ios_user_id=result["ios_user_id"],
        weeks=result["weeks"],
        weekly_stats=result["weekly_stats"],
        total_distance_km=result["total_distance_km"],
        average_weekly_km=result["average_weekly_km"],
        run_count=result["run_count"],
        longest_run_km=result["longest_run_km"],
        avg_pace_s_per_km=result["avg_pace_s_per_km"],
        intensity_estimate=result["intensity_estimate"],
        load_trend=result["load_trend"],
        trend_delta_pct=result["trend_delta_pct"],
        last_sync_at=result["last_sync_at"],
    )


@app.post("/integrations/strava/disconnect", response_model=StravaDisconnectResponse)
@_strava_endpoint("Failed to disconnect Strava")
async def strava_disconnect(payload: StravaDisconnectRequest) -> StravaDisconnectResponse:
    """Disconnect Strava, revoke access when possible, and delete imported Strava data."""
    with get_db_session() as session:
        conn: OAuthConnection | None = get_strava_connection(session, ios_user_id=payload.ios_user_id)
        user = session.scalar(select(User).where(User.ios_user_id == payload.ios_user_id))

        revoked = False
        revoke_error: str | None = None
        if conn is not None:
            access_token = decrypt_secret(conn.access_token_encrypted)
            try:
                await deauthorize_access_token(access_token)
                revoked = True
            except StravaOAuthError as exc:
                revoke_error = str(exc)

        deleted_run_count = 0
        deleted_weekly_stat_count = 0
        if user is not None:
            deleted_run_count = session.execute(delete(StravaRun).where(StravaRun.user_id == user.id)).rowcount or 0
            deleted_weekly_stat_count = (
                session.execute(delete(StravaWeeklyStat).where(StravaWeeklyStat.user_id == user.id)).rowcount or 0
            )

        if conn is not None:
            session.delete(conn)

        session.commit()

    if revoke_error:
        message = f"Strava data deleted. Token revocation failed: {revoke_error}"
    elif conn is None:
        message = "Strava data deleted. No active connection was found."
    else:
        message = "Strava disconnected and imported data deleted."

    return StravaDisconnectResponse(
        ios_user_id=payload.ios_user_id,
        revoked=revoked,
        deleted_run_count=deleted_run_count,
        deleted_weekly_stat_count=deleted_weekly_stat_count,
        message=message,
    )


# ═══════════════════════════════════════════════════════════════════════════
# RF-600  Invite Code System  ──────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════

_ALPHANUMERIC = string.ascii_uppercase + string.digits


def _generate_invite_code() -> str:
    """Generate a unique 8-character alphanumeric invite code."""
    return ''.join(random.choices(_ALPHANUMERIC, k=8))


@app.post("/api/v1/invite/generate", response_model=InviteCodeGenerateResponse)
def generate_invite(payload: InviteCodeGenerateRequest, _api_key: str = Depends(verify_api_key)) -> InviteCodeGenerateResponse:
    """Generate a unique 8-character invite code. Each user can create up to 5 codes."""
    try:
        with get_db_session() as session:
            user = _resolve_user(session, payload.user_id)

            active_codes = session.execute(
                select(InviteCode).where(
                    InviteCode.creator_user_id == user.id,
                    InviteCode.redeemed_by.is_(None),
                )
            ).scalars().all()
            if len(active_codes) >= _MAX_INVITE_CODES_PER_USER:
                raise HTTPException(
                    status_code=429,
                    detail=f"You have reached the maximum of {_MAX_INVITE_CODES_PER_USER} active invite codes.",
                )

            # Generate unique codes, retrying on collision
            for _ in range(20):
                code = _generate_invite_code()
                existing = session.scalar(select(InviteCode).where(InviteCode.code == code))
                if existing is None:
                    break
            else:
                raise HTTPException(status_code=500, detail="Failed to generate unique invite code. Please try again.")

            invite = InviteCode(
                code=code,
                creator_user_id=user.id,
            )
            session.add(invite)
            session.commit()
            session.refresh(invite)

            remaining = _MAX_INVITE_CODES_PER_USER - len(active_codes) - 1
            return InviteCodeGenerateResponse(
                code=invite.code,
                created_at=invite.created_at.isoformat(),
                remaining=remaining,
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate invite code: {exc}") from exc


@app.get("/api/v1/invite/{code}")
def verify_invite(code: str) -> dict:
    """Verify if an invite code is valid and unredeemed."""
    try:
        with get_db_session() as session:
            invite = session.scalar(select(InviteCode).where(InviteCode.code == code.upper()))
            if invite is None:
                return {"valid": False, "reason": "Code not found"}
            if invite.redeemed_by is not None:
                return {"valid": False, "reason": "Already redeemed"}
            return {
                "valid": True,
                "code": invite.code,
                "created_at": invite.created_at.isoformat(),
            }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to verify invite code: {exc}") from exc


@app.post("/api/v1/invite/redeem", response_model=InviteRedeemResponse)
def redeem_invite(payload: InviteRedeemRequest, _api_key: str = Depends(verify_api_key)) -> InviteRedeemResponse:
    """Redeem an invite code. Both creator and redeemer get reward markers."""

    try:
        with get_db_session() as session:
            user = _resolve_user(session, payload.user_id)
            code = payload.code.strip().upper()

            invite = session.scalar(select(InviteCode).where(InviteCode.code == code))
            if invite is None:
                raise HTTPException(status_code=404, detail="Invite code not found.")
            if invite.redeemed_by is not None:
                raise HTTPException(status_code=400, detail="This invite code has already been redeemed.")
            if invite.creator_user_id == user.id:
                raise HTTPException(status_code=400, detail="You cannot redeem your own invite code.")

            # Check if redeemer has already redeemed a code
            already_redeemed = session.scalar(
                select(func.count()).select_from(InviteCode).where(InviteCode.redeemed_by == user.id)
            ) or 0
            if already_redeemed > 0:
                raise HTTPException(status_code=400, detail="You have already redeemed an invite code.")

            invite.redeemed_by = user.id
            invite.redeemed_at = datetime.now(timezone.utc)
            session.commit()

            # Reward markers — logged for future gamification
            import logging
            logger = logging.getLogger(__name__)
            logger.info(
                "Invite redeemed — code=%s creator_user_id=%s redeemer_user_id=%s",
                code, invite.creator_user_id, user.id,
            )

            return InviteRedeemResponse(success=True, message="Invite code redeemed! Both you and your friend earned rewards.")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to redeem invite code: {exc}") from exc


@app.get("/api/v1/invite/status", response_model=InviteStatusResponse)
def invite_status(user_id: str = Query(..., min_length=3, description="iOS user identifier"), _api_key: str = Depends(verify_api_key)) -> InviteStatusResponse:
    """Return the user's active invite codes and the list of users who redeemed them.

    Called by WeChat invite.js onLoad to populate the invite sharing screen.
    """
    try:
        with get_db_session() as session:
            user = _resolve_user(session, user_id)

            # Fetch all active invite codes created by this user
            codes = session.execute(
                select(InviteCode).where(
                    InviteCode.creator_user_id == user.id,
                    InviteCode.is_active.is_(True),
                ).order_by(InviteCode.created_at.desc())
            ).scalars().all()

            code_items: list[InviteStatusCodeItem] = []
            total_invited = 0

            for invite in codes:
                redeemed_users: list[InviteStatusRedeemedUser] = []
                if invite.redeemed_by is not None:
                    redeemer = session.scalar(select(User).where(User.id == invite.redeemed_by))
                    redeemed_users.append(InviteStatusRedeemedUser(
                        nickname=redeemer.nickname if redeemer else None,
                        joined_at=invite.redeemed_at.isoformat() if invite.redeemed_at else invite.created_at.isoformat(),
                    ))
                    total_invited += 1

                code_items.append(InviteStatusCodeItem(
                    code=invite.code,
                    created_at=invite.created_at.isoformat(),
                    redeemed_count=1 if invite.redeemed_by is not None else 0,
                    redeemed_users=redeemed_users,
                ))

            return InviteStatusResponse(
                codes=code_items,
                total_invited=total_invited,
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to get invite status: {exc}") from exc


# ═══════════════════════════════════════════════════════════════════════════
# RF-601  Challenge Platform API ───────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════

_CHALLENGES = {
    _FOURTEEN_DAY_CHALLENGE_ID: {
        "id": _FOURTEEN_DAY_CHALLENGE_ID,
        "name": "14-Day Running Form Challenge",
        "description": (
            "Improve your running form in 14 days! Track your cadence and "
            "vertical oscillation improvements. Top improvers earn badges and rewards."
        ),
        "start_date": "2026-05-18",
        "end_date": "2026-06-01",
    },
}


@app.get("/api/v1/challenges", response_model=list[ChallengeInfo])
def list_challenges(
    ios_user_id: str | None = Query(None, min_length=3),
) -> list[ChallengeInfo]:
    """Return all challenges. Optionally include personal participation state when ios_user_id is provided."""
    try:
        with get_db_session() as session:
            # N3: Optionally resolve the requesting user
            user = None
            if ios_user_id:
                user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))

            results = []
            for cid, cdata in _CHALLENGES.items():
                count = session.scalar(
                    select(func.count()).select_from(ChallengeParticipant).where(
                        ChallengeParticipant.challenge_id == cid,
                    )
                ) or 0
                now = datetime.now(timezone.utc)
                end_dt = datetime.fromisoformat(cdata["end_date"]).replace(tzinfo=timezone.utc)
                start_dt = datetime.fromisoformat(cdata["start_date"]).replace(tzinfo=timezone.utc)
                days = (end_dt.date() - start_dt.date()).days
                status = "active" if now <= end_dt else "ended"

                # N3: Personal participation state
                joined = None
                completed_days = None
                today_completed = None
                if user is not None:
                    participant = session.scalar(
                        select(ChallengeParticipant).where(
                            ChallengeParticipant.challenge_id == cid,
                            ChallengeParticipant.user_id == user.id,
                        )
                    )
                    if participant is not None:
                        joined = True
                        completed_days = participant.check_in_count or 0
                        # Check if user completed today
                        if participant.last_check_in is not None:
                            today_completed = participant.last_check_in.date() == now.date()
                        else:
                            today_completed = False
                    else:
                        joined = False
                        completed_days = 0
                        today_completed = False

                results.append(ChallengeInfo(
                    id=cdata["id"],
                    name=cdata["name"],
                    description=cdata["description"],
                    start_date=cdata["start_date"],
                    end_date=cdata["end_date"],
                    days=days,
                    participant_count=count,
                    status=status,
                    joined=joined,
                    completed_days=completed_days,
                    today_completed=today_completed,
                ))
            return results
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list challenges: {exc}") from exc


@app.post("/api/v1/challenges/{challenge_id}/join", response_model=ChallengeJoinResponse)
def join_challenge(challenge_id: str, payload: ChallengeJoinRequest, _api_key: str = Depends(verify_api_key)) -> ChallengeJoinResponse:
    """Join a challenge. Captures baseline metrics from the user's recent run sessions."""
    if challenge_id not in _CHALLENGES:
        raise HTTPException(status_code=404, detail=f"Challenge '{challenge_id}' not found.")

    try:
        with get_db_session() as session:
            user = _resolve_user(session, payload.ios_user_id)

            # Check if already joined
            existing = session.scalar(
                select(ChallengeParticipant).where(
                    ChallengeParticipant.challenge_id == challenge_id,
                    ChallengeParticipant.user_id == user.id,
                )
            )
            if existing is not None:
                return ChallengeJoinResponse(
                    joined=True,
                    challenge_id=challenge_id,
                    message="You have already joined this challenge.",
                )

            # Capture baseline metrics from the user's 3 most recent sessions
            recent_sessions = session.execute(
                select(RunSession)
                .where(RunSession.user_id == user.id)
                .order_by(RunSession.start_time.desc())
                .limit(3)
            ).scalars().all()

            baseline_cadence = None
            baseline_osc = None
            baseline_score = None

            if recent_sessions:
                cadences = [s.avg_cadence for s in recent_sessions if s.avg_cadence is not None]
                oscillations = [s.avg_vertical_oscillation for s in recent_sessions if s.avg_vertical_oscillation is not None]

                if cadences:
                    baseline_cadence = round(sum(cadences) / len(cadences), 2)
                if oscillations:
                    baseline_osc = round(sum(oscillations) / len(oscillations), 4)

                # Composite overall score: normalized cadence + inverted oscillation
                if baseline_cadence and baseline_osc:
                    baseline_score = round(
                        (baseline_cadence / 180.0 * 0.5) + ((0.12 / max(baseline_osc, 0.001)) * 0.5), 3
                    )

            participant = ChallengeParticipant(
                challenge_id=challenge_id,
                user_id=user.id,
                baseline_cadence=baseline_cadence,
                baseline_vertical_oscillation=baseline_osc,
                baseline_overall_score=baseline_score,
            )
            session.add(participant)
            session.commit()

            return ChallengeJoinResponse(
                joined=True,
                challenge_id=challenge_id,
                message="Successfully joined the 14-Day Running Form Challenge! Your baseline metrics have been recorded.",
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to join challenge: {exc}") from exc


@app.get("/api/v1/challenges/{challenge_id}/leaderboard", response_model=list[ChallengeLeaderboardEntry])
def challenge_leaderboard(
    challenge_id: str,
    ios_user_id: str | None = Query(None, min_length=3),
) -> list[ChallengeLeaderboardEntry]:
    """Return the leaderboard sorted by overall improvement magnitude. Optionally mark is_me."""
    if challenge_id not in _CHALLENGES:
        raise HTTPException(status_code=404, detail=f"Challenge '{challenge_id}' not found.")

    try:
        with get_db_session() as session:
            participants = session.execute(
                select(ChallengeParticipant).where(
                    ChallengeParticipant.challenge_id == challenge_id,
                )
            ).scalars().all()

            entries: list[ChallengeLeaderboardEntry] = []

            for p in participants:
                # Get sessions since join date
                recent_sessions = session.execute(
                    select(RunSession)
                    .where(
                        RunSession.user_id == p.user_id,
                        RunSession.start_time >= p.joined_at,
                    )
                    .order_by(RunSession.start_time.desc())
                    .limit(10)
                ).scalars().all()

                # Compute current averages
                cadences = [s.avg_cadence for s in recent_sessions if s.avg_cadence is not None]
                oscillations = [s.avg_vertical_oscillation for s in recent_sessions if s.avg_vertical_oscillation is not None]

                current_cadence = round(sum(cadences) / len(cadences), 2) if cadences else None
                current_osc = round(sum(oscillations) / len(oscillations), 4) if oscillations else None

                # Improvement percentages
                cadence_improvement = None
                osc_improvement = None

                if p.baseline_cadence and current_cadence and p.baseline_cadence > 0:
                    cadence_improvement = round((current_cadence - p.baseline_cadence) / p.baseline_cadence * 100, 1)

                if p.baseline_vertical_oscillation and current_osc and p.baseline_vertical_oscillation > 0:
                    # Lower oscillation is better, so improvement = (baseline - current) / baseline * 100
                    osc_improvement = round((p.baseline_vertical_oscillation - current_osc) / p.baseline_vertical_oscillation * 100, 1)

                # Current overall score
                current_score = None
                if current_cadence and current_osc:
                    current_score = round(
                        (current_cadence / 180.0 * 0.5) + ((0.12 / max(current_osc, 0.001)) * 0.5), 3
                    )

                overall_change = None
                if p.baseline_overall_score is not None and current_score is not None:
                    overall_change = round(current_score - p.baseline_overall_score, 3)

                # Look up ios_user_id
                user = session.scalar(select(User).where(User.id == p.user_id))

                # N4: Compute display_name and is_me
                ios_uid = user.ios_user_id if user else f"user_{p.user_id}"
                display_name = (
                    user.nickname or user.first_name or ios_uid
                ) if user else ios_uid
                is_me = (ios_user_id is not None and ios_user_id == ios_uid)

                entries.append(ChallengeLeaderboardEntry(
                    ios_user_id=ios_uid,
                    cadence_improvement_pct=cadence_improvement,
                    oscillation_improvement_pct=osc_improvement,
                    overall_score_change=overall_change,
                    rank=0,  # placeholder, filled below
                    display_name=display_name,
                    completed_days=p.check_in_count or 0,
                    is_me=is_me,
                ))

            # Sort by overall_score_change descending, then cadence improvement
            entries.sort(
                key=lambda e: (
                    e.overall_score_change if e.overall_score_change is not None else float("-inf")
                ),
                reverse=True,
            )

            # Assign ranks
            for i, entry in enumerate(entries):
                entry.rank = i + 1

            return entries
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to compute leaderboard: {exc}") from exc


@app.post("/api/v1/challenges/{challenge_id}/check-in", response_model=ChallengeCheckInResponse)
def challenge_check_in(challenge_id: str, payload: ChallengeCheckInRequest, _api_key: str = Depends(verify_api_key)) -> ChallengeCheckInResponse:
    """C5: Daily check-in for an active challenge. Records today's run metrics and builds a streak.

    - Validates challenge exists and user has joined
    - Prevents duplicate check-ins on the same UTC day
    - Pulls the user's latest run_session metrics as today's data
    - If no run session today, still records the check-in but without metrics
    - Computes consecutive check-in streak
    """
    from datetime import timedelta

    if challenge_id not in _CHALLENGES:
        raise HTTPException(status_code=404, detail=f"Challenge '{challenge_id}' not found.")

    try:
        with get_db_session() as session:
            user = _resolve_user(session, payload.user_id)

            # Verify user has joined this challenge
            participant = session.scalar(
                select(ChallengeParticipant).where(
                    ChallengeParticipant.challenge_id == challenge_id,
                    ChallengeParticipant.user_id == user.id,
                )
            )
            if participant is None:
                raise HTTPException(status_code=400, detail="You must join the challenge before checking in.")

            # Prevent duplicate check-in on the same UTC day
            now = datetime.now(timezone.utc)
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            if participant.last_check_in is not None and participant.last_check_in >= today_start:
                raise HTTPException(status_code=409, detail="You have already checked in today.")

            # Get today's latest run session metrics
            latest_session = session.scalar(
                select(RunSession).where(
                    RunSession.user_id == user.id,
                ).order_by(RunSession.start_time.desc()).limit(1)
            )

            today_metrics: dict = {}
            has_today_run = False
            if latest_session is not None and latest_session.start_time >= today_start:
                has_today_run = True
                today_metrics = {
                    "cadence": latest_session.avg_cadence,
                    "vertical_oscillation": latest_session.avg_vertical_oscillation,
                    "gct": latest_session.avg_gct,
                    "duration_sec": latest_session.duration_sec,
                }
                # Filter out None values
                today_metrics = {k: v for k, v in today_metrics.items() if v is not None}

                # Update latest metrics on participant
                if latest_session.avg_cadence is not None:
                    participant.latest_cadence = latest_session.avg_cadence
                if latest_session.avg_cadence is not None and latest_session.avg_vertical_oscillation is not None:
                    participant.latest_score = round(
                        (latest_session.avg_cadence / 180.0 * 0.5)
                        + ((0.12 / max(latest_session.avg_vertical_oscillation, 0.001)) * 0.5),
                        3,
                    )

            # Compute streak based on previous check-in date
            yesterday_start = today_start - timedelta(days=1)
            yesterday_end = today_start - timedelta(seconds=1)
            if participant.last_check_in is not None and yesterday_start <= participant.last_check_in <= yesterday_end:
                # Consecutive day — streak continues
                streak_days = participant.current_streak + 1
            else:
                # Either first check-in ever, or streak was broken
                streak_days = 1

            # Record the check-in
            participant.last_check_in = now
            participant.check_in_count = (participant.check_in_count or 0) + 1
            participant.current_streak = streak_days
            session.commit()

            return ChallengeCheckInResponse(
                status="ok",
                check_in_count=participant.check_in_count,
                streak_days=streak_days,
                today_metrics=today_metrics,
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to check in: {exc}") from exc


# ═══════════════════════════════════════════════════════════════════════════
# RF-602  Coach Panel API ──────────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════

_MAX_COACH_CODES_PER_USER = 5


def _generate_coach_code() -> str:
    """Generate a unique 8-character alphanumeric coach code."""
    return ''.join(random.choices(_ALPHANUMERIC, k=8))


def _resolve_user_by_id(session, user_id: int) -> User:
    """Look up a User by internal ID or raise 404."""
    user = session.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise HTTPException(status_code=404, detail=f"User id={user_id} not found.")
    return user


@app.post("/api/v1/coach/generate-code", response_model=CoachCodeResponse)
def generate_coach_code(payload: CoachCodeGenerateRequest, _api_key: str = Depends(verify_api_key)) -> CoachCodeResponse:
    """Generate a unique 8-character coach code. Each user can create up to 5 active codes."""
    try:
        with get_db_session() as session:
            user = _resolve_user(session, payload.ios_user_id)

            active_codes = session.execute(
                select(CoachCode).where(
                    CoachCode.coach_id == user.id,
                    CoachCode.is_active.is_(True),
                )
            ).scalars().all()
            if len(active_codes) >= _MAX_COACH_CODES_PER_USER:
                raise HTTPException(
                    status_code=429,
                    detail=f"You have reached the maximum of {_MAX_COACH_CODES_PER_USER} active coach codes.",
                )

            # Generate unique code, retrying on collision
            for _ in range(20):
                code = _generate_coach_code()
                existing = session.scalar(select(CoachCode).where(CoachCode.code == code))
                if existing is None:
                    break
            else:
                raise HTTPException(status_code=500, detail="Failed to generate unique coach code. Please try again.")

            coach_code = CoachCode(
                coach_id=user.id,
                code=code,
            )
            session.add(coach_code)
            session.commit()
            session.refresh(coach_code)

            return CoachCodeResponse(
                code=coach_code.code,
                student_limit=coach_code.student_limit,
                created_at=coach_code.created_at.isoformat(),
                is_active=coach_code.is_active,
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate coach code: {exc}") from exc


@app.get("/api/v1/coach/students", response_model=list[CoachStudentResponse])
def coach_students(
    coach_id: int = Query(..., ge=1),
    _api_key: str = Depends(verify_api_key),
) -> list[CoachStudentResponse]:
    """List all students for a coach (looked up by user ID)."""
    try:
        with get_db_session() as session:
            _resolve_user_by_id(session, coach_id)

            rows = session.execute(
                select(CoachStudent, User).join(
                    User, CoachStudent.student_id == User.id,
                ).where(
                    CoachStudent.coach_id == coach_id,
                ).order_by(CoachStudent.joined_at.desc())
            ).all()

            results = []
            for cs, student in rows:
                results.append(CoachStudentResponse(
                    ios_user_id=student.ios_user_id,
                    nickname=student.nickname,
                    first_name=student.first_name,
                    last_name=student.last_name,
                    joined_at=cs.joined_at.isoformat(),
                    student_note=cs.student_note,
                ))
            return results
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list coach students: {exc}") from exc


@app.post("/api/v1/coach/join", response_model=CoachJoinResponse)
def coach_join(payload: CoachJoinRequest, _api_key: str = Depends(verify_api_key)) -> CoachJoinResponse:
    """Student joins a coach using a coach code."""
    try:
        with get_db_session() as session:
            student = _resolve_user(session, payload.ios_user_id)
            code = payload.code.strip().upper()

            coach_code = session.scalar(select(CoachCode).where(CoachCode.code == code))
            if coach_code is None:
                raise HTTPException(status_code=404, detail="Coach code not found.")
            if not coach_code.is_active:
                raise HTTPException(status_code=400, detail="This coach code is no longer active.")
            if coach_code.coach_id == student.id:
                raise HTTPException(status_code=400, detail="You cannot join yourself as a student.")

            # Check student limit
            current_student_count = session.scalar(
                select(func.count()).select_from(CoachStudent).where(
                    CoachStudent.coach_id == coach_code.coach_id,
                )
            ) or 0
            if current_student_count >= coach_code.student_limit:
                raise HTTPException(status_code=400, detail="This coach has reached their student limit.")

            # Check if already joined
            existing = session.scalar(
                select(CoachStudent).where(
                    CoachStudent.coach_id == coach_code.coach_id,
                    CoachStudent.student_id == student.id,
                )
            )
            if existing is not None:
                coach_user = session.scalar(select(User).where(User.id == coach_code.coach_id))
                return CoachJoinResponse(
                    joined=True,
                    coach_ios_user_id=coach_user.ios_user_id if coach_user else "",
                    message="You are already connected with this coach.",
                )

            cs = CoachStudent(
                coach_id=coach_code.coach_id,
                student_id=student.id,
            )
            session.add(cs)
            session.commit()

            coach_user = session.scalar(select(User).where(User.id == coach_code.coach_id))
            return CoachJoinResponse(
                joined=True,
                coach_ios_user_id=coach_user.ios_user_id if coach_user else "",
                message="Successfully joined your coach! They can now view your running form data.",
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to join coach: {exc}") from exc


@app.get("/api/v1/coach/dashboard", response_model=CoachDashboardResponse)
def coach_dashboard(
    coach_id: int = Query(..., ge=1),
    _api_key: str = Depends(verify_api_key),
) -> CoachDashboardResponse:
    """Coach dashboard: list all students with their latest form summaries."""
    try:
        with get_db_session() as session:
            coach = _resolve_user_by_id(session, coach_id)

            # Get all coach-student relationships
            rows = session.execute(
                select(CoachStudent, User).join(
                    User, CoachStudent.student_id == User.id,
                ).where(
                    CoachStudent.coach_id == coach_id,
                ).order_by(CoachStudent.joined_at.desc())
            ).all()

            students: list[CoachStudentResponse] = []
            form_summaries: list[CoachStudentFormSummary] = []

            for cs, student in rows:
                students.append(CoachStudentResponse(
                    ios_user_id=student.ios_user_id,
                    nickname=student.nickname,
                    first_name=student.first_name,
                    last_name=student.last_name,
                    joined_at=cs.joined_at.isoformat(),
                    student_note=cs.student_note,
                ))

                # Get latest run session metrics for this student
                latest_session = session.scalar(
                    select(RunSession).where(
                        RunSession.user_id == student.id,
                    ).order_by(RunSession.start_time.desc()).limit(1)
                )

                # Get all sessions for counting
                session_count = session.scalar(
                    select(func.count()).select_from(RunSession).where(
                        RunSession.user_id == student.id,
                    )
                ) or 0

                if latest_session:
                    form_summaries.append(CoachStudentFormSummary(
                        session_count=session_count,
                        latest_session_at=latest_session.start_time.isoformat(),
                        avg_cadence=latest_session.avg_cadence,
                        avg_vertical_oscillation=latest_session.avg_vertical_oscillation,
                        avg_gct=latest_session.avg_gct,
                        overall_score=(
                            round(
                                ((latest_session.avg_cadence or 0) / 180.0 * 0.5)
                                + ((0.12 / max((latest_session.avg_vertical_oscillation or 0.001), 0.001)) * 0.5),
                                3,
                            )
                            if latest_session.avg_cadence is not None and latest_session.avg_vertical_oscillation is not None
                            else None
                        ),
                    ))
                else:
                    form_summaries.append(CoachStudentFormSummary(
                        session_count=0,
                        latest_session_at=None,
                        avg_cadence=None,
                        avg_vertical_oscillation=None,
                        avg_gct=None,
                        overall_score=None,
                    ))

            return CoachDashboardResponse(
                coach_ios_user_id=coach.ios_user_id,
                student_count=len(students),
                students=students,
                form_summaries=form_summaries,
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to load dashboard: {exc}") from exc


# ═══════════════════════════════════════════════════════════════════════════
# C4  Club / Group Leaderboard API ─────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════

@app.get("/api/v1/clubs/{club_code}/leaderboard", response_model=ClubLeaderboardResponse)
def club_leaderboard(
    club_code: str,
    ios_user_id: str | None = Query(None, min_length=3),
    _api_key: str = Depends(verify_api_key),
) -> ClubLeaderboardResponse:
    """C4: Return a running-form leaderboard for a club/group.

    club_code maps to a CoachCode — the club is a virtual grouping identified
    by the coach's invite code. Students who joined through that code form the
    club. Rankings are based on the latest run session form_score for each member.

    If the club_code does not match any coach code, returns empty with
    coming_soon=true so the frontend can show an appropriate placeholder.
    """
    try:
        with get_db_session() as session:
            # Resolve club_code to a CoachCode
            coach_code = session.scalar(
                select(CoachCode).where(
                    CoachCode.code == club_code.upper(),
                    CoachCode.is_active.is_(True),
                )
            )
            if coach_code is None:
                # Also try looking up by coach ios_user_id as a fallback
                # (club_code might be a coach's user identifier directly)
                coach_user = session.scalar(
                    select(User).where(User.ios_user_id == club_code)
                )
                if coach_user is None:
                    return ClubLeaderboardResponse(members=[], coming_soon=True)
                coach_id = coach_user.id
            else:
                coach_id = coach_code.coach_id

            # Get all students in this club
            rows = session.execute(
                select(CoachStudent, User).join(
                    User, CoachStudent.student_id == User.id,
                ).where(
                    CoachStudent.coach_id == coach_id,
                ).order_by(CoachStudent.joined_at.desc())
            ).all()

            if not rows:
                return ClubLeaderboardResponse(members=[], coming_soon=True)

            # Build leaderboard entries with latest run session metrics
            entries: list[ClubLeaderboardEntry] = []
            for cs, student in rows:
                # Get latest run session for this student
                latest = session.scalar(
                    select(RunSession).where(
                        RunSession.user_id == student.id,
                    ).order_by(RunSession.start_time.desc()).limit(1)
                )

                # Get second-latest for score_change calculation
                second_latest = None
                if latest is not None:
                    second_latest = session.scalar(
                        select(RunSession).where(
                            RunSession.user_id == student.id,
                            RunSession.id != latest.id,
                        ).order_by(RunSession.start_time.desc()).limit(1)
                    )

                # Compute form_score
                form_score = None
                cadence = None
                if latest is not None:
                    cadence = latest.avg_cadence
                    if latest.avg_cadence is not None and latest.avg_vertical_oscillation is not None:
                        form_score = round(
                            (latest.avg_cadence / 180.0 * 0.5)
                            + ((0.12 / max(latest.avg_vertical_oscillation, 0.001)) * 0.5),
                            3,
                        )

                # Compute score_change direction
                score_change = "→"
                if latest is not None and second_latest is not None:
                    prev_score = None
                    if second_latest.avg_cadence is not None and second_latest.avg_vertical_oscillation is not None:
                        prev_score = round(
                            (second_latest.avg_cadence / 180.0 * 0.5)
                            + ((0.12 / max(second_latest.avg_vertical_oscillation, 0.001)) * 0.5),
                            3,
                        )
                    if form_score is not None and prev_score is not None:
                        if form_score > prev_score:
                            score_change = "+"
                        elif form_score < prev_score:
                            score_change = "-"

                # Determine nickname
                nickname = student.nickname or student.first_name or student.ios_user_id

                # Check if this entry is the requesting user
                is_me = (ios_user_id is not None and student.ios_user_id == ios_user_id)

                entries.append(ClubLeaderboardEntry(
                    rank=0,  # filled below after sorting
                    nickname=nickname,
                    avatar_url=None,
                    cadence=cadence,
                    form_score=form_score,
                    score_change=score_change,
                    is_me=is_me,
                ))

            # Sort by form_score descending (None goes to bottom)
            entries.sort(
                key=lambda e: e.form_score if e.form_score is not None else float("-inf"),
                reverse=True,
            )

            # Assign ranks
            for i, entry in enumerate(entries):
                entry.rank = i + 1

            return ClubLeaderboardResponse(members=entries, coming_soon=False)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to load club leaderboard: {exc}") from exc


# ═══════════════════════════════════════════════════════════════════════════
# RF-606  Challenge Notification Push ──────────────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════

# WeChat subscribe message template IDs (placeholder — replace with real ones)
_WX_TEMPLATE_RANK_CHANGE = "TEMPLATE_RANK_CHANGE_001"
_WX_TEMPLATE_OVERTAKEN = "TEMPLATE_OVERTAKEN_002"
_WX_TEMPLATE_DEADLINE = "TEMPLATE_DEADLINE_003"
_WX_TEMPLATE_WEEKLY_DIGEST = "TEMPLATE_WEEKLY_DIGEST_004"


def _build_wx_subscribe_data(template_id: str, openid: str, page: str, fields: dict) -> dict:
    """Build a WeChat subscribe message template payload.
    
    Returns the full payload as would be sent to WeChat API. The caller (WeChat
    mini-program) receives this and triggers wx.requestSubscribeMessage.
    """
    data = {}
    for key, value in fields.items():
        data[key] = {"value": str(value) if value is not None else ""}
    return {
        "touser": openid,
        "template_id": template_id,
        "page": page,
        "data": data,
    }


def _get_latest_sessions_for_users(session, user_ids: list[int], since: datetime | None = None) -> dict[int, list]:
    """Fetch latest run sessions (up to 10) for a list of user IDs, optionally since a date."""
    result: dict[int, list] = {}
    for uid in user_ids:
        q = select(RunSession).where(RunSession.user_id == uid)
        if since is not None:
            q = q.where(RunSession.start_time >= since)
        rows = session.execute(
            q.order_by(RunSession.start_time.desc()).limit(10)
        ).scalars().all()
        result[uid] = rows
    return result


def _compute_current_metrics(sessions: list) -> dict:
    """Compute current avg cadence, oscillation, and score from a list of sessions."""
    cadences = [s.avg_cadence for s in sessions if s.avg_cadence is not None]
    oscillations = [s.avg_vertical_oscillation for s in sessions if s.avg_vertical_oscillation is not None]

    avg_cadence = round(sum(cadences) / len(cadences), 2) if cadences else None
    avg_osc = round(sum(oscillations) / len(oscillations), 4) if oscillations else None
    score = None
    if avg_cadence and avg_osc:
        score = round((avg_cadence / 180.0 * 0.5) + ((0.12 / max(avg_osc, 0.001)) * 0.5), 3)

    return {"cadence": avg_cadence, "oscillation": avg_osc, "score": score}


@app.post("/api/v1/challenges/{challenge_id}/notify", response_model=ChallengeNotifyResponse)
def challenge_notify(
    challenge_id: str,
    payload: ChallengeNotifyRequest,
    _api_key: str = Depends(verify_api_key),
) -> ChallengeNotifyResponse:
    """RF-606: Generate WeChat subscribe message push data for challenge participants.

    trigger_type:
      - rank_change: Notify users whose leaderboard rank has changed
      - overtaken: Notify users who have been overtaken by others
      - deadline: Remind participants the challenge ends within 3 days
      - weekly_digest: Weekly summary of check-in days and cadence change

    Returns notification payloads ready for WeChat mini-program to trigger
    wx.requestSubscribeMessage. No actual push is performed server-side.
    """
    from datetime import timedelta

    if challenge_id not in _CHALLENGES:
        raise HTTPException(status_code=404, detail=f"Challenge '{challenge_id}' not found.")

    valid_triggers = {"rank_change", "overtaken", "deadline", "weekly_digest"}
    trigger = payload.trigger_type
    if trigger not in valid_triggers:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid trigger_type '{trigger}'. Must be one of: {', '.join(sorted(valid_triggers))}",
        )

    challenge_data = _CHALLENGES[challenge_id]
    end_dt = datetime.fromisoformat(challenge_data["end_date"]).replace(tzinfo=timezone.utc)
    start_dt = datetime.fromisoformat(challenge_data["start_date"]).replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)

    try:
        with get_db_session() as session:
            # Fetch all participants for this challenge
            participants = session.execute(
                select(ChallengeParticipant).where(
                    ChallengeParticipant.challenge_id == challenge_id,
                )
            ).scalars().all()

            if not participants:
                return ChallengeNotifyResponse(
                    challenge_id=challenge_id,
                    trigger_type=trigger,
                    notifications=[],
                )

            user_ids = [p.user_id for p in participants]
            # Fetch user records
            user_map: dict[int, User] = {}
            for u in session.execute(select(User).where(User.id.in_(user_ids))).scalars().all():
                user_map[u.id] = u

            notifications: list[NotificationItem] = []

            # Build participant lookup
            p_map: dict[int, ChallengeParticipant] = {p.user_id: p for p in participants}

            if trigger == "deadline":
                # ── Deadline check: last 3 days ──
                days_left = (end_dt.date() - now.date()).days
                if days_left > 3:
                    return ChallengeNotifyResponse(
                        challenge_id=challenge_id,
                        trigger_type=trigger,
                        notifications=[],
                    )

                template_id = _WX_TEMPLATE_DEADLINE
                for p in participants:
                    u = user_map.get(p.user_id)
                    if u is None:
                        continue
                    notifications.append(NotificationItem(
                        user_id=u.ios_user_id,
                        template_id=template_id,
                        data=_build_wx_subscribe_data(
                            template_id, u.ios_user_id,
                            page="pages/challenge/challenge",
                            fields={
                                "thing1": f"距离挑战结束仅剩{days_left}天",
                                "thing2": f"{p.check_in_count or 0}/{end_dt.date()}天打卡",
                                "thing3": f"当前步频 {p.latest_cadence or '--'} SPM",
                            },
                        ),
                    ))

            elif trigger == "weekly_digest":
                # ── Weekly digest: this week's stats per user ──
                template_id = _WX_TEMPLATE_WEEKLY_DIGEST
                monday = now - timedelta(days=now.weekday())
                monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
                sunday = monday + timedelta(days=6, hours=23, minutes=59, seconds=59)

                sessions_by_user = _get_latest_sessions_for_users(session, user_ids, since=monday)

                for p in participants:
                    u = user_map.get(p.user_id)
                    if u is None:
                        continue
                    user_sessions = sessions_by_user.get(p.user_id, [])
                    this_week_sessions = [s for s in user_sessions if monday <= s.start_time <= sunday]
                    check_in_days = p.check_in_count or 0

                    metrics = _compute_current_metrics(user_sessions)
                    cadence_now = metrics["cadence"]
                    cadence_baseline = p.baseline_cadence
                    cadence_delta = None
                    if cadence_now is not None and cadence_baseline is not None and cadence_baseline > 0:
                        cadence_delta = round(cadence_now - cadence_baseline, 1)

                    cadence_text = f"{cadence_now or '--'} SPM"
                    if cadence_delta is not None and cadence_delta > 0:
                        cadence_text += f" (↑+{cadence_delta})"
                    elif cadence_delta is not None and cadence_delta < 0:
                        cadence_text += f" (↓{cadence_delta})"

                    notifications.append(NotificationItem(
                        user_id=u.ios_user_id,
                        template_id=template_id,
                        data=_build_wx_subscribe_data(
                            template_id, u.ios_user_id,
                            page="pages/challenge/challenge",
                            fields={
                                "thing1": f"本周打卡{len(this_week_sessions)}天",
                                "thing2": cadence_text,
                                "thing3": f"连续打卡{p.current_streak or 0}天",
                            },
                        ),
                    ))

            elif trigger in ("rank_change", "overtaken"):
                # ── Rank change / Overtaken: compute leaderboard and detect changes ──
                # Compute full leaderboard (same logic as leaderboard endpoint)
                leaderboard: list[dict] = []
                for p in participants:
                    u = user_map.get(p.user_id)
                    if u is None:
                        continue
                    user_sessions = session.execute(
                        select(RunSession)
                        .where(RunSession.user_id == p.user_id, RunSession.start_time >= p.joined_at)
                        .order_by(RunSession.start_time.desc())
                        .limit(10)
                    ).scalars().all()

                    metrics = _compute_current_metrics(user_sessions)
                    overall_change = None
                    current_score = metrics["score"]
                    if p.baseline_overall_score is not None and current_score is not None:
                        overall_change = round(current_score - p.baseline_overall_score, 3)

                    leaderboard.append({
                        "user_id": p.user_id,
                        "ios_user_id": u.ios_user_id,
                        "overall_change": overall_change,
                        "cadence": metrics["cadence"],
                        "oscillation": metrics["oscillation"],
                        "check_in_count": p.check_in_count or 0,
                    })

                # Sort by overall_change desc
                leaderboard.sort(
                    key=lambda e: e["overall_change"] if e["overall_change"] is not None else float("-inf"),
                    reverse=True,
                )

                # Assign current ranks
                for i, entry in enumerate(leaderboard):
                    entry["rank"] = i + 1

                if trigger == "rank_change":
                    # Simulate "previous rank" by sorting by check_in_count then cadence
                    # (a reasonable proxy — earlier participants with fewer check-ins)
                    prev_sorted = sorted(leaderboard, key=lambda e: (
                        e["check_in_count"],
                        e["cadence"] if e["cadence"] is not None else 0,
                    ), reverse=True)
                    prev_rank_map: dict[int, int] = {}
                    for i, entry in enumerate(prev_sorted):
                        prev_rank_map[entry["user_id"]] = i + 1

                    template_id = _WX_TEMPLATE_RANK_CHANGE
                    for entry in leaderboard:
                        current_rank = entry["rank"]
                        prev_rank = prev_rank_map.get(entry["user_id"], current_rank)
                        rank_delta = prev_rank - current_rank  # positive = improved

                        if rank_delta == 0:
                            continue  # No change, skip

                        direction = "上升" if rank_delta > 0 else "下降"
                        notifications.append(NotificationItem(
                            user_id=entry["ios_user_id"],
                            template_id=template_id,
                            data=_build_wx_subscribe_data(
                                template_id, entry["ios_user_id"],
                                page="pages/challenge/challenge",
                                fields={
                                    "thing1": f"排名{direction}{abs(rank_delta)}位",
                                    "thing2": f"当前第{current_rank}名",
                                    "thing3": f"步频{entry['cadence'] or '--'} SPM",
                                },
                            ),
                        ))

                elif trigger == "overtaken":
                    # Detect users overtaken: compare each user's rank against a
                    # recency-adjusted rank (users who just got a good session pass others)
                    # Sort by cadence improvement to find who's surging
                    overtaken_users: set[int] = set()

                    for i, entry in enumerate(leaderboard):
                        # Check if anyone below this entry has higher recent cadence
                        for j in range(i + 1, len(leaderboard)):
                            below = leaderboard[j]
                            if entry["overall_change"] is not None and below["overall_change"] is not None:
                                if below["overall_change"] > entry["overall_change"]:
                                    # The lower-ranked user has better improvement — overtaken risk
                                    overtaken_users.add(entry["user_id"])

                    template_id = _WX_TEMPLATE_OVERTAKEN
                    for entry in leaderboard:
                        if entry["user_id"] not in overtaken_users:
                            continue
                        notifications.append(NotificationItem(
                            user_id=entry["ios_user_id"],
                            template_id=template_id,
                            data=_build_wx_subscribe_data(
                                template_id, entry["ios_user_id"],
                                page="pages/challenge/challenge",
                                fields={
                                    "thing1": "有人正在超越你！",
                                    "thing2": f"当前排名第{entry['rank']}",
                                    "thing3": f"步频{entry['cadence'] or '--'} SPM",
                                },
                            ),
                        ))

            return ChallengeNotifyResponse(
                challenge_id=challenge_id,
                trigger_type=trigger,
                notifications=notifications,
            )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate notifications: {exc}") from exc


# ═══════════════════════════════════════════════════════════════════════════
# RF-607  Share Image Server-Side Generation ───────────────────────────────
# ═══════════════════════════════════════════════════════════════════════════

from fastapi.responses import Response as FastAPIResponse


def _svg_circular_progress(percent: float, label: str, sublabel: str,
                           color: str = "#3B82F6", size: int = 200) -> str:
    """Generate an SVG circular progress ring.

    percent: 0-100
    label: main text in center (e.g. "8/14")
    sublabel: smaller text below (e.g. "days")
    """
    stroke_width = 12
    radius = (size // 2) - stroke_width - 4
    circumference = 2 * 3.14159265 * radius
    dash_offset = circumference * (1 - percent / 100)

    return f'''<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" xmlns="http://www.w3.org/2000/svg">
  <circle cx="{size//2}" cy="{size//2}" r="{radius}" fill="none" stroke="#E5E7EB" stroke-width="{stroke_width}"/>
  <circle cx="{size//2}" cy="{size//2}" r="{radius}" fill="none" stroke="{color}" stroke-width="{stroke_width}"
    stroke-linecap="round" stroke-dasharray="{circumference:.1f}" stroke-dashoffset="{dash_offset:.1f}"
    transform="rotate(-90 {size//2} {size//2})"/>
  <text x="{size//2}" y="{size//2-8}" text-anchor="middle" font-family="system-ui,sans-serif"
    font-size="36" font-weight="bold" fill="#111827">{label}</text>
  <text x="{size//2}" y="{size//2+22}" text-anchor="middle" font-family="system-ui,sans-serif"
    font-size="14" fill="#6B7280">{sublabel}</text>
</svg>'''


def _svg_trend_arrow(direction: str, x: int, y: int, size: int = 24) -> str:
    """Generate an SVG trend arrow: 'up', 'down', or 'flat'."""
    if direction == "up":
        return f'''<polygon points="{x},{y+size} {x+size//2},{y} {x+size},{y+size}"
          fill="#10B981" stroke="#10B981" stroke-width="2"/>'''
    elif direction == "down":
        return f'''<polygon points="{x},{y} {x+size//2},{y+size} {x+size},{y}"
          fill="#EF4444" stroke="#EF4444" stroke-width="2"/>'''
    else:
        return f'''<line x1="{x}" y1="{y+size//2}" x2="{x+size}" y2="{y+size//2}"
          stroke="#9CA3AF" stroke-width="3" stroke-linecap="round"/>'''


def _generate_challenge_progress_svg(
    user_display: str, check_in_count: int, total_days: int,
    cadence: float | None, cadence_delta: float | None,
    rank: int | None, total_participants: int,
) -> str:
    """Generate the challenge_progress share image as SVG."""
    percent = min(round(check_in_count / total_days * 100), 100) if total_days > 0 else 0
    cadence_str = f"{cadence:.0f}" if cadence is not None else "--"
    delta_str = ""
    trend_dir = "flat"
    if cadence_delta is not None and cadence_delta > 0:
        delta_str = f"+{cadence_delta:.1f}"
        trend_dir = "up"
    elif cadence_delta is not None and cadence_delta < 0:
        delta_str = f"{cadence_delta:.1f}"
        trend_dir = "down"

    rank_str = f"#{rank}" if rank is not None else "--"
    total_str = f"/{total_participants}" if total_participants else ""

    return f'''<svg width="600" height="400" viewBox="0 0 600 400" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1E3A5F;stop-opacity:1"/>
      <stop offset="100%" style="stop-color:#111827;stop-opacity:1"/>
    </linearGradient>
  </defs>
  <rect width="600" height="400" fill="url(#bg)" rx="16"/>
  <!-- Title -->
  <text x="30" y="40" font-family="system-ui,sans-serif" font-size="14" fill="#9CA3AF"
    text-anchor="start">14-Day Running Form Challenge</text>
  <!-- User name -->
  <text x="30" y="68" font-family="system-ui,sans-serif" font-size="20" font-weight="bold"
    fill="#FFFFFF" text-anchor="start">{user_display}</text>
  <!-- Circular progress (left side) -->
  <g transform="translate(80, 160)">
    {_svg_circular_progress(percent, f"{check_in_count}/{total_days}", "days", color="#3B82F6", size=160)}
  </g>
  <!-- Stats panel (right side) -->
  <g transform="translate(330, 140)">
    <!-- Cadence -->
    <rect x="0" y="0" width="240" height="52" rx="10" fill="rgba(255,255,255,0.08)"/>
    <text x="16" y="24" font-family="system-ui,sans-serif" font-size="12" fill="#9CA3AF">步频 Cadence</text>
    <text x="16" y="44" font-family="system-ui,sans-serif" font-size="20" font-weight="bold"
      fill="#FFFFFF">{cadence_str} <tspan font-size="12" fill="#9CA3AF">SPM</tspan></text>
    {_svg_trend_arrow(trend_dir, 180, 14, 24)}
    <text x="210" y="36" font-family="system-ui,sans-serif" font-size="13" fill="#10B981">{delta_str}</text>
    <!-- Rank -->
    <rect x="0" y="62" width="240" height="42" rx="10" fill="rgba(255,255,255,0.08)"/>
    <text x="16" y="90" font-family="system-ui,sans-serif" font-size="12" fill="#9CA3AF">排名 Rank</text>
    <text x="180" y="90" font-family="system-ui,sans-serif" font-size="20" font-weight="bold"
      fill="#FBBF24" text-anchor="end">{rank_str} <tspan font-size="12" fill="#9CA3AF">{total_str}</tspan></text>
    <!-- Score -->
    <rect x="0" y="114" width="240" height="42" rx="10" fill="rgba(255,255,255,0.08)"/>
    <text x="16" y="142" font-family="system-ui,sans-serif" font-size="12" fill="#9CA3AF">连续打卡 Streak</text>
    <text x="180" y="142" font-family="system-ui,sans-serif" font-size="20" font-weight="bold"
      fill="#FFFFFF" text-anchor="end">{check_in_count} 天</text>
  </g>
  <!-- Brand -->
  <text x="300" y="380" font-family="system-ui,sans-serif" font-size="11" fill="#4B5563"
    text-anchor="middle">RunForm · runformcoach.com</text>
</svg>'''


@app.get("/api/v1/share-image")
def share_image(
    type: str = Query(..., description="challenge_progress | invite | milestone"),
    user_id: str = Query(..., min_length=3),
    challenge_id: str | None = Query(None),
    _api_key: str = Depends(verify_api_key),
) -> FastAPIResponse:
    """RF-607: Generate share images server-side as SVG.

    Types:
      - challenge_progress: Circular progress ring + cadence trend + rank
      - invite: Invite poster (placeholder)
      - milestone: Milestone celebration (placeholder)

    Returns SVG content (image/svg+xml). The client can render directly
    or convert to PNG via Canvas on the mini-program side.
    """
    try:
        with get_db_session() as session:
            user = _resolve_user(session, user_id)

            if type == "challenge_progress":
                cid = challenge_id or _FOURTEEN_DAY_CHALLENGE_ID
                if cid not in _CHALLENGES:
                    raise HTTPException(status_code=404, detail=f"Challenge '{cid}' not found.")

                ch_data = _CHALLENGES[cid]
                total_days = (datetime.fromisoformat(ch_data["end_date"]).date()
                              - datetime.fromisoformat(ch_data["start_date"]).date()).days

                # Get participant data
                participant = session.scalar(
                    select(ChallengeParticipant).where(
                        ChallengeParticipant.challenge_id == cid,
                        ChallengeParticipant.user_id == user.id,
                    )
                )

                check_in_count = participant.check_in_count if participant else 0

                # Get cadence data
                recent_sessions = session.execute(
                    select(RunSession)
                    .where(RunSession.user_id == user.id)
                    .order_by(RunSession.start_time.desc())
                    .limit(10)
                ).scalars().all()

                metrics = _compute_current_metrics(recent_sessions)
                cadence = metrics["cadence"]
                cadence_delta = None
                if participant and participant.baseline_cadence and cadence:
                    cadence_delta = round(cadence - participant.baseline_cadence, 1)

                # Get rank from leaderboard
                all_participants = session.execute(
                    select(ChallengeParticipant).where(
                        ChallengeParticipant.challenge_id == cid,
                    )
                ).scalars().all()

                total_participants = len(all_participants)
                rank = None

                if participant:
                    lb_entries = []
                    for p in all_participants:
                        p_sessions = session.execute(
                            select(RunSession)
                            .where(RunSession.user_id == p.user_id, RunSession.start_time >= p.joined_at)
                            .order_by(RunSession.start_time.desc())
                            .limit(10)
                        ).scalars().all()
                        p_metrics = _compute_current_metrics(p_sessions)
                        overall_change = None
                        if p.baseline_overall_score is not None and p_metrics["score"] is not None:
                            overall_change = round(p_metrics["score"] - p.baseline_overall_score, 3)
                        lb_entries.append({
                            "user_id": p.user_id,
                            "overall_change": overall_change,
                        })

                    lb_entries.sort(
                        key=lambda e: e["overall_change"] if e["overall_change"] is not None else float("-inf"),
                        reverse=True,
                    )
                    for i, entry in enumerate(lb_entries):
                        if entry["user_id"] == user.id:
                            rank = i + 1
                            break

                display_name = user.nickname or user.first_name or user_id
                svg_content = _generate_challenge_progress_svg(
                    user_display=display_name,
                    check_in_count=check_in_count,
                    total_days=total_days,
                    cadence=cadence,
                    cadence_delta=cadence_delta,
                    rank=rank,
                    total_participants=total_participants,
                )

                return FastAPIResponse(
                    content=svg_content,
                    media_type="image/svg+xml",
                    headers={"Cache-Control": "public, max-age=300"},
                )

            elif type == "invite":
                # MVP: placeholder invite poster with invite code
                # Get user's first active invite code
                invite = session.scalar(
                    select(InviteCode).where(
                        InviteCode.creator_user_id == user.id,
                        InviteCode.redeemed_by.is_(None),
                        InviteCode.is_active.is_(True),
                    ).order_by(InviteCode.created_at.desc()).limit(1)
                )

                code = invite.code if invite else "--------"
                display_name = user.nickname or user.first_name or user_id

                svg = f'''<svg width="600" height="400" viewBox="0 0 600 400" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="invbg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#7C3AED;stop-opacity:1"/>
      <stop offset="100%" style="stop-color:#1E1B4B;stop-opacity:1"/>
    </linearGradient>
  </defs>
  <rect width="600" height="400" fill="url(#invbg)" rx="16"/>
  <text x="300" y="60" font-family="system-ui,sans-serif" font-size="28" font-weight="bold"
    fill="#FFFFFF" text-anchor="middle">Join the Challenge!</text>
  <text x="300" y="100" font-family="system-ui,sans-serif" font-size="16" fill="#C4B5FD"
    text-anchor="middle">{display_name} invites you to RunForm</text>
  <!-- Invite code box -->
  <rect x="140" y="140" width="320" height="80" rx="12" fill="rgba(255,255,255,0.12)"
    stroke="rgba(255,255,255,0.2)" stroke-width="1"/>
  <text x="300" y="175" font-family="system-ui,sans-serif" font-size="12" fill="#A78BFA"
    text-anchor="middle">INVITE CODE</text>
  <text x="300" y="208" font-family="monospace" font-size="36" font-weight="bold"
    fill="#FBBF24" text-anchor="middle" letter-spacing="6">{code}</text>
  <!-- QR placeholder -->
  <rect x="220" y="250" width="160" height="100" rx="10" fill="rgba(255,255,255,0.06)"
    stroke="rgba(255,255,255,0.15)" stroke-width="1"/>
  <text x="300" y="290" font-family="system-ui,sans-serif" font-size="12" fill="#6D28D9"
    text-anchor="middle">Scan to join</text>
  <text x="300" y="310" font-family="system-ui,sans-serif" font-size="10" fill="#5B21B6"
    text-anchor="middle">WeChat Mini Program</text>
  <!-- Brand -->
  <text x="300" y="380" font-family="system-ui,sans-serif" font-size="11" fill="#5B21B6"
    text-anchor="middle">RunForm · runformcoach.com</text>
</svg>'''
                return FastAPIResponse(
                    content=svg,
                    media_type="image/svg+xml",
                    headers={"Cache-Control": "public, max-age=300"},
                )

            elif type == "milestone":
                # MVP: milestone celebration placeholder
                display_name = user.nickname or user.first_name or user_id

                # Get cadence improvement
                participant = session.scalar(
                    select(ChallengeParticipant).where(
                        ChallengeParticipant.challenge_id == _FOURTEEN_DAY_CHALLENGE_ID,
                        ChallengeParticipant.user_id == user.id,
                    )
                )

                cadence_delta = None
                if participant and participant.baseline_cadence and participant.latest_cadence:
                    cadence_delta = round(participant.latest_cadence - participant.baseline_cadence, 1)

                delta_text = f"+{cadence_delta} SPM" if cadence_delta and cadence_delta > 0 else (
                    f"{cadence_delta} SPM" if cadence_delta else "Keep going!"
                )

                svg = f'''<svg width="600" height="400" viewBox="0 0 600 400" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="milebg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#059669;stop-opacity:1"/>
      <stop offset="100%" style="stop-color:#064E3B;stop-opacity:1"/>
    </linearGradient>
  </defs>
  <rect width="600" height="400" fill="url(#milebg)" rx="16"/>
  <!-- Celebration emoji -->
  <text x="300" y="90" font-family="system-ui,sans-serif" font-size="60" text-anchor="middle">🎉</text>
  <text x="300" y="150" font-family="system-ui,sans-serif" font-size="28" font-weight="bold"
    fill="#FFFFFF" text-anchor="middle">Milestone Reached!</text>
  <text x="300" y="190" font-family="system-ui,sans-serif" font-size="16" fill="#6EE7B7"
    text-anchor="middle">{display_name}</text>
  <!-- Stats -->
  <rect x="140" y="220" width="320" height="60" rx="12" fill="rgba(255,255,255,0.1)"/>
  <text x="300" y="248" font-family="system-ui,sans-serif" font-size="14" fill="#A7F3D0"
    text-anchor="middle">Cadence Improvement</text>
  <text x="300" y="272" font-family="system-ui,sans-serif" font-size="24" font-weight="bold"
    fill="#FBBF24" text-anchor="middle">{delta_text}</text>
  <!-- Trend arrow -->
  {_svg_trend_arrow('up' if cadence_delta and cadence_delta > 0 else 'flat', 430, 234, 28)}
  <!-- Brand -->
  <text x="300" y="380" font-family="system-ui,sans-serif" font-size="11" fill="#047857"
    text-anchor="middle">RunForm · runformcoach.com</text>
</svg>'''
                return FastAPIResponse(
                    content=svg,
                    media_type="image/svg+xml",
                    headers={"Cache-Control": "public, max-age=300"},
                )

            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unknown type '{type}'. Must be: challenge_progress, invite, milestone",
                )

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate share image: {exc}") from exc
