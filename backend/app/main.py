from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .analyzer import analyze_from_metrics, analyze_running_video
from .schemas import AnalysisResponse, PoseMetricsInput

app = FastAPI(title="RunForm Coach AI API", version="0.2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "runform-coach-ai"}


@app.post("/analyze-metrics", response_model=AnalysisResponse)
async def analyze_metrics(pose_input: PoseMetricsInput) -> AnalysisResponse:
    """Phase 2: accept on-device pose metrics and return AI coaching advice."""
    try:
        return analyze_from_metrics(pose_input)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Analysis error: {exc}")


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(video: UploadFile = File(...)) -> AnalysisResponse:
    """Phase 1 fallback: upload raw video for frame-based GPT-4o Vision analysis."""
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Please upload a valid video file.")

    video_bytes = await video.read()
    return analyze_running_video(video_bytes, video.filename or "running-video.mp4")
