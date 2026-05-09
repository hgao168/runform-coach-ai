import os
import json

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .analyzer import analyze_from_metrics, analyze_running_video, generate_plan
from .athletes import compare_with_athlete, get_all_athletes
from .db import check_database
from .schemas import (
    AnalyzeProfileContext,
    AnalysisResponse,
    AthleteListItem,
    CompareRequest,
    CompareResponse,
    PoseMetricsInput,
    TrainingPlanInput,
    TrainingPlanResponse,
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
