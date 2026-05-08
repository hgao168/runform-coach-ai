from .schemas import MarathonPlanBlock, MarathonPlanWeek, PlannedWorkout, TrainingPlanInput, TrainingPlanResponse


DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

MAJOR_MARATHON_PROFILES: dict[str, dict[str, str]] = {
    "Tokyo": {
        "course_profile": "Mostly flat with long rhythm sections and mild rollers.",
        "elevation_note": "Stay patient early, then lock into even pacing after halfway.",
        "terrain_focus": "steady rhythm"
    },
    "Boston": {
        "course_profile": "Net downhill early, then late-race climbing through Newton hills.",
        "elevation_note": "Protect quads downhill and reserve effort for climbs after 30 km.",
        "terrain_focus": "downhill control + late hills"
    },
    "London": {
        "course_profile": "Very flat and fast urban course with stable pacing opportunities.",
        "elevation_note": "Practice strict pace discipline to avoid overcooking early splits.",
        "terrain_focus": "pace precision"
    },
    "Berlin": {
        "course_profile": "Flat, PR-friendly profile with minimal elevation change.",
        "elevation_note": "Build lactate-threshold durability for sustained marathon pace.",
        "terrain_focus": "marathon-pace economy"
    },
    "Chicago": {
        "course_profile": "Flat and fast, but often exposed to wind on long straights.",
        "elevation_note": "Train effort-based pacing and wind-adjusted rhythm.",
        "terrain_focus": "wind-resilient pacing"
    },
    "New York City": {
        "course_profile": "Bridge climbs and rolling terrain with demanding final 10 km.",
        "elevation_note": "Prepare for repeated climbs and controlled surges over bridges.",
        "terrain_focus": "rolling hills + bridges"
    },
    "Sydney": {
        "course_profile": "Undulating route with harbor-side elevation changes.",
        "elevation_note": "Build climbing efficiency and downhill composure for variable grade.",
        "terrain_focus": "rolling terrain"
    },
}


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


def _build_marathon_block(inp: TrainingPlanInput, weekly_km: float) -> MarathonPlanBlock | None:
    if inp.target != "Marathon" or not inp.include_marathon_block:
        return None

    requested_weeks = inp.marathon_plan_weeks if inp.marathon_plan_weeks in {12, 16} else 16
    race = inp.marathon_major or "Berlin"
    profile = MAJOR_MARATHON_PROFILES.get(race, MAJOR_MARATHON_PROFILES["Berlin"])

    peak_km = max(weekly_km * 1.45, 55.0)
    taper_weeks = 2 if requested_weeks == 12 else 3
    taper_start = requested_weeks - taper_weeks + 1
    weeks: list[MarathonPlanWeek] = []

    for week in range(1, requested_weeks + 1):
        # Advanced Marathoning style progression:
        # - Mesocycles with cutback rhythm
        # - Medium-long run emphasis
        # - LT + VO2 + Marathon-pace specific workouts
        # - Progressive long runs with marathon-pace finish
        if requested_weeks == 16:
            base_end = 5
            build_end = 11
            peak_end = 13
        else:
            base_end = 3
            build_end = 8
            peak_end = 10

        if week < taper_start:
            progress = week / max(1, (taper_start - 1))
            cutback = week % 4 == 0
            wave = 0.90 if cutback else 1.0

            if week <= base_end:
                phase = "Base"
                km_factor = 0.86 + 0.18 * progress
                target_km = _round_half(min(peak_km * 0.88, peak_km * km_factor) * wave)
                long_run = _round_half(min(30.0, max(18.0, target_km * 0.36)))
                key_pool = [
                    "Lactate-threshold run: 6-10 km total at LT effort (continuous or cruise intervals).",
                    "General aerobic + 8-10 x 100 m strides; add a medium-long run (24-28% of weekly volume).",
                    "VO2 support: 5-8 x 800 m at roughly 5K effort with equal jog recovery.",
                ]
                key = key_pool[(week - 1) % len(key_pool)]
            elif week <= build_end:
                phase = "Specific"
                km_factor = 0.98 + 0.20 * progress
                target_km = _round_half(min(peak_km, peak_km * km_factor) * wave)
                long_run = _round_half(min(35.0, max(24.0, target_km * 0.40)))
                key_pool = [
                    "Marathon-pace workout: 3 x 5 km at MP with 1 km float jog.",
                    "Long run with quality finish: last 8-12 km at MP effort.",
                    "LT maintenance: 2 x 5 km at LT with short jog recovery + medium-long aerobic run.",
                ]
                key = key_pool[(week - base_end - 1) % len(key_pool)]
            else:
                phase = "Peak"
                km_factor = 1.0
                target_km = _round_half(min(peak_km, peak_km * km_factor) * wave)
                long_run = _round_half(min(35.0, max(28.0, target_km * 0.42)))
                key_pool = [
                    "Race-specific simulation: 16-22 km continuous at MP within long run.",
                    "Tune-up race week: 8-15 km race effort plus reduced long run load.",
                ]
                key = key_pool[(week - build_end - 1) % len(key_pool)]
        else:
            phase = "Taper"
            taper_index = week - taper_start
            if taper_weeks == 3:
                taper_factors = [0.80, 0.62, 0.46]
                taper_longs = [24.0, 18.0, 12.0]
            else:
                taper_factors = [0.70, 0.48]
                taper_longs = [20.0, 12.0]
            target_km = _round_half(max(26.0, peak_km * taper_factors[min(taper_index, len(taper_factors) - 1)]))
            long_run = _round_half(taper_longs[min(taper_index, len(taper_longs) - 1)])
            key = "Taper sharpening: short MP blocks, reduced volume, full recovery, and no accumulated fatigue."

        if race == "Boston":
            key += " Add downhill repeats and late-session uphill repeats for Newton simulation."
        elif race == "New York City":
            key += " Include bridge-style climbs inside long runs."
        elif race == "Chicago":
            key += " Practice pace by effort in windy conditions."
        elif race == "Sydney":
            key += " Add rolling hill continuous runs every 1-2 weeks."

        weeks.append(MarathonPlanWeek(
            week=week,
            phase=phase,
            target_km=target_km,
            long_run_km=long_run,
            key_workout=key,
            terrain_focus=profile["terrain_focus"],
        ))

    return MarathonPlanBlock(
        race=race,
        total_weeks=requested_weeks,
        course_profile=profile["course_profile"],
        elevation_note=profile["elevation_note"],
        weeks=weeks,
    )


def generate_training_plan(inp: TrainingPlanInput) -> TrainingPlanResponse:
    day_order = {day: idx for idx, day in enumerate(DAYS)}
    run_days = _resolve_run_days(inp)
    running_days = len(run_days)
    weekly_km = _planned_weekly_km(inp)
    marathon_block = _build_marathon_block(inp, weekly_km)

    notes: list[str] = [
        "Keep easy runs conversational; do not race the easy days.",
        "Stop or reduce volume if pain changes your stride or gets worse during the run.",
    ]
    if inp.injury_flag:
        notes.insert(0, "Injury flag is on: volume increase is capped and quality work is replaced with controlled easy running or mobility.")
    else:
        notes.insert(0, "Plan uses a conservative weekly progression from your current volume.")
    if marathon_block is not None:
        notes.insert(0, "Method: Advanced Marathoning philosophy (periodized mesocycles, medium-long runs, LT/VO2/MP progression, cutback rhythm, taper).")
        notes.insert(0, f"Marathon major selected: {marathon_block.race}. {marathon_block.elevation_note}")
        notes.insert(1, f"{marathon_block.total_weeks}-week race block generated for marathon-only progression.")

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
        marathon_plan=marathon_block,
    )
