from pathlib import Path

ROOT = Path.cwd()

def patch_file(rel, fn):
    path = ROOT / rel
    if not path.exists():
        raise FileNotFoundError(f"Missing {rel}. Run this script from the repo root.")
    text = path.read_text(encoding='utf-8')
    new = fn(text)
    if new == text:
        print(f"WARN: no change for {rel}")
    else:
        path.write_text(new, encoding='utf-8')
        print(f"patched {rel}")

# 1) iOS Models.swift: extend TrainingPlanInput with latest analysis context

def patch_models(text: str) -> str:
    old = 'struct TrainingPlanInput: Codable { let currentWeeklyKm: Double let target: String let availableRunningDays: Int let injuryFlag: Bool enum CodingKeys: String, CodingKey { case currentWeeklyKm = "current_weekly_km" case target case availableRunningDays = "available_running_days" case injuryFlag = "injury_flag" } }'
    new = 'struct TrainingPlanInput: Codable { let currentWeeklyKm: Double let target: String let availableRunningDays: Int let injuryFlag: Bool let formIssues: [String] let recommendedExercises: [Exercise] enum CodingKeys: String, CodingKey { case currentWeeklyKm = "current_weekly_km" case target case availableRunningDays = "available_running_days" case injuryFlag = "injury_flag" case formIssues = "form_issues" case recommendedExercises = "recommended_exercises" } }'
    if old in text:
        return text.replace(old, new)
    # fallback: already patched or formatted differently
    if 'let formIssues: [String]' not in text:
        text = text.replace('let injuryFlag: Bool enum CodingKeys', 'let injuryFlag: Bool let formIssues: [String] let recommendedExercises: [Exercise] enum CodingKeys')
        text = text.replace('case injuryFlag = "injury_flag"', 'case injuryFlag = "injury_flag" case formIssues = "form_issues" case recommendedExercises = "recommended_exercises"')
    return text

# 2) iOS PlanBuilderView.swift: read latest analysis from AppStore and send to backend

def patch_plan_builder(text: str) -> str:
    # Add a small card after inputCard so user knows latest analysis is being used
    text = text.replace('introCard inputCard generateButton', 'introCard inputCard latestAnalysisCard generateButton')

    marker = 'private var generateButton: some View {'
    insert = '''private var latestAnalysisItem: AnalysisHistoryItem? { appStore.history.first } private var latestFormIssues: [String] { Array((latestAnalysisItem?.result.issues.map { $0.title } ?? []).prefix(5)) } private var latestRecommendedExercises: [Exercise] { var seen = Set<String>(); return (latestAnalysisItem?.result.issues.flatMap { $0.recommendedExercises } ?? []).filter { exercise in if seen.contains(exercise.name) { return false }; seen.insert(exercise.name); return true } } private var latestAnalysisCard: some View { Group { if let latest = latestAnalysisItem { DarkCard { VStack(alignment: .leading, spacing: 10) { SectionTitle("Connected coaching", subtitle: "Using your latest form analysis to adjust the plan.", systemImage: "link.circle.fill") if latestFormIssues.isEmpty { Text("No major form issue found in your latest analysis.") .font(.caption) .foregroundStyle(.white.opacity(0.65)) } else { ForEach(latestFormIssues, id: \\.self) { issue in Label(issue, systemImage: "figure.run.circle") .font(.caption) .foregroundStyle(.white.opacity(0.78)) } } Text("Latest analysis: \\(latest.createdAt, format: .dateTime.month().day().hour().minute())") .font(.caption2) .foregroundStyle(.white.opacity(0.42)) } } } else { DarkCard { VStack(alignment: .leading, spacing: 8) { SectionTitle("Connected coaching", subtitle: "Generate an analysis first to personalise this plan with form issues.", systemImage: "link.circle") Text("Without an analysis, RunForm will create a plan from your weekly km, goal, days, and injury flag only.") .font(.caption) .foregroundStyle(.white.opacity(0.62)) } } } } } '''
    if marker in text and 'private var latestAnalysisCard' not in text:
        text = text.replace(marker, insert + marker)

    old_input = 'let input = TrainingPlanInput( currentWeeklyKm: km, target: target.rawValue, availableRunningDays: availableRunningDays, injuryFlag: injuryFlag )'
    new_input = 'let input = TrainingPlanInput( currentWeeklyKm: km, target: target.rawValue, availableRunningDays: availableRunningDays, injuryFlag: injuryFlag, formIssues: latestFormIssues, recommendedExercises: latestRecommendedExercises )'
    text = text.replace(old_input, new_input)
    return text

# 3) Backend schemas.py: add form_issues and recommended_exercises to TrainingPlanInput

def patch_schemas(text: str) -> str:
    old = 'class TrainingPlanInput(BaseModel): current_weekly_km: float target: str available_running_days: int = 3 injury_flag: bool = False'
    new = 'class TrainingPlanInput(BaseModel): current_weekly_km: float target: str available_running_days: int = 3 injury_flag: bool = False form_issues: List[str] = Field(default_factory=list) recommended_exercises: List[Exercise] = Field(default_factory=list)'
    if old in text:
        return text.replace(old, new)
    if 'form_issues:' not in text:
        text = text.replace('injury_flag: bool = False', 'injury_flag: bool = False form_issues: List[str] = Field(default_factory=list) recommended_exercises: List[Exercise] = Field(default_factory=list)')
    return text

# 4) Backend analyzer.py: send analysis context to LLM and deterministically enhance plan

def patch_analyzer(text: str) -> str:
    # Prompt additions
    text = text.replace('- Non-running days should NOT appear in the workouts array.', '- Non-running days should NOT appear in the workouts array. - Use form_issues and recommended_exercises to adjust workout purpose/details. Example: overstride or low cadence => cadence focus; hip drop or knee valgus => hip stability strength; trunk lean => posture/falling-start drills. - Add coach notes that explain how the latest analysis changed the plan.')

    helper_marker = 'def generate_plan(plan_input: TrainingPlanInput) -> TrainingPlanResponse:'
    helpers = r'''def _normalise_issue_text(plan_input: TrainingPlanInput) -> str:
    issue_text = " ".join(plan_input.form_issues or []).lower()
    exercise_text = " ".join(e.name for e in (plan_input.recommended_exercises or [])).lower()
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
    for exercise in plan_input.recommended_exercises or []:
        if exercise.name not in seen:
            names.append(exercise.name)
            seen.add(exercise.name)
        if len(names) >= limit:
            break
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
    )


'''
    if helper_marker in text and '_enhance_plan_with_form_context' not in text:
        text = text.replace(helper_marker, helpers + helper_marker)

    old_user_msg = 'user_message = json.dumps({ "current_weekly_km": plan_input.current_weekly_km, "target": plan_input.target, "available_running_days": plan_input.available_running_days, "injury_flag": plan_input.injury_flag, })'
    new_user_msg = 'user_message = json.dumps({ "current_weekly_km": plan_input.current_weekly_km, "target": plan_input.target, "available_running_days": plan_input.available_running_days, "injury_flag": plan_input.injury_flag, "form_issues": plan_input.form_issues, "recommended_exercises": [e.model_dump() for e in plan_input.recommended_exercises], "coaching_focus_notes": _coaching_focus_notes(plan_input), })'
    text = text.replace(old_user_msg, new_user_msg)

    old_return = 'return TrainingPlanResponse( summary=data.get("summary", "Your personalised weekly training plan."), planned_weekly_km=float(data.get("planned_weekly_km", plan_input.current_weekly_km)), running_days=int(data.get("running_days", plan_input.available_running_days)), workouts=workouts, notes=data.get("notes", []), )'
    new_return = 'plan = TrainingPlanResponse( summary=data.get("summary", "Your personalised weekly training plan."), planned_weekly_km=float(data.get("planned_weekly_km", plan_input.current_weekly_km)), running_days=int(data.get("running_days", plan_input.available_running_days)), workouts=workouts, notes=data.get("notes", []), ) return _enhance_plan_with_form_context(plan, plan_input)'
    text = text.replace(old_return, new_return)
    return text

patch_file('ios/RunFormCoachAI/Models.swift', patch_models)
patch_file('ios/RunFormCoachAI/PlanBuilderView.swift', patch_plan_builder)
patch_file('backend/app/schemas.py', patch_schemas)
patch_file('backend/app/analyzer.py', patch_analyzer)

print('\nDone. Next steps:')
print('1. git diff')
print('2. Run backend tests / start FastAPI locally')
print('3. Rebuild iOS in Xcode')
print('4. Redeploy Railway so /training-plan accepts the new fields')
