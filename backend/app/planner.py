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


def _closest_am_profile(weekly_km: float) -> int:
    return 55 if abs(weekly_km - 55.0) <= abs(weekly_km - 70.0) else 70


def _key_workout_for_phase(phase: str, week: int, injury_flag: bool) -> str:
    if injury_flag:
        if phase == "Base":
            return "Aerobic progression run with short relaxed strides; keep effort controlled."
        if phase == "BuildUp":
            return "Steady aerobic run with brief marathon-effort blocks (no hard surges)."
        if phase == "Peak":
            return "Long run with controlled marathon-pace finish; stop if form degrades."
        return "Taper sharpening with short rhythm segments and full recovery."

    if phase == "Base":
        pool = [
            "Lactate-threshold session: 3 x 10 min at LT effort with short float recoveries.",
            "General aerobic run + 8-10 strides, plus a medium-long run in the same week.",
            "VO2 support: 6-8 x 800 m around 5K effort with equal jog recoveries.",
        ]
        return pool[(week - 1) % len(pool)]
    if phase == "BuildUp":
        pool = [
            "Marathon-pace session: 3 x 4-5 km at MP with 1 km float jog.",
            "Long run with quality finish: final 8-12 km around MP effort.",
            "LT maintenance: 2 x 5 km at LT with short jog recovery.",
        ]
        return pool[(week - 1) % len(pool)]
    if phase == "Peak":
        pool = [
            "Race-specific simulation: 14-20 km continuous at MP within the long run.",
            "Tune-up effort week: 8-12 km race effort with reduced total load.",
        ]
        return pool[(week - 1) % len(pool)]
    return "Taper sharpening: short MP blocks, reduced volume, and no residual fatigue."


def _build_marathon_week_workouts(
    run_days: list[str],
    target_km: float,
    long_run_km: float,
    phase: str,
    week: int,
    injury_flag: bool,
) -> list[PlannedWorkout]:
    if not run_days:
        return []

    n = len(run_days)
    slots: dict[str, str] = {run_days[-1]: "long"}

    if n == 1:
        pass
    elif n == 2:
        slots[run_days[0]] = "quality"
    else:
        pre_long_days = run_days[:-1]
        quality_day = pre_long_days[len(pre_long_days) // 2]
        slots[quality_day] = "quality"

        if n >= 4:
            medium_day = pre_long_days[-1]
            if medium_day == quality_day and len(pre_long_days) > 1:
                medium_day = pre_long_days[0]
            if medium_day != quality_day:
                slots[medium_day] = "medium"

        for idx, day in enumerate(pre_long_days):
            if day in slots:
                continue
            if n >= 5 and idx == 0:
                slots[day] = "recovery"
            else:
                slots[day] = "easy"

    long_run_km = min(long_run_km, target_km)
    remaining_km = max(0.0, target_km - long_run_km)

    non_long_days = [d for d in run_days if slots.get(d) != "long"]
    base_weights = {"quality": 1.25, "medium": 1.12, "easy": 1.0, "recovery": 0.82}
    weight_sum = sum(base_weights.get(slots[d], 1.0) for d in non_long_days)

    day_km: dict[str, float] = {run_days[-1]: _round_half(long_run_km)}
    for day in non_long_days:
        if weight_sum <= 0:
            planned = remaining_km / max(1, len(non_long_days))
        else:
            planned = remaining_km * (base_weights.get(slots[day], 1.0) / weight_sum)
        day_km[day] = _round_half(planned)

    total_assigned = sum(day_km.values())
    diff = _round_half(target_km - total_assigned)
    if non_long_days:
        day_km[non_long_days[0]] = _round_half(max(2.0, day_km[non_long_days[0]] + diff))

    quality_title = {
        "Base": "LT / Rhythm Session",
        "BuildUp": "Marathon Pace Session",
        "Peak": "Race-Specific Session",
        "Taper": "Taper Rhythm Session",
    }.get(phase, "Quality Session")

    workouts: list[PlannedWorkout] = []
    for day in run_days:
        slot = slots.get(day, "easy")
        km = day_km.get(day, _round_half(target_km / max(1, n)))

        if slot == "long":
            title = "Long Run"
            intensity = "Zone 2 / easy-moderate"
            details = "Progressively extend durability. Keep posture stable and fuel well."
            purpose = "Primary marathon-specific endurance stimulus."
            if phase in {"BuildUp", "Peak"}:
                details = "Include controlled marathon-pace finish in selected weeks."
        elif slot == "quality":
            title = quality_title
            intensity = "Moderate to moderately hard" if not injury_flag else "Controlled moderate"
            details = _key_workout_for_phase(phase, week, injury_flag)
            purpose = "Build marathon pace durability and economy."
        elif slot == "medium":
            title = "Medium Long Run"
            intensity = "Zone 2 steady"
            details = "Steady aerobic run at relaxed effort, slightly longer than easy days."
            purpose = "Increase aerobic volume without excessive fatigue."
        elif slot == "recovery":
            title = "Recovery Run"
            intensity = "Very easy"
            details = "Short and easy. Keep cadence relaxed and stop if soreness rises."
            purpose = "Absorb training and maintain frequency."
        else:
            title = "Easy Run"
            intensity = "Zone 2 / easy"
            details = "Conversational pace. Focus on smooth form and relaxed shoulders."
            purpose = "Add low-stress aerobic volume."

        workouts.append(PlannedWorkout(
            day=day,
            title=title,
            category="Marathon" if slot in {"quality", "long", "medium"} else "Easy",
            intensity=intensity,
            details=details,
            purpose=purpose,
            distance_km=km,
            duration_minutes=None,
            coaching_focus="Advanced Marathoning progression",
        ))

    return workouts


def _build_marathon_block(inp: TrainingPlanInput, weekly_km: float) -> MarathonPlanBlock | None:
    if inp.target != "Marathon" or not inp.include_marathon_block:
        return None

    requested_weeks = inp.marathon_plan_weeks if inp.marathon_plan_weeks in {12, 16} else 16
    race = inp.marathon_major or "Berlin"
    profile = MAJOR_MARATHON_PROFILES.get(race, MAJOR_MARATHON_PROFILES["Berlin"])

    run_days = _resolve_run_days(inp)
    am_profile_km = _closest_am_profile(weekly_km)
    profile_label = f"AM {am_profile_km}"

    start_km = max(16.0, weekly_km)
    if am_profile_km == 70:
        peak_km = min(78.0, max(64.0, start_km * 1.38))
    else:
        peak_km = min(62.0, max(52.0, start_km * 1.35))
    if inp.injury_flag:
        peak_km = _round_half(max(start_km, peak_km * 0.90))

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
                target_km = _round_half((start_km + (peak_km - start_km) * (0.45 * progress)) * wave)
                long_run = _round_half(min(30.0, max(16.0, target_km * 0.33)))
            elif week <= build_end:
                phase = "BuildUp"
                target_km = _round_half((start_km + (peak_km - start_km) * (0.75 + 0.20 * progress)) * wave)
                long_run = _round_half(min(35.0, max(20.0, target_km * 0.38)))
            else:
                phase = "Peak"
                target_km = _round_half(min(peak_km, peak_km * wave))
                long_run = _round_half(min(36.0, max(24.0, target_km * 0.41)))
        else:
            phase = "Taper"
            taper_index = week - taper_start
            if taper_weeks == 3:
                taper_factors = [0.80, 0.62, 0.46]
                taper_longs = [24.0, 18.0, 12.0]
            else:
                taper_factors = [0.70, 0.48]
                taper_longs = [20.0, 12.0]
            target_km = _round_half(max(24.0, peak_km * taper_factors[min(taper_index, len(taper_factors) - 1)]))
            long_run = _round_half(taper_longs[min(taper_index, len(taper_longs) - 1)])
        if week == 1:
            target_km = _round_half(start_km)

        key = _key_workout_for_phase(phase, week, inp.injury_flag)
        if race == "Boston":
            key += " Add downhill repeats and late-session uphill repeats for Newton simulation."
        elif race == "New York City":
            key += " Include bridge-style climbs inside long runs."
        elif race == "Chicago":
            key += " Practice pace by effort in windy conditions."
        elif race == "Sydney":
            key += " Add rolling hill continuous runs every 1-2 weeks."

        week_workouts = _build_marathon_week_workouts(
            run_days=run_days,
            target_km=target_km,
            long_run_km=long_run,
            phase=phase,
            week=week,
            injury_flag=inp.injury_flag,
        )

        weeks.append(MarathonPlanWeek(
            week=week,
            phase=phase,
            target_km=target_km,
            long_run_km=long_run,
            key_workout=key,
            terrain_focus=profile["terrain_focus"],
            workouts=week_workouts,
        ))

    return MarathonPlanBlock(
        race=race,
        total_weeks=requested_weeks,
        plan_profile=profile_label,
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
