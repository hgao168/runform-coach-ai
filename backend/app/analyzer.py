import base64
import json
import os
import tempfile
from pathlib import Path

import cv2
from openai import OpenAI

from .planner import generate_training_plan
from .schemas import AnalysisResponse, Exercise, Issue, Metric, PoseMetricsInput, TrainingPlanInput, TrainingPlanResponse

_SYSTEM_PROMPT = """You are an expert running coach and sports biomechanics analyst. Analyze the provided video frames of a person running and give a detailed biomechanical assessment.
Return ONLY valid JSON with this exact structure: { "summary": "<1-2 sentence overall assessment>", "confidence": 0.0, "metrics": [ { "name": "", "score": 0.0, "status": "", "explanation": "" } ], "issues": [ { "title": "", "severity": "", "explanation": "", "recommended_exercises": [ { "name": "", "category": "", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": "" } ] } ] }
Always evaluate exactly these 4 metrics in order: 1. Hip stability 2. Knee tracking 3. Trunk control 4. Overstride risk. If unclear due to video angle or quality, assign a moderate score and note the limitation. Provide 1-3 issues with 2 exercises each."""

_METRICS_SYSTEM_PROMPT = """You are an expert running coach and sports biomechanics analyst.
You are given biomechanical metrics extracted from on-device Apple Vision pose detection.
Return ONLY valid JSON with this exact structure: { "summary": "<1-2 sentence overall assessment referencing the numbers and video quality>", "confidence": 0.0, "issues": [ { "title": "", "severity": "", "explanation": "", "recommended_exercises": [ { "name": "", "category": "", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": "" } ] } ] }
Rules:
- Only generate issues for metrics with status "Needs work" or "Moderate". Skip "Good" metrics unless all metrics are Good.
- If video_quality_score < 0.65, lower confidence and explicitly say the report is approximate.
- Provide 2 recommended exercises per issue.
- Maximum 3 issues."""


def _extract_frames(video_path: str, num_frames: int = 8) -> list[str]:
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


def _parse_issues(data: dict) -> list[Issue]:
    return [
        Issue(
            title=iss["title"],
            severity=iss["severity"],
            explanation=iss["explanation"],
            recommended_exercises=[Exercise(**e) for e in iss.get("recommended_exercises", [])],
        )
        for iss in data.get("issues", [])
    ]


def analyze_running_video(video_bytes: bytes, filename: str) -> AnalysisResponse:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable is not set.")
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

    content: list[dict] = [{"type": "text", "text": "Analyze the running form shown in these video frames:"}]
    for b64 in frames_b64:
        content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "low"}})

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": _SYSTEM_PROMPT}, {"role": "user", "content": content}],
        max_tokens=2000,
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content)
    return AnalysisResponse(
        summary=data["summary"],
        confidence=float(data["confidence"]),
        metrics=[Metric(**m) for m in data["metrics"]],
        issues=_parse_issues(data),
    )


def analyze_from_metrics(pose_input: PoseMetricsInput) -> AnalysisResponse:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable is not set.")

    if pose_input.cadence_status == "Not measurable":
        cadence_explanation = "Cadence could not be measured from this clip. Ensure feet are visible and the video is 8+ seconds of steady running."
    else:
        cadence_explanation = f"Estimated cadence: {pose_input.cadence_estimate_spm:.0f} steps/min (target 160–180 spm). " + ("Consider smaller, quicker steps." if pose_input.cadence_status != "Good" else "Cadence is in the optimal range.")
    trunk_explanation = f"Average trunk angle: {abs(pose_input.trunk_lean_degrees):.1f}°. " + ("Check whether the runner is leaning from the hips instead of the ankles." if pose_input.trunk_lean_status != "Good" else "Trunk alignment looks solid.")
    quality_pct = int(pose_input.video_quality_score * 100)

    metrics = [
        Metric(name="Video quality", score=round(pose_input.video_quality_score, 2), status="Good" if pose_input.video_quality_score >= 0.75 else "Moderate" if pose_input.video_quality_score >= 0.55 else "Needs work", explanation=f"Pose detection rate {int(pose_input.pose_detection_rate * 100)}%. Higher quality means more trustworthy metrics."),
        Metric(name="Cadence", score=round(pose_input.cadence_score, 2), status=pose_input.cadence_status, explanation=cadence_explanation),
        Metric(name="Overstride risk", score=round(pose_input.overstride_risk_score, 2), status=pose_input.overstride_status, explanation="Foot landing position relative to hip center of mass. " + ("Foot may be landing ahead of the body." if pose_input.overstride_status != "Good" else "Foot strike looks well-positioned under the body.")),
        Metric(name="Trunk lean", score=round(pose_input.trunk_lean_score, 2), status=pose_input.trunk_lean_status, explanation=trunk_explanation),
        Metric(name="Knee valgus / hip stability", score=round(pose_input.knee_valgus_risk_score, 2), status=pose_input.knee_valgus_status, explanation="Knee tracking relative to the hip-ankle alignment during stance. " + ("Inward knee collapse detected — suggests hip abductor control work." if pose_input.knee_valgus_status != "Good" else "Knee alignment during stance looks stable.")),
    ]

    all_notes = pose_input.notes + pose_input.quality_notes
    notes_str = " Notes: " + "; ".join(all_notes) if all_notes else ""
    user_message = f"""Running form metrics from on-device Apple Vision pose detection:
- Capture mode: {pose_input.video_mode}
- Video quality: {quality_pct}% | pose detection rate {pose_input.pose_detection_rate:.2f}
- Cadence: {pose_input.cadence_estimate_spm:.0f} steps/min | score {pose_input.cadence_score:.2f} | {pose_input.cadence_status}
- Overstride risk: score {pose_input.overstride_risk_score:.2f} | {pose_input.overstride_status}
- Trunk lean: {pose_input.trunk_lean_degrees:.1f}° | score {pose_input.trunk_lean_score:.2f} | {pose_input.trunk_lean_status}
- Knee valgus / hip stability: score {pose_input.knee_valgus_risk_score:.2f} | {pose_input.knee_valgus_status}
- Frames analyzed: {pose_input.frame_count} over {pose_input.video_duration_seconds:.1f}s{notes_str}
Generate targeted coaching issues and exercise recommendations based on these measurements."""

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": _METRICS_SYSTEM_PROMPT}, {"role": "user", "content": user_message}],
        max_tokens=1500,
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content)
    metric_avg = sum(m.score for m in metrics[1:]) / 4
    quality_adjusted_confidence = min(float(data.get("confidence", metric_avg)), pose_input.video_quality_score + 0.20, 0.95)
    return AnalysisResponse(
        summary=data["summary"],
        confidence=round(quality_adjusted_confidence, 2),
        metrics=metrics,
        issues=_parse_issues(data),
        video_quality_score=round(pose_input.video_quality_score, 2),
        quality_notes=pose_input.quality_notes,
    )


def generate_plan(plan_input: TrainingPlanInput) -> TrainingPlanResponse:
    return generate_training_plan(plan_input)
