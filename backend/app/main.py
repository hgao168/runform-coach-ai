from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .analyzer import analyze_running_video_mock
from .schemas import AnalysisResponse

app = FastAPI(title="RunForm Coach AI API", version="0.1.0")

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


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze(video: UploadFile = File(...)) -> AnalysisResponse:
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Please upload a valid video file.")

    # V1: read file bytes to validate upload flow, then discard.
    # For real analysis, save to temp storage and pass file path to analyzer.
    _ = await video.read()
    return analyze_running_video_mock(video.filename or "running-video.mov")
