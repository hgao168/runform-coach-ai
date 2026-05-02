import base64
import json
import os
import tempfile
from pathlib import Path
from typing import Any

import cv2
from openai import OpenAI

from .schemas import AnalysisResponse, Exercise, Issue, Metric, PoseMetricsInput, TrainingPlanInput, TrainingPlanResponse, PlannedWorkout, VideoQuality


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
The app uses a deterministic issue-to-exercise map. Use the provided issue list as the source of truth.
Return ONLY valid JSON with this exact structure:
{
  "summary": "<1-2 sentence overall assessment>",
  "confidence": 0.0
}
Rules:
- Never say cadence is 0. If cadence_status is "Not measurable", say cadence was not measurable from this clip.
- Do not invent extra exercises. The app will attach exercises from the deterministic recommendation map.
- Mention the main movement priorities only.
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

    issues = _mapped_issues(pose_input, quality)
    return AnalysisResponse(
        summary=data.get("summary", _summary_fallback(pose_input, quality)),
        confidence=confidence,
        quality=quality,
        metrics=metrics,
        issues=issues,
    )


def _signal_confidence(rate: float) -> str:
    """Convert a detection/visibility rate (0–1) to a human-readable confidence tier."""
    if rate >= 0.75:
        return "High"
    if rate >= 0.50:
        return "Medium"
    return "Low"


def _build_metric_cards(p: PoseMetricsInput) -> list[Metric]:
    # Per-metric signal confidence derived from detection quality
    cadence_conf = "Low" if (p.cadence_status == "Not measurable" or p.cadence_estimate_spm <= 0) else p.cadence_quality
    overstride_conf = _signal_confidence(p.ankle_visibility_rate)
    pose_conf = _signal_confidence(p.pose_detection_rate)

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
        Metric(name="Cadence", score=round(p.cadence_score, 2), status=p.cadence_status, explanation=cadence_explanation, confidence=cadence_conf),
        Metric(
            name="Overstride risk",
            score=round(p.overstride_risk_score, 2),
            status=p.overstride_status,
            confidence=overstride_conf,
            explanation=(
                "Foot landing was assessed relative to the hip center during stance. "
                + ("Foot may be landing ahead of the body, increasing braking force." if p.overstride_status != "Good" else "Foot strike looks reasonably close to under the body.")
            ),
        ),
        Metric(
            name="Trunk lean",
            score=round(p.trunk_lean_score, 2),
            status=p.trunk_lean_status,
            confidence=pose_conf,
            explanation=f"Average trunk angle: {abs(p.trunk_lean_degrees):.1f}°. "
            + ("Keep posture tall with a slight forward lean from the ankles." if p.trunk_lean_status != "Good" else "Trunk alignment looks stable."),
        ),
        Metric(
            name="Knee valgus / hip stability",
            score=round(p.knee_valgus_risk_score, 2),
            status=p.knee_valgus_status,
            confidence=pose_conf,
            explanation=(
                "Knee tracking was compared with hip-to-ankle alignment during stance. "
                + ("Some inward knee drift or hip stability limitation may be present." if p.knee_valgus_status != "Good" else "Knee tracking looks controlled in this clip.")
            ),
        ),
        Metric(
            name="Hip drop",
            score=round(p.hip_drop_risk_score, 2),
            status=p.hip_drop_status,
            confidence=pose_conf,
            explanation=(
                "Left/right hip height was compared when landmarks were visible. "
                + ("Possible pelvic drop suggests more single-leg hip control work." if p.hip_drop_status != "Good" else "Pelvic control looks stable in this clip.")
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
        "hip_drop_status": p.hip_drop_status,
        "hip_drop_risk_score": p.hip_drop_risk_score,
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

# ── Phase 3 deterministic issue-to-exercise recommendation engine ────────────

def _exercise(
    name: str,
    category: str,
    sets: int,
    reps: str,
    frequency: int,
    reason: str,
) -> Exercise:
    return Exercise(
        name=name,
        category=category,
        sets=sets,
        reps=reps,
        frequency_per_week=frequency,
        reason=reason,
    )


ISSUE_EXERCISE_MAP: dict[str, dict[str, Any]] = {
    "overstride": {
        "title": "Reduce overstride",
        "severity": "Medium",
        "explanation": "Your foot may be landing too far in front of your body. This can increase braking force and make each stride less efficient.",
        "exercises": [
            _exercise("Cadence drill", "Run drill", 6, "30 sec @ slightly quicker rhythm", 2, "A quicker rhythm encourages shorter steps and helps the foot land closer under the hips."),
            _exercise("A-skip", "Run drill", 3, "20 meters", 2, "A-skip teaches knee drive, posture, and landing mechanics without reaching forward."),
            _exercise("Wall drill", "Run drill", 3, "8 reps each leg", 2, "Wall drill reinforces forward lean from the ankles and foot strike under the center of mass."),
        ],
    },
    "knee_valgus": {
        "title": "Improve knee tracking",
        "severity": "Medium",
        "explanation": "Your knee may be drifting inward during stance. This often points to hip control and single-leg stability limitations.",
        "exercises": [
            _exercise("Side plank", "Strength", 3, "20–30 sec each side", 2, "Side planks build lateral core and hip stability so the pelvis and knee stay better aligned."),
            _exercise("Clamshell", "Strength", 3, "12 reps each side", 2, "Clamshells target glute medius, which helps control inward knee collapse."),
            _exercise("Single-leg squat", "Strength", 3, "6–8 reps each side", 2, "Single-leg squats train knee-over-foot control under running-like single-leg load."),
        ],
    },
    "low_trunk_lean": {
        "title": "Improve trunk lean",
        "severity": "Medium",
        "explanation": "Your trunk position may be too upright or inconsistent. A small forward lean from the ankles can improve momentum and reduce overstriding.",
        "exercises": [
            _exercise("Falling start drill", "Run drill", 4, "10 meters", 2, "Falling starts teach forward lean from the ankles without bending at the waist."),
            _exercise("Posture drill", "Run drill", 3, "30 sec", 3, "Posture drills reinforce tall alignment, relaxed shoulders, and a stable trunk while running."),
        ],
    },
    "hip_drop": {
        "title": "Build hip stability",
        "severity": "Medium",
        "explanation": "Possible hip drop suggests the pelvis is not staying level during single-leg stance. This can reduce efficiency and increase knee/hip stress.",
        "exercises": [
            _exercise("Glute bridge", "Strength", 3, "12–15 reps", 2, "Glute bridges improve hip extension strength so you can push off without losing pelvic control."),
            _exercise("Monster walk", "Strength", 3, "10 steps each direction", 2, "Monster walks strengthen glute medius for better side-to-side pelvic stability."),
            _exercise("Single-leg RDL", "Strength", 3, "8 reps each side", 2, "Single-leg RDLs train hip hinge control, balance, and stance-leg stability."),
        ],
    },
    "video_quality": {
        "title": "Improve video quality",
        "severity": "Medium",
        "explanation": "The clip did not show enough reliable body landmarks for high-confidence analysis. Better recording quality will improve your metrics and recommendations.",
        "exercises": [
            _exercise("Re-record side-view run", "Run drill", 1, "10–20 sec", 1, "A full-body side view lets the app measure foot strike, cadence, trunk angle, and hip movement more reliably."),
            _exercise("Treadmill phone setup practice", "Run drill", 1, "2 minutes", 1, "A stable hip-height camera reduces motion blur and improves landmark detection."),
        ],
    },
}


def _issue_from_key(key: str, severity: str | None = None) -> Issue:
    spec = ISSUE_EXERCISE_MAP[key]
    return Issue(
        title=spec["title"],
        severity=severity or spec["severity"],
        explanation=spec["explanation"],
        recommended_exercises=spec["exercises"],
    )


def _is_problem(status: str) -> bool:
    return status in {"Moderate", "Needs work", "Not measurable", "Low"}


def _mapped_issues(p: PoseMetricsInput, quality: VideoQuality) -> list[Issue]:
    """Deterministic Phase 3 recommendation engine.

    Keeps recommendation quality stable for TestFlight by mapping measured form
    issues to a curated exercise library with explicit "why this exercise" text.
    """
    ranked: list[tuple[float, Issue]] = []

    if quality.score < 0.70 or p.cadence_status == "Not measurable":
        ranked.append((1.00 - quality.score + 0.15, _issue_from_key("video_quality", "High" if quality.score < 0.45 else "Medium")))

    if _is_problem(p.overstride_status):
        ranked.append((1.00 - p.overstride_risk_score, _issue_from_key("overstride", "High" if p.overstride_risk_score < 0.40 else "Medium")))

    if _is_problem(p.knee_valgus_status):
        ranked.append((1.00 - p.knee_valgus_risk_score, _issue_from_key("knee_valgus", "High" if p.knee_valgus_risk_score < 0.40 else "Medium")))

    if _is_problem(p.trunk_lean_status):
        ranked.append((1.00 - p.trunk_lean_score, _issue_from_key("low_trunk_lean", "High" if p.trunk_lean_score < 0.40 else "Medium")))

    if _is_problem(p.hip_drop_status):
        ranked.append((1.00 - p.hip_drop_risk_score, _issue_from_key("hip_drop", "High" if p.hip_drop_risk_score < 0.40 else "Medium")))

    if not ranked:
        return [
            Issue(
                title="Maintain running strength",
                severity="Low",
                explanation="No major movement issue was detected in this clip. Keep a light weekly strength routine to maintain durability.",
                recommended_exercises=[
                    _exercise("A-skip", "Run drill", 3, "20 meters", 1, "Keeps rhythm, posture, and foot placement sharp even when metrics look good."),
                    _exercise("Glute bridge", "Strength", 3, "12 reps", 1, "Maintains hip extension strength for efficient push-off."),
                ],
            )
        ]

    ranked.sort(key=lambda item: item[0], reverse=True)
    return [issue for _, issue in ranked[:3]]


# ── Training plan generation ──────────────────────────────────────────────────

_PLAN_SYSTEM_PROMPT = """You are an expert running coach.
Generate a one-week training plan as valid JSON only.
RULES:
- planned_weekly_km MUST equal exactly the value of current_weekly_km supplied by the user.
- Distribute total km across exactly available_running_days sessions.
- If injury_flag is true, replace all hard/tempo workouts with easy runs and add recovery notes.
- The goal drives the TYPE of workouts (e.g. long slow run for Marathon/Half, speed work for 5K/10K).
- If previous_week_summary is supplied, use it to adapt this week: reduce intensity/volume if workouts were too hard; add recovery if pain was reported; maintain or slightly increase if all were completed.
- Non-running days should NOT appear in the workouts array.
- If form_focus items are supplied, use them to adapt run cues and strength/mobility purpose to those issues.
- Use form_issues to adjust workout purpose/details: overstride/cadence => cadence focus; hip drop/knee valgus => hip stability strength; trunk lean => posture/falling-start drills.
- Add coach notes that explain how the latest analysis changed the plan.
- Include strength/mobility work that supports the latest detected form issues when available.
Return this exact JSON structure:
{
  "summary": "<1-2 sentence overview>",
  "planned_weekly_km": <number — must match current_weekly_km>,
  "running_days": <int — must match available_running_days>,
  "workouts": [
    {
      "day": "Monday",
      "title": "Easy Run",
      "category": "Easy",
      "intensity": "Low",
      "details": "<pace, effort, terrain>",
      "purpose": "<why this session>",
      "distance_km": 8.0,
      "duration_minutes": 50
    }
  ],
  "notes": ["<recovery tip>", "<nutrition tip>"]
}"""




def _form_focus_from_issues(plan_input: TrainingPlanInput) -> list[dict[str, str]]:
    """Translate latest Analyze issues into plan coaching focuses.
    This keeps plan adaptation deterministic even if the LLM returns generic workouts.
    """
    focuses: list[dict[str, str]] = []
    for issue in getattr(plan_input, "form_issues", []) or []:
        title = issue.title.lower()
        exercises = ", ".join(issue.exercise_names[:3]) if issue.exercise_names else "targeted drills"
        if "overstride" in title:
            focuses.append({
                "issue": issue.title,
                "cue": "shorter stride + quicker rhythm",
                "plan_note": "Add cadence-focused cues to easy/long runs and include A-skip or wall drill before quality work.",
                "strength": exercises,
            })
        elif "cadence" in title or "video quality" in title:
            focuses.append({
                "issue": issue.title,
                "cue": "measurable cadence + full-foot visibility",
                "plan_note": "Use short relaxed strides and re-check form with a cleaner side-view clip.",
                "strength": exercises,
            })
        elif "trunk" in title or "lean" in title:
            focuses.append({
                "issue": issue.title,
                "cue": "tall posture + slight lean from ankles",
                "plan_note": "Add posture cues during easy runs and falling-start drill before faster running.",
                "strength": exercises,
            })
        elif "hip" in title or "stability" in title or "drop" in title:
            focuses.append({
                "issue": issue.title,
                "cue": "level pelvis + stable single-leg stance",
                "plan_note": "Add glute/hip stability work on strength days and keep long run easy.",
                "strength": exercises,
            })
        elif "knee" in title or "valgus" in title:
            focuses.append({
                "issue": issue.title,
                "cue": "knee tracks over toes",
                "plan_note": "Use hip-control strength work and avoid aggressive intensity if knee discomfort appears.",
                "strength": exercises,
            })
        elif "arm" in title:
            focuses.append({
                "issue": issue.title,
                "cue": "relaxed forward-backward elbow drive",
                "plan_note": "Add arm swing cues to strides and easy runs to stabilize rhythm.",
                "strength": exercises,
            })
    # keep the plan simple; 1-3 focus items are enough for runners
    return focuses[:3]


def _apply_form_focus_to_workouts(workouts: list[PlannedWorkout], focuses: list[dict[str, str]]) -> list[PlannedWorkout]:
    if not focuses:
        return workouts
    primary = focuses[0]
    adapted: list[PlannedWorkout] = []
    for workout in workouts:
        focus = primary["cue"]
        details = workout.details
        purpose = workout.purpose
        category = workout.category.lower()
        title = workout.title.lower()

        if "easy" in category or "easy" in title:
            details = f"{details} Form cue: {primary['cue']}. Keep this relaxed, not faster."
            purpose = f"{purpose} Also reinforces {primary['issue'].lower()} improvements without adding fatigue."
        elif "quality" in category or "tempo" in title or "interval" in title or "speed" in title:
            details = f"{details} Before the main set, add 5 minutes of drills: {primary['strength']}."
            purpose = f"{purpose} Quality work is paired with form drills so faster running does not reinforce old mechanics."
        elif "long" in category or "long" in title:
            details = f"{details} Keep the form focus simple: {primary['cue']} in the first and last 10 minutes."
            purpose = f"{purpose} Long-run form reminders help maintain mechanics under fatigue."
        elif "strength" in category or "mobility" in category:
            all_strength = "; ".join(f["strength"] for f in focuses if f.get("strength"))
            details = f"{details} Prioritise: {all_strength}."
            purpose = "Targets the movement limiters detected in your latest RunForm analysis."
            focus = ", ".join(f["issue"] for f in focuses)

        adapted.append(PlannedWorkout(
            day=workout.day,
            title=workout.title,
            category=workout.category,
            intensity=workout.intensity,
            details=details,
            purpose=purpose,
            distance_km=workout.distance_km,
            duration_minutes=workout.duration_minutes,
            coaching_focus=focus,
        ))
    return adapted

def _normalise_issue_text(plan_input: TrainingPlanInput) -> str:
    """Build a single lowercase text blob from form issue titles and exercise names."""
    issue_text = " ".join(i.title for i in (plan_input.form_issues or [])).lower()
    exercise_text = " ".join(
        name
        for issue in (plan_input.form_issues or [])
        for name in (issue.exercise_names or [])
    ).lower()
    return f"{issue_text} {exercise_text}"


def _coaching_focus_notes(plan_input: TrainingPlanInput) -> list[str]:
    text = _normalise_issue_text(plan_input)
    notes: list[str] = []
    if any(k in text for k in ["overstride", "cadence", "stride"]):
        notes.append("Latest analysis focus: cadence and shorter ground contact cues were added to reduce overstride risk.")
    if any(k in text for k in ["knee", "valgus", "tracking", "hip stability"]):
        notes.append("Latest analysis focus: hip stability work was added to support knee tracking.")
    if any(k in text for k in ["trunk", "lean", "posture"]):
        notes.append("Latest analysis focus: posture and falling-start cues were added for better trunk position.")
    if any(k in text for k in ["hip drop", "glute", "monster", "single-leg rdl"]):
        notes.append("Latest analysis focus: glute and single-leg stability work was added to reduce hip drop risk.")
    if plan_input.injury_flag:
        notes.append("Injury flag active: hard efforts should be reduced or replaced by easy running and mobility.")
    return notes


def _exercise_names(plan_input: TrainingPlanInput, limit: int = 4) -> str:
    names: list[str] = []
    seen: set[str] = set()
    for issue in plan_input.form_issues or []:
        for name in issue.exercise_names or []:
            if name not in seen:
                names.append(name)
                seen.add(name)
            if len(names) >= limit:
                return ", ".join(names)
    return ", ".join(names)


def _enhance_plan_with_form_context(plan: TrainingPlanResponse, plan_input: TrainingPlanInput) -> TrainingPlanResponse:
    notes = list(plan.notes or [])
    for note in _coaching_focus_notes(plan_input):
        if note not in notes:
            notes.append(note)

    issue_text = _normalise_issue_text(plan_input)
    exercise_summary = _exercise_names(plan_input)
    workouts: list[PlannedWorkout] = []

    for workout in plan.workouts:
        details = workout.details or ""
        purpose = workout.purpose or ""
        title_lower = f"{workout.title} {workout.category} {workout.intensity}".lower()

        if plan_input.injury_flag and any(k in title_lower for k in ["tempo", "interval", "speed", "quality", "hard"]):
            workout = PlannedWorkout(
                day=workout.day,
                title="Easy Run + Mobility",
                category="Easy",
                intensity="Low",
                details=f"{workout.distance_km or 0:g} km easy only. Keep it conversational; stop if pain increases.",
                purpose="Protect recovery while maintaining consistency because injury / pain flag is active.",
                distance_km=workout.distance_km,
                duration_minutes=workout.duration_minutes,
            )
            workouts.append(workout)
            continue

        if "easy" in title_lower or "long" in title_lower:
            cues: list[str] = []
            if any(k in issue_text for k in ["overstride", "cadence", "stride"]):
                cues.append("Run with a light cadence focus and avoid reaching forward with the foot.")
            if any(k in issue_text for k in ["trunk", "lean", "posture"]):
                cues.append("Keep posture tall with a slight forward lean from the ankles.")
            if cues:
                details = (details + " " + " ".join(cues)).strip()
                purpose = (purpose + " Form focus: translate your latest analysis into relaxed running cues.").strip()

        if any(k in title_lower for k in ["strength", "mobility", "cross", "recovery"]):
            if exercise_summary:
                details = (details + f" Add: {exercise_summary}.").strip()
                purpose = (purpose + " These exercises are selected from your latest running-form analysis.").strip()

        workouts.append(PlannedWorkout(
            day=workout.day,
            title=workout.title,
            category=workout.category,
            intensity=workout.intensity,
            details=details,
            purpose=purpose,
            distance_km=workout.distance_km,
            duration_minutes=workout.duration_minutes,
        ))

    return TrainingPlanResponse(
        summary=plan.summary,
        planned_weekly_km=plan.planned_weekly_km,
        running_days=plan.running_days,
        workouts=workouts,
        notes=notes[:8],
        connected_analysis_used=plan.connected_analysis_used,
    )


def generate_plan(plan_input: TrainingPlanInput) -> TrainingPlanResponse:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable is not set.")

    form_focuses = _form_focus_from_issues(plan_input)

    user_message_dict: dict[str, Any] = {
        "current_weekly_km": plan_input.current_weekly_km,
        "target": plan_input.target,
        "available_running_days": plan_input.available_running_days,
        "injury_flag": plan_input.injury_flag,
    }
    if form_focuses:
        user_message_dict["form_focus"] = form_focuses
    if plan_input.recent_analysis_summary:
        user_message_dict["recent_analysis_summary"] = plan_input.recent_analysis_summary
    if plan_input.recent_analysis_confidence is not None:
        user_message_dict["recent_analysis_confidence"] = plan_input.recent_analysis_confidence
    if plan_input.previous_week_summary:
        user_message_dict["previous_week_summary"] = plan_input.previous_week_summary

    user_message = json.dumps(user_message_dict)

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model=os.environ.get("OPENAI_COACH_MODEL", "gpt-4o"),
        messages=[
            {"role": "system", "content": _PLAN_SYSTEM_PROMPT},
            {"role": "user", "content": user_message},
        ],
        max_tokens=1200,
        temperature=0.3,
        response_format={"type": "json_object"},
    )
    data = _safe_json_loads(response.choices[0].message.content or "{}")

    workouts = [
        PlannedWorkout(
            day=w.get("day", ""),
            title=w.get("title", ""),
            category=w.get("category", ""),
            intensity=w.get("intensity", ""),
            details=w.get("details", ""),
            purpose=w.get("purpose", ""),
            distance_km=w.get("distance_km"),
            duration_minutes=w.get("duration_minutes"),
        )
        for w in data.get("workouts", [])
    ]

    workouts = _apply_form_focus_to_workouts(workouts, form_focuses)

    plan = TrainingPlanResponse(
        summary=data.get("summary", "Your personalised weekly training plan."),
        planned_weekly_km=float(data.get("planned_weekly_km", plan_input.current_weekly_km)),
        running_days=int(data.get("running_days", plan_input.available_running_days)),
        workouts=workouts,
        notes=data.get("notes", []),
        connected_analysis_used=bool(form_focuses),
    )

    # Second pass: inject form-focused cues and exercise recommendations deterministically
    if plan_input.form_issues:
        plan = _enhance_plan_with_form_context(plan, plan_input)

    return plan
