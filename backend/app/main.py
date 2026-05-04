import os

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .analyzer import analyze_from_metrics, analyze_running_video, generate_plan
from .schemas import AnalysisResponse, PoseMetricsInput, TrainingPlanInput, TrainingPlanResponse

ENVIRONMENT = os.getenv("ENVIRONMENT", "production")

app = FastAPI(title="RunForm Coach AI API", version="0.4.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "runform-coach-ai", "version": "0.4.0", "environment": ENVIRONMENT}


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
async def analyze(video: UploadFile = File(...)) -> AnalysisResponse:
    """Legacy fallback: upload raw video for frame-based GPT-4o Vision analysis."""
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Please upload a valid video file.")
    video_bytes = await video.read()
    return analyze_running_video(video_bytes, video.filename or "running-video.mp4")
