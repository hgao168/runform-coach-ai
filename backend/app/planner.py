from .schemas import PlannedWorkout, TrainingPlanInput, TrainingPlanResponse


DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def _round_half(value: float) -> float:
    return round(value * 2) / 2


def _planned_weekly_km(inp: TrainingPlanInput) -> float:
    n = len(inp.selected_run_days) if inp.selected_run_days else inp.available_running_days
    if inp.current_weekly_km <= 0:
        starter = 10.0 if n <= 2 else 15.0
        return _round_half(starter)
    planned = inp.current_weekly_km * 0.90 if inp.injury_flag else inp.current_weekly_km
    return _round_half(max(planned, 1.0))


def _resolve_run_days(inp: TrainingPlanInput) -> list[str]:
    """Return the sorted list of days the user wants to run on."""
    day_order = {day: idx for idx, day in enumerate(DAYS)}
    if inp.selected_run_days:
        valid = [d for d in inp.selected_run_days if d in day_order]
        if valid:
            return sorted(valid, key=lambda d: day_order[d])
    # Fallback: infer from count using sensible defaults
    defaults = ["Tue", "Thu", "Sat", "Fri", "Sun", "Mon", "Wed"]
    count = max(1, min(inp.available_running_days, 7))
    return sorted(defaults[:count], key=lambda d: day_order[d])


def generate_training_plan(inp: TrainingPlanInput) -> TrainingPlanResponse:
    day_order = {day: idx for idx, day in enumerate(DAYS)}
    run_days = _resolve_run_days(inp)
    running_days = len(run_days)
    weekly_km = _planned_weekly_km(inp)

    notes: list[str] = [
        "Keep easy runs conversational; do not race the easy days.",
        "Stop or reduce volume if pain changes your stride or gets worse during the run.",
    ]
    if inp.injury_flag:
        notes.insert(0, "Injury flag is on: volume increase is capped and quality work is replaced with controlled easy running or mobility.")
    else:
        notes.insert(0, "Plan uses a conservative weekly progression from your current volume.")

    workouts: list[PlannedWorkout] = []
    strength_days = 3 if inp.injury_flag else 2
    strength_minutes = 20 if inp.injury_flag else 15

    # ── Assign running workouts to selected days ───────────────────────────
    if running_days == 1:
        workouts.append(PlannedWorkout(
            day=run_days[0], title="Easy Run", category="Easy",
            distance_km=_round_half(weekly_km), intensity="Zone 2 / easy",
            details="Run relaxed. Add 4 × 15 sec light strides only if you feel good.",
            purpose="Build routine and aerobic base without overloading the week."
        ))
    elif running_days == 2:
        long_km = _round_half(weekly_km * 0.55)
        easy_km = _round_half(max(2.0, weekly_km - long_km))
        workouts.extend([
            PlannedWorkout(day=run_days[0], title="Easy Run", category="Easy",
                distance_km=easy_km, intensity="Zone 2 / easy",
                details="Relaxed pace, focus on smooth cadence.",
                purpose="Aerobic base and recovery-friendly volume."),
            PlannedWorkout(day=run_days[1], title="Long Run", category="Long",
                distance_km=long_km, intensity="Zone 2 / easy",
                details="Keep it controlled. Walk 30–60 sec if form breaks down.",
                purpose="Build endurance and durability."),
        ])
    else:
        long_km = _round_half(weekly_km * 0.35)
        quality_km = 0.0 if inp.injury_flag else _round_half(weekly_km * 0.22)

        long_day = run_days[-1]
        pre_long_day = run_days[-2]  # recovery day before long run (used when running_days >= 4)

        # Quality day: pick from middle of candidates, excluding long and pre-long
        quality_day = None
        if quality_km > 0:
            candidates = run_days[:-2]  # always >= 1 element when running_days >= 3
            quality_day = candidates[len(candidates) // 2]

        # Easy days: all run days except long, quality, and pre-long (when running_days >= 4)
        easy_days = [
            d for d in run_days
            if d != long_day
            and d != quality_day
            and not (running_days >= 4 and d == pre_long_day)
        ]
        # pre_long_day (Recovery Run) also uses easy_km, so include it in the denominator
        easy_like_count = len(easy_days) + (1 if running_days >= 4 else 0)
        easy_km = _round_half(max(0.0, weekly_km - long_km - quality_km) / max(1, easy_like_count))

        quality_title = "5K Rhythm Session" if inp.target == "5K" else "Tempo Run" if inp.target in {"10K", "Half Marathon"} else "Light Quality Run"
        quality_details = (
            "Warm up 10 min, then 6 × 1 min faster / 1 min easy, cool down."
            if inp.target == "5K"
            else "Warm up 10 min, then 2 × 8 min comfortably hard with 3 min easy, cool down."
        )

        for day in run_days:
            if day == long_day:
                workouts.append(PlannedWorkout(
                    day=day, title="Long Run", category="Long",
                    distance_km=long_km, intensity="Zone 2 / easy",
                    details="Keep a steady rhythm. Do not turn this into a tempo run.",
                    purpose="Main endurance stimulus of the week."
                ))
            elif day == quality_day:
                workouts.append(PlannedWorkout(
                    day=day, title=quality_title, category="Quality",
                    distance_km=quality_km, intensity="Moderate",
                    details=quality_details,
                    purpose="Improve speed endurance while keeping the session controlled."
                ))
            elif running_days >= 4 and day == pre_long_day:
                workouts.append(PlannedWorkout(
                    day=day, title="Recovery Run", category="Recovery",
                    distance_km=easy_km, intensity="Very easy",
                    details="Short and relaxed. Skip if tired or sore.",
                    purpose="Add low-stress frequency without accumulating fatigue before the long run."
                ))
            else:
                workouts.append(PlannedWorkout(
                    day=day, title="Easy Run", category="Easy",
                    distance_km=easy_km, intensity="Zone 2 / easy",
                    details="Conversational pace. Finish feeling fresh.",
                    purpose="Build aerobic volume with low fatigue."
                ))

    # ── Assign strength/mobility to non-run days ──────────────────────────
    non_run_days = [d for d in DAYS if d not in run_days]
    # Prefer Mon then Wed for strength/mobility; fall through to other free days
    preferred_order = ["Mon", "Wed"] + [d for d in non_run_days if d not in ("Mon", "Wed")]
    strength_slots = [d for d in preferred_order if d in non_run_days][:strength_days]

    strength_titles = [
        ("Strength / Mobility", "Strength", strength_minutes,
         "Glute bridge, side plank, clamshell, calf raises, hip mobility.",
         "Improve running durability and support better form."),
        ("Form Drills + Mobility", "Mobility", 15,
         "A-skip, wall drill, posture drill, light hip mobility.",
         "Reinforce efficient movement without adding much fatigue."),
        ("Injury-Safe Mobility", "Mobility", 20,
         "Gentle mobility and activation only. No painful movements.",
         "Support recovery while injury flag is active."),
    ]
    for slot, (title, category, duration, details, purpose) in zip(strength_slots, strength_titles):
        workouts.append(PlannedWorkout(
            day=slot, title=title, category=category,
            distance_km=None, duration_minutes=duration,
            intensity="Low" if category == "Strength" else "Very low" if inp.injury_flag and category == "Mobility" else "Low",
            details=details, purpose=purpose
        ))

    workouts.sort(key=lambda w: day_order.get(w.day, 99))

    return TrainingPlanResponse(
        summary=f"Next week: {weekly_km:g} km across {running_days} running day(s), targeting {inp.target}.",
        target=inp.target,
        current_weekly_km=inp.current_weekly_km,
        planned_weekly_km=weekly_km,
        running_days=running_days,
        injury_adjusted=inp.injury_flag,
        workouts=workouts,
        notes=notes,
    )
