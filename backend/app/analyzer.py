import base64
import json
import os
import tempfile
from pathlib import Path

import cv2
from openai import OpenAI

from .schemas import AnalysisResponse, Exercise, Issue, Metric

_SYSTEM_PROMPT = """You are an expert running coach and sports biomechanics analyst.
Analyze the provided video frames of a person running and give a detailed biomechanical assessment.

Return ONLY valid JSON with this exact structure:
{
  "summary": "<1-2 sentence overall assessment>",
  "confidence": <float 0.0-1.0>,
  "metrics": [
    {
      "name": "<metric name>",
      "score": <float 0.0-1.0>,
      "status": "<Good|Moderate|Needs work>",
      "explanation": "<detailed explanation>"
    }
  ],
  "issues": [
    {
      "title": "<issue title>",
      "severity": "<Low|Medium|High>",
      "explanation": "<detailed explanation>",
      "recommended_exercises": [
        {
          "name": "<exercise name>",
          "category": "<Strength|Mobility|Run drill|Stability>",
          "sets": <integer>,
          "reps": "<e.g. '8-10 each side' or '30 seconds'>",
          "frequency_per_week": <integer>,
          "reason": "<why this exercise helps>"
        }
      ]
    }
  ]
}

Always evaluate exactly these 4 metrics in order:
1. Hip stability (pelvic drop, lateral hip control)
2. Knee tracking (alignment, valgus/varus collapse)
3. Trunk control (rotation, lateral sway)
4. Overstride risk (foot landing position relative to center of mass)

If a metric is unclear due to video angle or quality, assign a moderate score (0.55-0.70) and note the limitation.
Provide 1-3 issues with 2 recommended exercises each. Be specific and actionable."""


def _extract_frames(video_path: str, num_frames: int = 8) -> list[str]:
    """Extract evenly spaced frames and return as base64-encoded JPEG strings."""
    cap = cv2.VideoCapture(video_path)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total == 0:
        cap.release()
        return []

    indices = [int(i * total / num_frames) for i in range(num_frames)]
    frames: list[str] = []

    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if ret:
            _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            frames.append(base64.b64encode(buf).decode("utf-8"))

    cap.release()
    return frames


def analyze_running_video(video_bytes: bytes, filename: str) -> AnalysisResponse:
    """Analyze a running video using OpenAI GPT-4o Vision."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable is not set.")

    # Write bytes to a temp file so OpenCV can read it
    suffix = Path(filename).suffix or ".mp4"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(video_bytes)
        tmp_path = tmp.name

    try:
        frames_b64 = _extract_frames(tmp_path)
    finally:
        os.unlink(tmp_path)

    if not frames_b64:
        raise ValueError("Could not extract frames from the uploaded video.")

    content: list[dict] = [
        {"type": "text", "text": "Analyze the running form shown in these video frames:"}
    ]
    for b64 in frames_b64:
        content.append(
            {
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{b64}",
                    "detail": "low",
                },
            }
        )

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": content},
        ],
        max_tokens=2000,
        temperature=0.2,
        response_format={"type": "json_object"},
    )

    data = json.loads(response.choices[0].message.content)

    metrics = [Metric(**m) for m in data["metrics"]]
    issues = [
        Issue(
            title=iss["title"],
            severity=iss["severity"],
            explanation=iss["explanation"],
            recommended_exercises=[Exercise(**e) for e in iss.get("recommended_exercises", [])],
        )
        for iss in data["issues"]
    ]

    return AnalysisResponse(
        summary=data["summary"],
        confidence=float(data["confidence"]),
        metrics=metrics,
        issues=issues,
    )


def analyze_running_video_mock(filename: str) -> AnalysisResponse:
    """
    V1 mock analyzer.

    Replace this with real pose-analysis logic later:
    1. Extract frames from video.
    2. Detect landmarks using Apple Vision, MediaPipe, or OpenCV.
    3. Calculate joint angles and gait events.
    4. Map movement patterns to strength recommendations.
    """
    metrics = [
        Metric(
            name="Hip stability",
            score=0.62,
            status="Needs work",
            explanation="Detected possible hip drop during stance phase. This often indicates weak glute medius or poor single-leg control.",
        ),
        Metric(
            name="Knee tracking",
            score=0.68,
            status="Moderate",
            explanation="Knee alignment may drift inward under load. Improve hip external rotation and foot stability.",
        ),
        Metric(
            name="Trunk control",
            score=0.74,
            status="Good",
            explanation="Upper-body position looks mostly stable, with minor rotation that can be improved with core work.",
        ),
        Metric(
            name="Overstride risk",
            score=0.58,
            status="Needs work",
            explanation="Foot may be landing too far ahead of center of mass. Cadence drills and posterior-chain strength can help.",
        ),
    ]

    hip_exercises = [
        Exercise(
            name="Side plank with top-leg raise",
            category="Strength",
            sets=3,
            reps="8–10 each side",
            frequency_per_week=2,
            reason="Targets glute medius and lateral hip stability to reduce hip drop.",
        ),
        Exercise(
            name="Single-leg Romanian deadlift",
            category="Strength",
            sets=3,
            reps="8 each side",
            frequency_per_week=2,
            reason="Builds single-leg control, hamstring strength, and pelvis stability.",
        ),
    ]

    overstride_exercises = [
        Exercise(
            name="A-march drill",
            category="Run drill",
            sets=3,
            reps="20 meters",
            frequency_per_week=2,
            reason="Improves foot placement under the body and reinforces rhythm.",
        ),
        Exercise(
            name="Calf raise iso hold",
            category="Strength",
            sets=3,
            reps="30 seconds",
            frequency_per_week=2,
            reason="Improves ankle stiffness and push-off control.",
        ),
    ]

    issues = [
        Issue(
            title="Possible hip drop",
            severity="Medium",
            explanation="Your pelvis may drop slightly on one side during stance. Prioritize lateral hip strength and single-leg balance.",
            recommended_exercises=hip_exercises,
        ),
        Issue(
            title="Possible overstride",
            severity="Medium",
            explanation="Your foot may be landing ahead of your center of mass. Combine cadence awareness with calf and posterior-chain work.",
            recommended_exercises=overstride_exercises,
        ),
    ]

    return AnalysisResponse(
        summary=f"Analyzed {filename}. V1 mock result: focus on hip stability, knee tracking, and overstride control.",
        confidence=0.72,
        metrics=metrics,
        issues=issues,
    )
