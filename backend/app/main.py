import asyncio
import os
import json
from datetime import datetime, timezone
from functools import wraps
from urllib.parse import urlencode

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address, _rate_limit_exceeded_handler
from sqlalchemy import delete, select

from .analyzer import analyze_from_metrics, analyze_running_video, generate_plan
from .athletes import compare_with_athlete, get_all_athletes
from .db import check_database, get_db_session
from .db_models import OAuthConnection, RunSession, StravaRun, StravaWeeklyStat, User
from .schemas import (
    AnalyzeProfileContext,
    AnalysisResponse,
    AthleteListItem,
    CompareRequest,
    CompareResponse,
    FeedbackSubmitRequest,
    FeedbackSubmitResponse,
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
async def compare(request: Request, compare_request: CompareRequest, _api_key: str = Depends(verify_api_key)) -> CompareResponse:
    """Compare user running metrics against an elite athlete benchmark."""
    try:
        return compare_with_athlete(compare_request)
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


@app.post("/sessions", response_model=RunSessionResponse, status_code=201)
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


@app.get("/sessions", response_model=list[RunSessionResponse])
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


@app.get("/sessions/trends", response_model=SessionTrendsResponse)
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


@app.post("/sessions/compare", response_model=SessionCompareResponse)
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


@app.get("/sessions/{session_id}", response_model=RunSessionResponse)
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


@app.delete("/sessions/{session_id}", status_code=204)
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
