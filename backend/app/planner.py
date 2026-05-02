from .schemas import PlannedWorkout, TrainingPlanInput, TrainingPlanResponse


DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def _round_half(value: float) -> float:
    return round(value * 2) / 2


def _target_cap(target: str) -> float:
    if target == "5K":
        return 30.0
    if target == "10K":
        return 45.0
    if target == "Half Marathon":
        return 60.0
    return 35.0


def _planned_weekly_km(inp: TrainingPlanInput) -> float:
    if inp.current_weekly_km <= 0:
        starter = 10.0 if inp.available_running_days <= 2 else 15.0
        return _round_half(starter)
    increase = 0.05 if inp.injury_flag else 0.10
    planned = inp.current_weekly_km * (1 + increase)
    planned = min(planned, _target_cap(inp.target))
    return _round_half(max(planned, min(inp.current_weekly_km, _target_cap(inp.target))))


def generate_training_plan(inp: TrainingPlanInput) -> TrainingPlanResponse:
    running_days = max(1, min(inp.available_running_days, 6))
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

    if running_days == 1:
        workouts.append(PlannedWorkout(
            day="Sat", title="Easy Run", category="Easy", distance_km=_round_half(weekly_km),
            intensity="Zone 2 / easy", details="Run relaxed. Add 4 × 15 sec light strides only if you feel good.",
            purpose="Build routine and aerobic base without overloading the week."
        ))
    elif running_days == 2:
        long_km = _round_half(weekly_km * 0.55)
        easy_km = _round_half(max(2.0, weekly_km - long_km))
        workouts.extend([
            PlannedWorkout(day="Tue", title="Easy Run", category="Easy", distance_km=easy_km, intensity="Zone 2 / easy", details="Relaxed pace, focus on smooth cadence.", purpose="Aerobic base and recovery-friendly volume."),
            PlannedWorkout(day="Sat", title="Long Run", category="Long", distance_km=long_km, intensity="Zone 2 / easy", details="Keep it controlled. Walk 30–60 sec if form breaks down.", purpose="Build endurance and durability."),
        ])
    else:
        long_km = _round_half(weekly_km * 0.35)
        quality_km = 0.0 if inp.injury_flag else _round_half(weekly_km * 0.22)
        remaining = max(0.0, weekly_km - long_km - quality_km)
        easy_count = running_days - (1 if quality_km > 0 else 0) - 1
        easy_km = _round_half(remaining / max(1, easy_count))

        workouts.append(PlannedWorkout(day="Tue", title="Easy Run", category="Easy", distance_km=easy_km, intensity="Zone 2 / easy", details="Conversational pace. Finish feeling fresh.", purpose="Build aerobic volume with low fatigue."))

        if quality_km > 0:
            quality_title = "5K Rhythm Session" if inp.target == "5K" else "Tempo Run" if inp.target in {"10K", "Half Marathon"} else "Light Quality Run"
            quality_details = (
                "Warm up 10 min, then 6 × 1 min faster / 1 min easy, cool down."
                if inp.target == "5K"
                else "Warm up 10 min, then 2 × 8 min comfortably hard with 3 min easy, cool down."
            )
            workouts.append(PlannedWorkout(day="Thu", title=quality_title, category="Quality", distance_km=quality_km, intensity="Moderate", details=quality_details, purpose="Improve speed endurance while keeping the session controlled."))
        else:
            workouts.append(PlannedWorkout(day="Thu", title="Controlled Easy Run", category="Easy", distance_km=easy_km, intensity="Easy", details="No speed work this week because injury flag is on.", purpose="Maintain frequency while reducing injury risk."))

        if running_days >= 4:
            workouts.append(PlannedWorkout(day="Fri", title="Recovery Run", category="Recovery", distance_km=easy_km, intensity="Very easy", details="Short and relaxed. Skip if tired or sore.", purpose="Add low-stress frequency."))
        if running_days >= 5:
            workouts.append(PlannedWorkout(day="Sun", title="Optional Easy Run", category="Easy", distance_km=easy_km, intensity="Easy", details="Only run if legs feel good; otherwise replace with walking.", purpose="Extra aerobic volume without intensity."))

        workouts.append(PlannedWorkout(day="Sat", title="Long Run", category="Long", distance_km=long_km, intensity="Zone 2 / easy", details="Keep a steady rhythm. Do not turn this into a tempo run.", purpose="Main endurance stimulus of the week."))

    workouts.append(PlannedWorkout(
        day="Mon", title="Strength / Mobility", category="Strength", distance_km=None, duration_minutes=strength_minutes,
        intensity="Low", details="Glute bridge, side plank, clamshell, calf raises, hip mobility.",
        purpose="Improve running durability and support better form."
    ))
    if strength_days >= 2:
        workouts.append(PlannedWorkout(
            day="Wed", title="Form Drills + Mobility", category="Mobility", distance_km=None, duration_minutes=15,
            intensity="Low", details="A-skip, wall drill, posture drill, light hip mobility.",
            purpose="Reinforce efficient movement without adding much fatigue."
        ))
    if strength_days >= 3:
        workouts.append(PlannedWorkout(
            day="Sun", title="Injury-Safe Mobility", category="Mobility", distance_km=None, duration_minutes=20,
            intensity="Very low", details="Gentle mobility and activation only. No painful movements.",
            purpose="Support recovery while injury flag is active."
        ))

    day_order = {day: idx for idx, day in enumerate(DAYS)}
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
