import base64
import json
import os
import tempfile
from pathlib import Path
from typing import Optional

import cv2
from openai import OpenAI

from .planner import generate_training_plan
from .schemas import AnalyzeProfileContext, AnalysisResponse, Exercise, Issue, Metric, PoseMetricsInput, TrainingPlanInput, TrainingPlanResponse

_SYSTEM_PROMPT = """You are an expert running coach and sports biomechanics analyst. Analyze the provided video frames of a person running and give a detailed biomechanical assessment.
Return ONLY valid JSON with this exact structure: { "summary": "<1-2 sentence overall assessment>", "confidence": 0.0, "metrics": [ { "name": "", "score": 0.0, "status": "", "explanation": "" } ], "issues": [ { "title": "", "severity": "", "explanation": "", "recommended_exercises": [ { "name": "", "category": "", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": "" } ] } ] }
Always evaluate exactly these 4 metrics in order: 1. Hip stability 2. Knee tracking 3. Trunk control 4. Overstride risk. If unclear due to video angle or quality, assign a moderate score and note the limitation. Provide 1-3 issues with 2 exercises each."""

_METRICS_SYSTEM_PROMPT = """You are an expert running coach and sports biomechanics analyst.
You are given biomechanical metrics extracted from on-device Apple Vision pose detection.
Return ONLY valid JSON with this exact structure: { "summary": "<1-2 sentence overall assessment referencing the numbers and video quality>", "confidence": 0.0, "issues": [ { "title": "", "severity": "", "explanation": "", "recommended_exercises": [ { "name": "", "category": "", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": "" } ] } ] }
Rules:
- Only generate issues for metrics with status "Needs work" or "Moderate". Skip "Good" metrics unless all metrics are Good.
- If video_quality_score < 0.65, lower confidence and explicitly say the report is approximate.
- If runner profile context is provided (gender, shoe, leg length), use it only to personalize cueing and load advice. Do not override biomechanical evidence.
- Provide 2 recommended exercises per issue.
- Maximum 3 issues."""

_LANGUAGE_NAMES: dict[str, str] = {
    "zh-Hans": "Simplified Chinese (简体中文)",
    "zh": "Simplified Chinese (简体中文)",
    "nl": "Dutch (Nederlands)",
}


def _build_video_prompt(language: str, profile_context: Optional[AnalyzeProfileContext]) -> str:
    prompt = _SYSTEM_PROMPT
    lang_name = _LANGUAGE_NAMES.get(language)
    if lang_name:
        prompt += (
            f"\n\nIMPORTANT: Return ALL coaching text in {lang_name}. "
            "This includes summary, metric explanations, issue titles, explanations, and exercise reasons."
        )
    if profile_context:
        prompt += (
            "\n\nYou may receive runner profile context from self-reported user data. "
            "Use it only to personalize explanation and cueing, not to override visible biomechanical evidence. "
            "If profile factors are missing, proceed normally."
        )
    return prompt


def _build_profile_context_text(profile_context: Optional[AnalyzeProfileContext]) -> str:
    if not profile_context:
        return ""
    parts = []
    if profile_context.gender and profile_context.gender != "unspecified":
        parts.append(f"Gender: {profile_context.gender}")
    if profile_context.shoe_size:
        parts.append(f"Shoe size: {profile_context.shoe_size}")
    if profile_context.leg_length_cm is not None:
        parts.append(f"Leg length: {profile_context.leg_length_cm:.1f} cm")
    if profile_context.shoe_brand_model:
        parts.append(f"Shoe brand/model: {profile_context.shoe_brand_model}")
    if profile_context.weekly_mileage_km is not None:
        parts.append(f"Weekly mileage: {profile_context.weekly_mileage_km:.1f} km")
    if profile_context.running_days_per_week is not None:
        parts.append(f"Running days per week: {profile_context.running_days_per_week}")
    if profile_context.injury_note:
        parts.append(f"Injury note: {profile_context.injury_note}")

    if not parts:
        return ""
    return "\nRunner profile context (self-reported):\n- " + "\n- ".join(parts)


def _build_metrics_prompt(language: str) -> str:
    prompt = _METRICS_SYSTEM_PROMPT
    lang_name = _LANGUAGE_NAMES.get(language)
    if lang_name:
        prompt += (
            f"\n\nIMPORTANT: Return ALL coaching text in {lang_name}. "
            "This includes the summary, all issue titles, explanations, exercise names, and reasons. "
            "Keep metric names in English only."
        )
    return prompt

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


def analyze_running_video(
    video_bytes: bytes,
    filename: str,
    language: str = "en",
    profile_context: Optional[AnalyzeProfileContext] = None,
) -> AnalysisResponse:
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

    profile_text = _build_profile_context_text(profile_context)
    content: list[dict] = [{"type": "text", "text": "Analyze the running form shown in these video frames:" + profile_text}]
    for b64 in frames_b64:
        content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "low"}})

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": _build_video_prompt(language, profile_context)},
            {"role": "user", "content": content},
        ],
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
    if pose_input.vertical_oscillation_status != "Not measurable":
        metrics.append(Metric(name="Vertical oscillation", score=round(pose_input.vertical_oscillation_score, 2), status=pose_input.vertical_oscillation_status, explanation="Hip vertical bounce normalized to body height. " + ("Excessive bounce detected — aim for a quiet, gliding stride." if pose_input.vertical_oscillation_status != "Good" else "Vertical oscillation is in the efficient range.")))
    if pose_input.shoulder_elevation_status != "Not measurable":
        metrics.append(Metric(name="Shoulder elevation", score=round(pose_input.shoulder_elevation_score, 2), status=pose_input.shoulder_elevation_status, explanation="Shoulder-to-hip height ratio detecting hunching or raised/tense shoulders. " + ("Relax your shoulders and restore natural posture." if pose_input.shoulder_elevation_status != "Good" else "Shoulder posture looks relaxed and well-positioned.")))
    if pose_input.arm_swing_status != "Not measurable":
        metrics.append(Metric(name="Arm swing", score=round(pose_input.arm_swing_score, 2), status=pose_input.arm_swing_status, explanation="Elbow oscillation amplitude as a proxy for arm drive rhythm. " + ("Arm drive appears stiff or exaggerated — focus on relaxed 90° elbow swings." if pose_input.arm_swing_status != "Good" else "Arm swing rhythm looks natural and efficient.")))
    if pose_input.arm_crossing_status != "Not measurable":
        metrics.append(Metric(name="Arm crossing (knitting)", score=round(pose_input.arm_crossing_score, 2), status=pose_input.arm_crossing_status, explanation=f"Arm path relative to body midline. Dominant pattern: {pose_input.arm_crossing_direction}. " + ("Cross-body arm motion is elevated; drive elbows backward instead of across the torso." if pose_input.arm_crossing_status != "Good" else "Arm path remains mostly front-back with minimal cross-over.")))
    if pose_input.backward_elbow_drive_status != "Not measurable":
        metrics.append(Metric(name="Backward elbow drive", score=round(pose_input.backward_elbow_drive_score, 2), status=pose_input.backward_elbow_drive_status, explanation=f"Rearward elbow drive angle around {pose_input.backward_elbow_drive_angle_degrees:.1f}°. " + ("Limited rear arm drive may reduce stride rhythm and propulsion." if pose_input.backward_elbow_drive_status != "Good" else "Backward elbow drive supports strong rhythm and propulsion.")))
    if pose_input.elbow_angle_status != "Not measurable":
        metrics.append(Metric(name="Elbow angle", score=round(pose_input.elbow_angle_score, 2), status=pose_input.elbow_angle_status, explanation=f"Average elbow flexion around {pose_input.elbow_angle_degrees:.1f}°. " + ("Arm carriage may be too open or too tight; aim for compact relaxed elbows." if pose_input.elbow_angle_status != "Good" else "Elbow carriage is within an efficient range.")))
    if pose_input.shoulder_arm_independence_status != "Not measurable":
        metrics.append(Metric(name="Shoulder-arm independence", score=round(pose_input.shoulder_arm_independence_score, 2), status=pose_input.shoulder_arm_independence_status, explanation="Coupling between shoulder rotation and arm swing. " + ("Arms appear tied to torso rotation; maintain relaxed shoulders and independent arm rhythm." if pose_input.shoulder_arm_independence_status != "Good" else "Arms move independently of torso rotation, supporting efficiency.")))
    if pose_input.pelvic_drop_status != "Not measurable":
        metrics.append(Metric(name="Pelvic drop / hip symmetry", score=round(pose_input.pelvic_drop_score, 2), status=pose_input.pelvic_drop_status, explanation="Left-right hip height symmetry during running. " + ("Pelvic drop detected — suggests weak glute medius or hip abductor imbalance." if pose_input.pelvic_drop_status != "Good" else "Hip symmetry looks balanced through the gait cycle.")))
    if pose_input.step_symmetry_status != "Not measurable":
        metrics.append(Metric(name="Step symmetry", score=round(pose_input.step_symmetry_score, 2), status=pose_input.step_symmetry_status, explanation="Left-right ankle oscillation amplitude balance. " + ("Asymmetric stride detected — one leg is doing more work than the other, increasing injury risk." if pose_input.step_symmetry_status != "Good" else "Step symmetry looks well-balanced between left and right sides.")))
    if pose_input.head_forward_status != "Not measurable":
        metrics.append(Metric(name="Head forward position", score=round(pose_input.head_forward_score, 2), status=pose_input.head_forward_status, explanation="Nose horizontal offset from shoulder line, indicating forward head posture. " + ("Forward head detected — chin tuck and gaze-forward cues recommended." if pose_input.head_forward_status != "Good" else "Head position looks well-aligned over the shoulders.")))
    metrics.extend([
        Metric(name="Posture score", score=round(pose_input.posture_score, 2), status="Good" if pose_input.posture_score >= 0.75 else "Moderate" if pose_input.posture_score >= 0.50 else "Needs work", explanation="Composite posture score across trunk lean, shoulder elevation, and head position."),
        Metric(name="Efficiency score", score=round(pose_input.efficiency_score, 2), status="Good" if pose_input.efficiency_score >= 0.75 else "Moderate" if pose_input.efficiency_score >= 0.50 else "Needs work", explanation="Composite efficiency score across cadence, overstride risk, and vertical oscillation."),
        Metric(name="Stability score", score=round(pose_input.stability_score, 2), status="Good" if pose_input.stability_score >= 0.75 else "Moderate" if pose_input.stability_score >= 0.50 else "Needs work", explanation="Composite stability score across knee tracking, pelvic control, and left-right step symmetry."),
        Metric(name="Propulsion score", score=round(pose_input.propulsion_score, 2), status="Good" if pose_input.propulsion_score >= 0.75 else "Moderate" if pose_input.propulsion_score >= 0.50 else "Needs work", explanation="Composite propulsion score across cadence, overstride control, and backward elbow drive."),
        Metric(name="Arm mechanics score", score=round(pose_input.arm_mechanics_score, 2), status="Good" if pose_input.arm_mechanics_score >= 0.75 else "Moderate" if pose_input.arm_mechanics_score >= 0.50 else "Needs work", explanation="Composite arm mechanics score across arm swing, crossing, elbow angle, drive, and shoulder-arm independence."),
        Metric(name="Symmetry score", score=round(pose_input.symmetry_score, 2), status="Good" if pose_input.symmetry_score >= 0.75 else "Moderate" if pose_input.symmetry_score >= 0.50 else "Needs work", explanation="Composite left-right symmetry score for lower-body and arm swing balance."),
        Metric(name="Injury risk score", score=round(pose_input.injury_risk_score, 2), status="Needs work" if pose_input.injury_risk_score >= 0.65 else "Moderate" if pose_input.injury_risk_score >= 0.40 else "Good", explanation="Estimated injury likelihood derived from instability, asymmetry, overstride, and load-transfer metrics."),
    ])

    all_notes = pose_input.notes + pose_input.quality_notes
    notes_str = " Notes: " + "; ".join(all_notes) if all_notes else ""
    vert_osc_line = f"\n- Vertical oscillation: score {pose_input.vertical_oscillation_score:.2f} | {pose_input.vertical_oscillation_status}" if pose_input.vertical_oscillation_status != "Not measurable" else ""
    shoulder_line = f"\n- Shoulder elevation: score {pose_input.shoulder_elevation_score:.2f} | {pose_input.shoulder_elevation_status}" if pose_input.shoulder_elevation_status != "Not measurable" else ""
    arm_swing_line = f"\n- Arm swing: score {pose_input.arm_swing_score:.2f} | {pose_input.arm_swing_status}" if pose_input.arm_swing_status != "Not measurable" else ""
    arm_cross_line = f"\n- Arm crossing (knitting): score {pose_input.arm_crossing_score:.2f} | {pose_input.arm_crossing_status} | direction {pose_input.arm_crossing_direction}" if pose_input.arm_crossing_status != "Not measurable" else ""
    elbow_drive_line = f"\n- Backward elbow drive: {pose_input.backward_elbow_drive_angle_degrees:.1f}° | score {pose_input.backward_elbow_drive_score:.2f} | {pose_input.backward_elbow_drive_status}" if pose_input.backward_elbow_drive_status != "Not measurable" else ""
    elbow_angle_line = f"\n- Elbow angle: {pose_input.elbow_angle_degrees:.1f}° | score {pose_input.elbow_angle_score:.2f} | {pose_input.elbow_angle_status}" if pose_input.elbow_angle_status != "Not measurable" else ""
    shoulder_arm_line = f"\n- Shoulder-arm independence: score {pose_input.shoulder_arm_independence_score:.2f} | {pose_input.shoulder_arm_independence_status}" if pose_input.shoulder_arm_independence_status != "Not measurable" else ""
    pelvic_drop_line = f"\n- Pelvic drop / hip symmetry: score {pose_input.pelvic_drop_score:.2f} | {pose_input.pelvic_drop_status}" if pose_input.pelvic_drop_status != "Not measurable" else ""
    step_symmetry_line = f"\n- Step symmetry: score {pose_input.step_symmetry_score:.2f} | {pose_input.step_symmetry_status}" if pose_input.step_symmetry_status != "Not measurable" else ""
    head_forward_line = f"\n- Head forward position: score {pose_input.head_forward_score:.2f} | {pose_input.head_forward_status}" if pose_input.head_forward_status != "Not measurable" else ""
    composite_scores_line = f"\n- Composite scores (0-100): posture {pose_input.posture_score * 100:.0f}, efficiency {pose_input.efficiency_score * 100:.0f}, stability {pose_input.stability_score * 100:.0f}, propulsion {pose_input.propulsion_score * 100:.0f}, arm mechanics {pose_input.arm_mechanics_score * 100:.0f}, symmetry {pose_input.symmetry_score * 100:.0f}, injury risk {pose_input.injury_risk_score * 100:.0f}"
    profile_lines: list[str] = []
    if pose_input.gender:
        profile_lines.append(f"- Gender: {pose_input.gender}")
    if pose_input.shoe_size:
        profile_lines.append(f"- Shoe size: {pose_input.shoe_size}")
    if pose_input.leg_length_cm is not None:
        profile_lines.append(f"- Leg length: {pose_input.leg_length_cm:.1f} cm")
    if pose_input.shoe_brand_model:
        profile_lines.append(f"- Shoe brand/model: {pose_input.shoe_brand_model}")
    profile_context_block = "\nRunner profile context (self-reported):\n" + "\n".join(profile_lines) if profile_lines else ""
    user_message = f"""Running form metrics from on-device Apple Vision pose detection:
- Capture mode: {pose_input.video_mode}
- Video quality: {quality_pct}% | pose detection rate {pose_input.pose_detection_rate:.2f}
- Cadence: {pose_input.cadence_estimate_spm:.0f} steps/min | score {pose_input.cadence_score:.2f} | {pose_input.cadence_status}
- Overstride risk: score {pose_input.overstride_risk_score:.2f} | {pose_input.overstride_status}
- Trunk lean: {pose_input.trunk_lean_degrees:.1f}° | score {pose_input.trunk_lean_score:.2f} | {pose_input.trunk_lean_status}
- Knee valgus / hip stability: score {pose_input.knee_valgus_risk_score:.2f} | {pose_input.knee_valgus_status}{vert_osc_line}{shoulder_line}{arm_swing_line}{arm_cross_line}{elbow_drive_line}{elbow_angle_line}{shoulder_arm_line}{pelvic_drop_line}{step_symmetry_line}{head_forward_line}{composite_scores_line}
- Frames analyzed: {pose_input.frame_count} over {pose_input.video_duration_seconds:.1f}s{notes_str}
{profile_context_block}
Generate targeted coaching issues and exercise recommendations based on these measurements."""

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": _build_metrics_prompt(pose_input.language)}, {"role": "user", "content": user_message}],
        max_tokens=1500,
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content)

    # --- Form Score: weighted average of biomechanical metric values ---
    # Cadence is excluded when "Not measurable" so it doesn't unfairly tank the score.
    # Weights reflect injury-risk significance: cadence + overstride highest.
    form_components: list[tuple[float, float]] = []  # (score, weight)
    if pose_input.cadence_status != "Not measurable":
        form_components.append((pose_input.cadence_score, 0.30))
    form_components.append((pose_input.overstride_risk_score, 0.25))
    form_components.append((pose_input.trunk_lean_score, 0.25))
    form_components.append((pose_input.knee_valgus_risk_score, 0.20))

    total_weight = sum(w for _, w in form_components)
    form_score = sum(s * w for s, w in form_components) / total_weight

    # --- Quality factor: poor video reduces trust in the form score ---
    # A perfect video gives full form score. A poor video (0.4) caps it at ~70%.
    # This means good video does NOT inflate the score — only bad video deflates it.
    quality_factor = min(1.0, 0.70 + 0.30 * pose_input.video_quality_score)
    final_score = round(form_score * quality_factor, 2)

    return AnalysisResponse(
        summary=data["summary"],
        confidence=final_score,
        metrics=metrics,
        issues=_parse_issues(data),
        video_quality_score=round(pose_input.video_quality_score, 2),
        quality_notes=pose_input.quality_notes,
    )


def generate_plan(plan_input: TrainingPlanInput) -> TrainingPlanResponse:
    return generate_training_plan(plan_input)
