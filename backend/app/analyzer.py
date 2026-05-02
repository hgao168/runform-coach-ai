import base64
import json
import os
import tempfile
from pathlib import Path
from typing import Any

import cv2
from openai import OpenAI

from .schemas import AnalysisResponse, Exercise, Issue, Metric, PoseMetricsInput, VideoQuality


VIDEO_TIPS = [
    "Record 10–20 seconds from the side view.",
    "Keep the full body visible, especially both feet.",
    "Use a stable phone at hip height with good lighting.",
    "Run at your normal pace and avoid baggy clothes covering knees/ankles.",
]


def _status_from_quality(score: float) -> str:
    if score >= 0.75:
        return "Good"
    if score >= 0.55:
        return "Usable"
    return "Low"


def _video_quality(pose_input: PoseMetricsInput) -> VideoQuality:
    reasons = list(pose_input.quality_reasons)
    if not reasons and pose_input.video_quality_score >= 0.75:
        reasons = ["Pose detection and ankle visibility look good for this clip."]
    return VideoQuality(
        score=round(max(0.0, min(1.0, pose_input.video_quality_score)), 2),
        status=_status_from_quality(pose_input.video_quality_score),
        reasons=reasons[:5],
        tips=VIDEO_TIPS,
    )


def _safe_json_loads(raw: str) -> dict[str, Any]:
    try:
        return json.loads(raw)
    except Exception:
        start = raw.find("{")
        end = raw.rfind("}")
        if start >= 0 and end > start:
            return json.loads(raw[start : end + 1])
        raise


# ── Legacy video-to-LLM fallback ─────────────────────────────────────────────

_SYSTEM_PROMPT = """
You are an expert running coach and sports biomechanics analyst.
Analyze the provided video frames of a person running and give a biomechanical assessment.
Return ONLY valid JSON with this exact structure:
{
  "summary": "<1-2 sentence overall assessment>",
  "confidence": 0.0,
  "metrics": [ { "name": "", "score": 0.0, "status": "", "explanation": "" } ],
  "issues": [ { "title": "", "severity": "", "explanation": "", "recommended_exercises": [ { "name": "", "category": "", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": "" } ] } ]
}
Evaluate exactly these 4 metrics in order: Hip stability, Knee tracking, Trunk control, Overstride risk.
If a metric is unclear due to video angle or quality, assign a moderate score and state the limitation.
Do not invent exact cadence from static frames.
"""


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

    content: list[dict[str, Any]] = [
        {"type": "text", "text": "Analyze the running form shown in these frames. Do not calculate cadence from frames."}
    ]
    for b64 in frames_b64:
        content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "low"}})

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model=os.environ.get("OPENAI_VISION_MODEL", "gpt-4o"),
        messages=[{"role": "system", "content": _SYSTEM_PROMPT}, {"role": "user", "content": content}],
        max_tokens=1800,
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    data = _safe_json_loads(response.choices[0].message.content or "{}")
    return AnalysisResponse(
        summary=data.get("summary", "Running form analysis completed."),
        confidence=float(data.get("confidence", 0.65)),
        quality=VideoQuality(score=0.55, status="Usable", reasons=["Legacy video upload path used."], tips=VIDEO_TIPS),
        metrics=[Metric(**m) for m in data.get("metrics", [])],
        issues=[
            Issue(
                title=iss["title"],
                severity=iss["severity"],
                explanation=iss["explanation"],
                recommended_exercises=[Exercise(**e) for e in iss.get("recommended_exercises", [])],
            )
            for iss in data.get("issues", [])
        ],
    )


# ── Preferred metrics-based analysis ─────────────────────────────────────────

_METRICS_SYSTEM_PROMPT = """
You are an expert running coach and sports biomechanics analyst.
You are given numeric pose metrics extracted on-device from Apple Vision.
Return ONLY valid JSON with this exact structure:
{
  "summary": "<1-2 sentence overall assessment>",
  "confidence": 0.0,
  "issues": [
    {
      "title": "",
      "severity": "Low|Medium|High",
      "explanation": "",
      "recommended_exercises": [
        {"name": "", "category": "Strength|Run drill|Mobility", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": ""}
      ]
    }
  ]
}
Rules:
- Never say cadence is 0. If cadence_status is "Not measurable", say cadence was not measurable from this clip.
- Generate issues only for Moderate, Needs work, or Not measurable metrics.
- Include one issue about video quality if video quality is Low.
- Maximum 3 issues. Give 2 exercises per issue.
"""


def analyze_from_metrics(pose_input: PoseMetricsInput) -> AnalysisResponse:
    metrics = _build_metric_cards(pose_input)
    quality = _video_quality(pose_input)
    data = _generate_issues_with_llm(pose_input, metrics, quality)

    avg_metric_score = sum(m.score for m in metrics) / max(1, len(metrics))
    confidence = min(avg_metric_score, quality.score)
    if pose_input.cadence_status == "Not measurable":
        confidence = min(confidence, 0.62)
    confidence = round(float(data.get("confidence", confidence)), 2)
    confidence = round(max(0.30, min(confidence, 0.95)), 2)

    return AnalysisResponse(
        summary=data.get("summary", _summary_fallback(pose_input, quality)),
        confidence=confidence,
        quality=quality,
        metrics=metrics,
        issues=_parse_issues(data) or _fallback_issues(pose_input, quality),
    )


def _build_metric_cards(p: PoseMetricsInput) -> list[Metric]:
    if p.cadence_status == "Not measurable" or p.cadence_estimate_spm <= 0:
        cadence_explanation = (
            "Cadence was not measurable from this clip because the foot/ankle signal was too weak. "
            "Re-record from side view with both feet visible; RunForm avoids showing a false 0 spm value."
        )
    else:
        cadence_explanation = (
            f"Estimated cadence: {p.cadence_estimate_spm:.0f} steps/min. "
            + ("Target range is usually around 165–185 spm for many steady runs." if p.cadence_status != "Good" else "Cadence is in a solid range for this clip.")
        )

    return [
        Metric(name="Cadence", score=round(p.cadence_score, 2), status=p.cadence_status, explanation=cadence_explanation),
        Metric(
            name="Overstride risk",
            score=round(p.overstride_risk_score, 2),
            status=p.overstride_status,
            explanation=(
                "Foot landing was assessed relative to the hip center during stance. "
                + ("Foot may be landing ahead of the body, increasing braking force." if p.overstride_status != "Good" else "Foot strike looks reasonably close to under the body.")
            ),
        ),
        Metric(
            name="Trunk lean",
            score=round(p.trunk_lean_score, 2),
            status=p.trunk_lean_status,
            explanation=f"Average trunk angle: {abs(p.trunk_lean_degrees):.1f}°. "
            + ("Keep posture tall with a slight forward lean from the ankles." if p.trunk_lean_status != "Good" else "Trunk alignment looks stable."),
        ),
        Metric(
            name="Knee valgus / hip stability",
            score=round(p.knee_valgus_risk_score, 2),
            status=p.knee_valgus_status,
            explanation=(
                "Knee tracking was compared with hip-to-ankle alignment during stance. "
                + ("Some inward knee drift or hip stability limitation may be present." if p.knee_valgus_status != "Good" else "Knee tracking looks controlled in this clip.")
            ),
        ),
    ]


def _generate_issues_with_llm(p: PoseMetricsInput, metrics: list[Metric], quality: VideoQuality) -> dict[str, Any]:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return {}

    user_message = {
        "cadence_estimate_spm": p.cadence_estimate_spm,
        "cadence_status": p.cadence_status,
        "cadence_quality": p.cadence_quality,
        "cadence_step_count": p.cadence_step_count,
        "overstride_status": p.overstride_status,
        "overstride_risk_score": p.overstride_risk_score,
        "trunk_lean_degrees": p.trunk_lean_degrees,
        "trunk_lean_status": p.trunk_lean_status,
        "knee_valgus_status": p.knee_valgus_status,
        "knee_valgus_risk_score": p.knee_valgus_risk_score,
        "frame_count": p.frame_count,
        "sampled_frame_count": p.sampled_frame_count,
        "video_duration_seconds": p.video_duration_seconds,
        "pose_detection_rate": p.pose_detection_rate,
        "ankle_visibility_rate": p.ankle_visibility_rate,
        "video_quality": quality.model_dump(),
        "metric_cards": [m.model_dump() for m in metrics],
        "notes": p.notes,
    }

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model=os.environ.get("OPENAI_COACH_MODEL", "gpt-4o"),
        messages=[
            {"role": "system", "content": _METRICS_SYSTEM_PROMPT},
            {"role": "user", "content": json.dumps(user_message)},
        ],
        max_tokens=1400,
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    return _safe_json_loads(response.choices[0].message.content or "{}")


def _parse_issues(data: dict[str, Any]) -> list[Issue]:
    issues: list[Issue] = []
    for iss in data.get("issues", [])[:3]:
        try:
            issues.append(
                Issue(
                    title=iss["title"],
                    severity=iss.get("severity", "Medium"),
                    explanation=iss["explanation"],
                    recommended_exercises=[Exercise(**e) for e in iss.get("recommended_exercises", [])[:2]],
                )
            )
        except Exception:
            continue
    return issues


def _summary_fallback(p: PoseMetricsInput, quality: VideoQuality) -> str:
    if p.cadence_status == "Not measurable":
        return f"Analysis completed with {quality.status.lower()} video quality. Cadence was not measurable from this clip, so re-recording may improve accuracy."
    return f"Analysis completed with {quality.status.lower()} video quality. Cadence estimate is {p.cadence_estimate_spm:.0f} spm."


def _fallback_issues(p: PoseMetricsInput, quality: VideoQuality) -> list[Issue]:
    issues: list[Issue] = []
    if quality.score < 0.70 or p.cadence_status == "Not measurable":
        issues.append(
            Issue(
                title="Improve recording quality",
                severity="Medium",
                explanation="The clip did not show enough reliable foot/ankle movement to measure cadence. A better side-view clip will improve accuracy.",
                recommended_exercises=[
                    Exercise(name="Re-record side-view run", category="Run drill", sets=1, reps="10–20 sec", frequency_per_week=1, reason="Full-body side view helps detect foot-strike cycles."),
                    Exercise(name="Treadmill phone setup practice", category="Run drill", sets=1, reps="2 minutes", frequency_per_week=1, reason="Stable hip-height camera improves pose landmark quality."),
                ],
            )
        )
    if p.overstride_status != "Good":
        issues.append(
            Issue(
                title="Reduce overstride risk",
                severity="Medium",
                explanation="Your foot may be landing too far ahead of your body. Shorter, quicker steps can reduce braking force.",
                recommended_exercises=[
                    Exercise(name="A-march drill", category="Run drill", sets=3, reps="20 meters", frequency_per_week=2, reason="Reinforces foot placement under the body."),
                    Exercise(name="Metronome cadence strides", category="Run drill", sets=6, reps="20 seconds", frequency_per_week=2, reason="Builds quicker rhythm without forcing pace."),
                ],
            )
        )
    if p.knee_valgus_status != "Good":
        issues.append(
            Issue(
                title="Build hip stability",
                severity="Medium",
                explanation="Knee tracking suggests hip control may need work during stance.",
                recommended_exercises=[
                    Exercise(name="Side plank with top-leg raise", category="Strength", sets=3, reps="8 each side", frequency_per_week=2, reason="Targets lateral hip stability."),
                    Exercise(name="Single-leg Romanian deadlift", category="Strength", sets=3, reps="8 each side", frequency_per_week=2, reason="Improves single-leg control."),
                ],
            )
        )
    return issues[:3]
