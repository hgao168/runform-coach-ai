from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .analyzer import analyze_running_video, analyze_from_metrics
from .planner import generate_training_plan
from .schemas import (
    AnalysisResponse,
    Exercise,
    Issue,
    Metric,
    PoseMetricsInput,
    TrainingPlanInput,
    TrainingPlanResponse,
    VideoQuality,
)

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
    return {"status": "ok", "version": "0.4.0", "service": "runform-coach-ai"}


def _safe_mock_analysis() -> AnalysisResponse:
    return AnalysisResponse(
        summary="Starter analysis completed. This fallback is used when video decoding or AI analysis is unavailable.",
        confidence=0.55,
        quality=VideoQuality(
            score=0.55,
            status="Usable",
            reasons=["Fallback analysis path used."],
            tips=["Record 10–20 seconds from the side view.", "Keep the full body and both feet visible."],
        ),
        metrics=[
            Metric(name="Cadence", score=0.5, status="Not measurable", explanation="Cadence requires clear foot movement across the clip."),
            Metric(name="Overstride risk", score=0.6, status="Usable", explanation="Upload a clear side-view clip for better accuracy."),
        ],
        issues=[
            Issue(
                title="Improve video quality",
                severity="Medium",
                explanation="A clearer side-view clip will improve metrics and recommendations.",
                recommended_exercises=[
                    Exercise(
                        name="Re-record side-view run",
                        category="Run drill",
                        sets=1,
                        reps="10–20 sec",
                        frequency_per_week=1,
                        reason="A stable full-body side view helps the app measure cadence, foot strike, and posture.",
                    )
                ],
            )
        ],
    )


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(video: UploadFile = File(...)) -> AnalysisResponse:
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Please upload a valid video file.")
    video_bytes = await video.read()
    try:
        return analyze_running_video(video_bytes, video.filename or "running-video.mov")
    except Exception:
        return _safe_mock_analysis()


@app.post("/analyze-metrics", response_model=AnalysisResponse)
def analyze_metrics(input: PoseMetricsInput) -> AnalysisResponse:
    return analyze_from_metrics(input)


@app.post("/training-plan", response_model=TrainingPlanResponse)
def training_plan(input: TrainingPlanInput) -> TrainingPlanResponse:
    return generate_training_plan(input)
