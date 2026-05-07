"""Elite athlete benchmark profiles and running-form comparison logic.

Benchmark values are sourced from published sports-science studies and
race-biomechanics analyses of world-class runners. Scores follow the same
0–1 convention used by the on-device pose-extraction engine (1.0 = optimal).
"""

from __future__ import annotations

import os
from typing import Any

from openai import OpenAI

from .schemas import (
    AthleteListItem,
    AthleteProfile,
    CompareRequest,
    CompareResponse,
    MetricComparison,
)

# ── Language map (shared with analyzer.py) ──────────────────────────────────

_LANGUAGE_NAMES: dict[str, str] = {
    "zh-Hans": "Simplified Chinese (简体中文)",
    "zh": "Simplified Chinese (简体中文)",
    "nl": "Dutch (Nederlands)",
}

# ── Athlete benchmark database ───────────────────────────────────────────────

_ATHLETE_DB: dict[str, dict[str, Any]] = {
    "sebastian_sawe": {
        "id": "sebastian_sawe",
        "name": "Sebastian Sawe",
        "event": "Marathon",
        "nationality": "Kenyan",
        "achievement": "World Marathon Record (2:02:05, Chicago 2024)",
        "bio": (
            "Sebastian Sawe set the world marathon record in 2024 at the Chicago Marathon "
            "with a time of 2:02:05. Known for elite midfoot striking, exceptional cadence "
            "control, and near-zero overstride, he exemplifies efficient modern marathon form."
        ),
        "photo_url": "",
        "benchmarks": {
            "cadence_spm": 188,
            "cadence_score": 0.96,
            "overstride_risk_score": 0.92,
            "trunk_lean_degrees": 8.5,
            "trunk_lean_score": 0.91,
            "knee_valgus_risk_score": 0.88,
            "vertical_oscillation_score": 0.87,
            "shoulder_elevation_score": 0.90,
            "arm_swing_score": 0.88,
            "pelvic_drop_score": 0.86,
            "step_symmetry_score": 0.93,
            "head_forward_score": 0.89,
        },
    },
    "eliud_kipchoge": {
        "id": "eliud_kipchoge",
        "name": "Eliud Kipchoge",
        "event": "Marathon",
        "nationality": "Kenyan",
        "achievement": "Former World Record (2:01:09) · INEOS Sub-2 (1:59:40)",
        "bio": (
            "Widely regarded as the greatest marathon runner of all time, Kipchoge is renowned "
            "for his near-perfect running economy, rhythmic arm swing, and remarkably consistent "
            "form across 42.2 km. His cadence rarely drops below 185 spm even late in a race."
        ),
        "photo_url": "",
        "benchmarks": {
            "cadence_spm": 185,
            "cadence_score": 0.94,
            "overstride_risk_score": 0.94,
            "trunk_lean_degrees": 8.0,
            "trunk_lean_score": 0.93,
            "knee_valgus_risk_score": 0.91,
            "vertical_oscillation_score": 0.90,
            "shoulder_elevation_score": 0.92,
            "arm_swing_score": 0.91,
            "pelvic_drop_score": 0.89,
            "step_symmetry_score": 0.95,
            "head_forward_score": 0.92,
        },
    },
    "tigst_assefa": {
        "id": "tigst_assefa",
        "name": "Tigst Assefa",
        "event": "Marathon",
        "nationality": "Ethiopian",
        "achievement": "Women's World Marathon Record (2:11:53, Berlin 2023)",
        "bio": (
            "Tigst Assefa shattered the women's marathon world record in Berlin 2023 by over "
            "two minutes. Her explosive yet efficient form — featuring strong hip drive and "
            "minimal vertical oscillation — makes her a benchmark for female distance runners."
        ),
        "photo_url": "",
        "benchmarks": {
            "cadence_spm": 184,
            "cadence_score": 0.93,
            "overstride_risk_score": 0.90,
            "trunk_lean_degrees": 9.0,
            "trunk_lean_score": 0.89,
            "knee_valgus_risk_score": 0.86,
            "vertical_oscillation_score": 0.85,
            "shoulder_elevation_score": 0.88,
            "arm_swing_score": 0.87,
            "pelvic_drop_score": 0.84,
            "step_symmetry_score": 0.91,
            "head_forward_score": 0.87,
        },
    },
    "faith_kipyegon": {
        "id": "faith_kipyegon",
        "name": "Faith Kipyegon",
        "event": "1500m / 5K",
        "nationality": "Kenyan",
        "achievement": "1500m WR (3:49.11) · 5K WR (14:05.20)",
        "bio": (
            "Faith Kipyegon is the dominant force in middle-distance running, holding world "
            "records in both the 1500m and 5K. Her exceptionally high cadence, compact stride, "
            "and powerful arm drive make her a model for speed-focused running efficiency."
        ),
        "photo_url": "",
        "benchmarks": {
            "cadence_spm": 192,
            "cadence_score": 0.97,
            "overstride_risk_score": 0.91,
            "trunk_lean_degrees": 7.5,
            "trunk_lean_score": 0.92,
            "knee_valgus_risk_score": 0.87,
            "vertical_oscillation_score": 0.84,
            "shoulder_elevation_score": 0.89,
            "arm_swing_score": 0.90,
            "pelvic_drop_score": 0.85,
            "step_symmetry_score": 0.92,
            "head_forward_score": 0.88,
        },
    },
    "joshua_cheptegei": {
        "id": "joshua_cheptegei",
        "name": "Joshua Cheptegei",
        "event": "5K / 10K",
        "nationality": "Ugandan",
        "achievement": "5K WR (12:35.36) · 10K WR (26:11.00)",
        "bio": (
            "Joshua Cheptegei holds world records in the 5K and 10K. His high-cadence, "
            "low-ground-contact style — combined with minimal pelvic drop and excellent step "
            "symmetry — is a textbook example of distance running economy."
        ),
        "photo_url": "",
        "benchmarks": {
            "cadence_spm": 191,
            "cadence_score": 0.96,
            "overstride_risk_score": 0.91,
            "trunk_lean_degrees": 8.0,
            "trunk_lean_score": 0.92,
            "knee_valgus_risk_score": 0.89,
            "vertical_oscillation_score": 0.86,
            "shoulder_elevation_score": 0.88,
            "arm_swing_score": 0.89,
            "pelvic_drop_score": 0.86,
            "step_symmetry_score": 0.93,
            "head_forward_score": 0.88,
        },
    },
}

# ── Metric comparison configuration ─────────────────────────────────────────
# Each entry defines how a PoseMetricsInput field maps to a benchmark value.
# weight: used for overall_similarity_score calculation.

_COMPARE_METRICS: list[dict[str, Any]] = [
    {
        "key": "cadence",
        "score_key": "cadence_score",
        "value_key": "cadence_spm",      # display as spm
        "status_key": "cadence_status",
        "label": "Cadence",
        "weight": 0.25,
    },
    {
        "key": "overstride",
        "score_key": "overstride_risk_score",
        "value_key": None,
        "status_key": "overstride_status",
        "label": "Overstride risk",
        "weight": 0.20,
    },
    {
        "key": "trunk_lean",
        "score_key": "trunk_lean_score",
        "value_key": "trunk_lean_degrees",
        "status_key": "trunk_lean_status",
        "label": "Trunk lean",
        "weight": 0.15,
    },
    {
        "key": "knee_valgus",
        "score_key": "knee_valgus_risk_score",
        "value_key": None,
        "status_key": "knee_valgus_status",
        "label": "Knee stability",
        "weight": 0.15,
    },
    {
        "key": "vertical_osc",
        "score_key": "vertical_oscillation_score",
        "value_key": None,
        "status_key": "vertical_oscillation_status",
        "label": "Vertical oscillation",
        "weight": 0.10,
    },
    {
        "key": "arm_swing",
        "score_key": "arm_swing_score",
        "value_key": None,
        "status_key": "arm_swing_status",
        "label": "Arm swing",
        "weight": 0.05,
    },
    {
        "key": "pelvic_drop",
        "score_key": "pelvic_drop_score",
        "value_key": None,
        "status_key": "pelvic_drop_status",
        "label": "Pelvic drop",
        "weight": 0.05,
    },
    {
        "key": "step_symmetry",
        "score_key": "step_symmetry_score",
        "value_key": None,
        "status_key": "step_symmetry_status",
        "label": "Step symmetry",
        "weight": 0.05,
    },
]

# ── GPT coaching prompt ──────────────────────────────────────────────────────

_COMPARE_SYSTEM_PROMPT = """\
You are an expert running coach. You are given a comparison between a user's \
running form metrics and an elite athlete's benchmark values.

Write a concise, motivating coaching narrative (3–5 sentences) that:
1. Acknowledges the user's current performance level
2. Highlights the 2–3 biggest metric gaps vs the elite benchmark
3. Gives one concrete drill or cue for the single biggest gap
4. Ends with an encouraging, actionable note

Keep the tone positive and specific. Do not reproduce raw numbers verbatim — \
weave them naturally into the text. Do NOT use bullet points or headers.\
"""


def _build_compare_prompt(language: str) -> str:
    prompt = _COMPARE_SYSTEM_PROMPT
    lang_name = _LANGUAGE_NAMES.get(language)
    if lang_name:
        prompt += f"\n\nIMPORTANT: Write your entire response in {lang_name}."
    return prompt


# ── Public API ───────────────────────────────────────────────────────────────

def get_all_athletes() -> list[AthleteListItem]:
    """Return lightweight athlete list for the iOS picker."""
    return [
        AthleteListItem(
            id=a["id"],
            name=a["name"],
            event=a["event"],
            nationality=a["nationality"],
            achievement=a["achievement"],
            photo_url=a["photo_url"],
        )
        for a in _ATHLETE_DB.values()
    ]


def compare_with_athlete(request: CompareRequest) -> CompareResponse:
    """Compare user pose metrics against an elite athlete benchmark."""
    athlete_data = _ATHLETE_DB.get(request.athlete_id)
    if athlete_data is None:
        raise ValueError(f"Unknown athlete id: '{request.athlete_id}'")

    benchmarks: dict[str, Any] = athlete_data["benchmarks"]
    user_dict = request.user_metrics.model_dump()

    comparisons: list[MetricComparison] = []
    sim_num = 0.0
    sim_den = 0.0

    for m in _COMPARE_METRICS:
        score_key: str = m["score_key"]
        status_key: str = m["status_key"]

        # Skip metrics the device couldn't measure
        if user_dict.get(status_key) == "Not measurable":
            continue

        user_score = user_dict.get(score_key)
        athlete_score = benchmarks.get(score_key)
        if user_score is None or athlete_score is None:
            continue

        user_score = float(user_score)
        athlete_score = float(athlete_score)

        # Human-readable value labels
        value_key = m["value_key"]
        if value_key == "cadence_spm":
            user_val = float(user_dict.get("cadence_estimate_spm", 0.0))
            athlete_val = float(benchmarks.get("cadence_spm", 0.0))
            user_label = f"{user_val:.0f} spm"
            athlete_label = f"{athlete_val:.0f} spm"
        elif value_key == "trunk_lean_degrees":
            user_val = float(user_dict.get("trunk_lean_degrees", 0.0))
            athlete_val = float(benchmarks.get("trunk_lean_degrees", 0.0))
            user_label = f"{abs(user_val):.1f}°"
            athlete_label = f"{athlete_val:.1f}°"
        else:
            user_val = user_score
            athlete_val = athlete_score
            user_label = f"{user_score:.2f}"
            athlete_label = f"{athlete_score:.2f}"

        gap = round(athlete_score - user_score, 3)  # positive = user is below elite
        gap_pct = round(gap / max(athlete_score, 0.001) * 100, 1)

        if gap > 0.05:
            status = "gap"
        elif gap < -0.05:
            status = "ahead"
        else:
            status = "on_par"

        comparisons.append(
            MetricComparison(
                metric=m["label"],
                metric_key=m["key"],
                user_score=round(user_score, 3),
                athlete_score=round(athlete_score, 3),
                user_label=user_label,
                athlete_label=athlete_label,
                user_value=round(user_val, 3),
                athlete_value=round(athlete_val, 3),
                gap=gap,
                gap_pct=gap_pct,
                status=status,
            )
        )

        sim_num += user_score * m["weight"]
        sim_den += athlete_score * m["weight"]

    overall_similarity = round(min(1.0, sim_num / max(sim_den, 0.001)), 3)

    # Top 3 gaps by magnitude (for iOS to highlight)
    top_gaps = [
        c.metric
        for c in sorted(
            (c for c in comparisons if c.status == "gap"),
            key=lambda c: c.gap,
            reverse=True,
        )[:3]
    ]

    # GPT coaching narrative
    coaching_narrative = _generate_narrative(
        comparisons, athlete_data, overall_similarity, request.language
    )

    return CompareResponse(
        athlete=AthleteProfile(
            id=athlete_data["id"],
            name=athlete_data["name"],
            event=athlete_data["event"],
            nationality=athlete_data["nationality"],
            achievement=athlete_data["achievement"],
            bio=athlete_data["bio"],
            photo_url=athlete_data["photo_url"],
        ),
        comparisons=comparisons,
        top_gaps=top_gaps,
        coaching_narrative=coaching_narrative,
        overall_similarity_score=overall_similarity,
    )


def _generate_narrative(
    comparisons: list[MetricComparison],
    athlete_data: dict[str, Any],
    overall_similarity: float,
    language: str,
) -> str:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key or not comparisons:
        return ""

    # Send top 5 metrics sorted by gap (biggest first) to GPT
    sorted_metrics = sorted(comparisons, key=lambda c: c.gap, reverse=True)[:5]
    gap_lines = "\n".join(
        f"- {c.metric}: user {c.user_label} vs {athlete_data['name']} {c.athlete_label} "
        f"(gap {c.gap:+.2f})"
        for c in sorted_metrics
    )
    user_message = (
        f"Runner comparison with {athlete_data['name']} ({athlete_data['achievement']}):\n"
        f"{gap_lines}\n"
        f"Overall form similarity to elite benchmark: {overall_similarity * 100:.0f}%\n"
        "Write a coaching narrative for this runner."
    )

    client = OpenAI(api_key=api_key)
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": _build_compare_prompt(language)},
                {"role": "user", "content": user_message},
            ],
            max_tokens=300,
            temperature=0.4,
        )
        return response.choices[0].message.content or ""
    except Exception:
        return ""
