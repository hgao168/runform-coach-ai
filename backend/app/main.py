import asyncio
import os
import json
from datetime import datetime, timezone
from functools import wraps
from urllib.parse import urlencode

from fastapi import FastAPI, File, Form, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
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

_PROFILE_FIELDS = [
    "first_name", "last_name", "nickname", "level", "weekly_mileage_km",
    "running_days_per_week", "height_cm", "weight_kg", "target", "injury_note",
    "gender", "shoe_size", "shoe_brand_model", "leg_length_cm", "date_of_birth",
    "weekly_exercise_hours",
]


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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
def save_profile(payload: ProfileSaveRequest) -> ProfileSaveResponse:
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
async def training_plan(plan_input: TrainingPlanInput) -> TrainingPlanResponse:
    """Generate a personalised one-week training plan. planned_weekly_km mirrors current_weekly_km."""
    try:
        return generate_plan(plan_input)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Plan generation error: {exc}") from exc


@app.post("/analyze-metrics", response_model=AnalysisResponse)
async def analyze_metrics(pose_input: PoseMetricsInput) -> AnalysisResponse:
    """Preferred path: iOS extracts pose metrics on-device; backend generates coaching advice."""
    try:
        return analyze_from_metrics(pose_input)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Analysis error: {exc}") from exc


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(
    video: UploadFile = File(...),
    language: str = Form("en"),
    profile_context: str = Form(""),
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
async def compare(request: CompareRequest) -> CompareResponse:
    """Compare user running metrics against an elite athlete benchmark."""
    try:
        return compare_with_athlete(request)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Comparison error: {exc}") from exc


@app.post("/api/v1/feedback", response_model=FeedbackSubmitResponse)
def submit_feedback(payload: FeedbackSubmitRequest) -> FeedbackSubmitResponse:
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
def create_session(payload: RunSessionCreate) -> RunSessionResponse:
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
def compare_sessions(payload: SessionCompareRequest) -> SessionCompareResponse:
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
def get_session(session_id: int, ios_user_id: str = Query(..., min_length=3)) -> RunSessionResponse:
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
def delete_session(session_id: int, ios_user_id: str = Query(..., min_length=3)):
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
