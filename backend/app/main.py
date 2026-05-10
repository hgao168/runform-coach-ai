import os
import json
from urllib.parse import urlencode

from fastapi import FastAPI, File, Form, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from .analyzer import analyze_from_metrics, analyze_running_video, generate_plan
from .athletes import compare_with_athlete, get_all_athletes
from .db import check_database, get_db_session
from .db_models import OAuthConnection
from .schemas import (
    AnalyzeProfileContext,
    AnalysisResponse,
    AthleteListItem,
    CompareRequest,
    CompareResponse,
    PoseMetricsInput,
    StravaCallbackResponse,
    StravaConnectResponse,
    StravaDisconnectRequest,
    StravaStatusResponse,
    TrainingPlanInput,
    TrainingPlanResponse,
)
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


@app.get("/integrations/strava/connect", response_model=StravaConnectResponse)
def strava_connect(ios_user_id: str = Query(..., min_length=3)) -> StravaConnectResponse:
    """Build a Strava OAuth authorize URL for a specific iOS user identifier."""
    try:
        payload = build_authorize_url(ios_user_id=ios_user_id)
        return StravaConnectResponse(**payload)
    except StravaOAuthConfigError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to create Strava connect URL: {exc}") from exc


@app.get("/integrations/strava/callback", response_model=StravaCallbackResponse)
async def strava_callback(code: str | None = None, state: str | None = None, error: str | None = None):
    """Handle Strava OAuth callback, exchange code for tokens, and persist encrypted credentials."""
    if error:
        raise HTTPException(status_code=400, detail=f"Strava OAuth error: {error}")
    if not code or not state:
        raise HTTPException(status_code=400, detail="Missing required callback parameters: code and state.")

    try:
        ios_user_id = verify_state(state)
        token_payload = await exchange_code_for_token(code)
        with get_db_session() as session:
            connection = upsert_strava_connection(session, ios_user_id=ios_user_id, token_payload=token_payload)
            session.commit()

        if app_url := app_callback_url():
            query = urlencode({
                "status": "connected",
                "ios_user_id": ios_user_id,
                "provider": "strava",
                "provider_athlete_id": connection.provider_athlete_id,
            })
            return RedirectResponse(url=f"{app_url}?{query}")

        return StravaCallbackResponse(
            connected=True,
            ios_user_id=ios_user_id,
            provider_athlete_id=connection.provider_athlete_id,
        )
    except StravaOAuthConfigError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except StravaOAuthError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Strava callback failed: {exc}") from exc


@app.get("/integrations/strava/status", response_model=StravaStatusResponse)
def strava_status(ios_user_id: str = Query(..., min_length=3)) -> StravaStatusResponse:
    """Return Strava connection status for a given iOS user identifier."""
    try:
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
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to get Strava status: {exc}") from exc


@app.post("/integrations/strava/disconnect")
async def strava_disconnect(payload: StravaDisconnectRequest) -> dict:
    """Disconnect Strava by deauthorizing and deleting stored OAuth credentials."""
    try:
        with get_db_session() as session:
            conn: OAuthConnection | None = get_strava_connection(session, ios_user_id=payload.ios_user_id)
            if conn is None:
                return {"disconnected": True, "provider": "strava", "message": "No active connection."}

            access_token = decrypt_secret(conn.access_token_encrypted)
            await deauthorize_access_token(access_token)
            session.delete(conn)
            session.commit()

        return {"disconnected": True, "provider": "strava"}
    except StravaOAuthConfigError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except StravaOAuthError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to disconnect Strava: {exc}") from exc
