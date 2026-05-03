#!/usr/bin/env python3
"""
Phase 5A patch for hgao168/runform-coach-ai
Feature: Connect Analyze -> Plan

Run from the root of your local repo:
  python apply_phase5a_connected_plan.py

Then:
  git diff
  git add ios/RunFormCoachAI backend/app
  git commit -m "Connect analysis results to adaptive training plan"
"""
from pathlib import Path
import re

ROOT = Path.cwd()
IOS = ROOT / "ios" / "RunFormCoachAI"
BACKEND = ROOT / "backend" / "app"


def read(p: Path) -> str:
    if not p.exists():
        raise FileNotFoundError(f"Missing file: {p}")
    return p.read_text(encoding="utf-8")


def write(p: Path, s: str) -> None:
    p.write_text(s, encoding="utf-8")
    print(f"updated {p}")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Could not find target block for {label}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# iOS: Models.swift
# ---------------------------------------------------------------------------
models_path = IOS / "Models.swift"
models = read(models_path)

if "struct FormIssueContext" not in models:
    marker = "struct TrainingPlanInput: Codable {"
    form_issue = """
struct FormIssueContext: Codable, Identifiable, Equatable {
    var id: String { title + severity }
    let title: String
    let severity: String
    let explanation: String
    let exerciseNames: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case severity
        case explanation
        case exerciseNames = "exercise_names"
    }
}

"""
    models = models.replace(marker, form_issue + marker, 1)

# Replace TrainingPlanInput block whether compact or formatted.
models = re.sub(
    r"struct TrainingPlanInput: Codable \{.*?enum CodingKeys: String, CodingKey \{.*?\}\s*\}",
    """struct TrainingPlanInput: Codable {
    let currentWeeklyKm: Double
    let target: String
    let availableRunningDays: Int
    let injuryFlag: Bool
    let formIssues: [FormIssueContext]
    let recentAnalysisSummary: String?
    let recentAnalysisConfidence: Double?

    init(
        currentWeeklyKm: Double,
        target: String,
        availableRunningDays: Int,
        injuryFlag: Bool,
        formIssues: [FormIssueContext] = [],
        recentAnalysisSummary: String? = nil,
        recentAnalysisConfidence: Double? = nil
    ) {
        self.currentWeeklyKm = currentWeeklyKm
        self.target = target
        self.availableRunningDays = availableRunningDays
        self.injuryFlag = injuryFlag
        self.formIssues = formIssues
        self.recentAnalysisSummary = recentAnalysisSummary
        self.recentAnalysisConfidence = recentAnalysisConfidence
    }

    enum CodingKeys: String, CodingKey {
        case currentWeeklyKm = "current_weekly_km"
        case target
        case availableRunningDays = "available_running_days"
        case injuryFlag = "injury_flag"
        case formIssues = "form_issues"
        case recentAnalysisSummary = "recent_analysis_summary"
        case recentAnalysisConfidence = "recent_analysis_confidence"
    }
}""",
    models,
    count=1,
    flags=re.S,
)

# Add optional response fields in a backward-compatible way.
models = models.replace(
    "struct PlannedWorkout: Codable, Identifiable, Equatable { var id: String { day + title } let day: String let title: String let category: String let intensity: String let details: String let purpose: String let distanceKm: Double? let durationMinutes: Int? enum CodingKeys: String, CodingKey { case day, title, category, intensity, details, purpose case distanceKm = \"distance_km\" case durationMinutes = \"duration_minutes\" } }",
    "struct PlannedWorkout: Codable, Identifiable, Equatable { var id: String { day + title } let day: String let title: String let category: String let intensity: String let details: String let purpose: String let distanceKm: Double? let durationMinutes: Int? let coachingFocus: String? enum CodingKeys: String, CodingKey { case day, title, category, intensity, details, purpose case distanceKm = \"distance_km\" case durationMinutes = \"duration_minutes\" case coachingFocus = \"coaching_focus\" } }",
)
models = models.replace(
    "struct TrainingPlanResponse: Codable, Equatable { let summary: String let plannedWeeklyKm: Double let runningDays: Int let workouts: [PlannedWorkout] let notes: [String] enum CodingKeys: String, CodingKey { case summary case plannedWeeklyKm = \"planned_weekly_km\" case runningDays = \"running_days\" case workouts case notes } }",
    "struct TrainingPlanResponse: Codable, Equatable { let summary: String let plannedWeeklyKm: Double let runningDays: Int let workouts: [PlannedWorkout] let notes: [String] let connectedAnalysisUsed: Bool? enum CodingKeys: String, CodingKey { case summary case plannedWeeklyKm = \"planned_weekly_km\" case runningDays = \"running_days\" case workouts case notes case connectedAnalysisUsed = \"connected_analysis_used\" } }",
)
write(models_path, models)


# ---------------------------------------------------------------------------
# iOS: AppStore.swift - expose latest analysis as coaching context
# ---------------------------------------------------------------------------
store_path = IOS / "AppStore.swift"
store = read(store_path)
if "latestCoachingIssues" not in store:
    insertion = """
    var latestCoachingIssues: [FormIssueContext] {
        guard let latest = history.first else { return [] }
        return latest.result.issues.map { issue in
            FormIssueContext(
                title: issue.title,
                severity: issue.severity,
                explanation: issue.explanation,
                exerciseNames: issue.recommendedExercises.map(\\.name)
            )
        }
    }

    var latestAnalysisSummary: String? {
        history.first?.result.summary
    }

    var latestAnalysisConfidence: Double? {
        history.first?.result.confidence
    }

"""
    store = store.replace("private let profileKey", insertion + "private let profileKey", 1)
write(store_path, store)


# ---------------------------------------------------------------------------
# iOS: PlanBuilderView.swift - show connected analysis and send it to backend
# ---------------------------------------------------------------------------
plan_path = IOS / "RunFormCoachAI" / "PlanBuilderView.swift"
if not plan_path.exists():
    plan_path = IOS / "PlanBuilderView.swift"
plan = read(plan_path)

if "connectedAnalysisCard" not in plan:
    plan = plan.replace("introCard inputCard generateButton", "introCard connectedAnalysisCard inputCard generateButton", 1)
    card = r'''
    private var connectedAnalysisCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    "Connected coaching",
                    subtitle: "Latest analysis will adjust your plan",
                    systemImage: "link.circle.fill"
                )

                if let summary = appStore.latestAnalysisSummary, !appStore.latestCoachingIssues.isEmpty {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(appStore.latestCoachingIssues.prefix(3)) { issue in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "target")
                                    .foregroundStyle(AppTheme.mint)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(issue.exerciseNames.prefix(3).joined(separator: " • "))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                        }
                    }
                } else {
                    Text("Analyze a running video first. Then RunForm will adapt your easy run cues, quality session, long run focus, and strength/mobility work from your latest form issues.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
        }
    }

'''
    plan = plan.replace("private var inputCard", card + "private var inputCard", 1)

# Send latest issues to backend when generating plan.
old_input = """let input = TrainingPlanInput( currentWeeklyKm: km, target: target.rawValue, availableRunningDays: availableRunningDays, injuryFlag: injuryFlag )"""
new_input = """let input = TrainingPlanInput(
            currentWeeklyKm: km,
            target: target.rawValue,
            availableRunningDays: availableRunningDays,
            injuryFlag: injuryFlag,
            formIssues: appStore.latestCoachingIssues,
            recentAnalysisSummary: appStore.latestAnalysisSummary,
            recentAnalysisConfidence: appStore.latestAnalysisConfidence
        )"""
if old_input in plan:
    plan = plan.replace(old_input, new_input, 1)
else:
    # tolerant regex for formatted variants
    plan = re.sub(
        r"let input = TrainingPlanInput\(\s*currentWeeklyKm:\s*km,\s*target:\s*target\.rawValue,\s*availableRunningDays:\s*availableRunningDays,\s*injuryFlag:\s*injuryFlag\s*\)",
        new_input,
        plan,
        count=1,
        flags=re.S,
    )

# Display coaching focus if backend returns it.
if "workout.coachingFocus" not in plan:
    plan = plan.replace(
        "Text(\"Why: \\(workout.purpose)\") .font(.caption) .foregroundStyle(.white.opacity(0.55))",
        """Text(\"Why: \\(workout.purpose)\") .font(.caption) .foregroundStyle(.white.opacity(0.55)) if let coachingFocus = workout.coachingFocus, !coachingFocus.isEmpty { Text(\"Form focus: \\(coachingFocus)\") .font(.caption.bold()) .foregroundStyle(AppTheme.mint) }""",
        1,
    )
write(plan_path, plan)


# ---------------------------------------------------------------------------
# Backend: schemas.py
# ---------------------------------------------------------------------------
schemas_path = BACKEND / "schemas.py"
schemas = read(schemas_path)

if "class FormIssueContext" not in schemas:
    schemas = schemas.replace(
        "class TrainingPlanInput(BaseModel):",
        """class FormIssueContext(BaseModel):
    title: str
    severity: str = "Medium"
    explanation: str = ""
    exercise_names: List[str] = []

class TrainingPlanInput(BaseModel):""",
        1,
    )

schemas = re.sub(
    r"class TrainingPlanInput\(BaseModel\):\s*current_weekly_km: float\s*target: str\s*available_running_days: int = 3\s*injury_flag: bool = False",
    """class TrainingPlanInput(BaseModel):
    current_weekly_km: float
    target: str
    available_running_days: int = 3
    injury_flag: bool = False
    form_issues: List[FormIssueContext] = []
    recent_analysis_summary: Optional[str] = None
    recent_analysis_confidence: Optional[float] = None""",
    schemas,
    count=1,
    flags=re.S,
)

schemas = re.sub(
    r"class PlannedWorkout\(BaseModel\):\s*day: str\s*title: str\s*category: str\s*intensity: str\s*details: str\s*purpose: str\s*distance_km: Optional\[float\] = None\s*duration_minutes: Optional\[int\] = None",
    """class PlannedWorkout(BaseModel):
    day: str
    title: str
    category: str
    intensity: str
    details: str
    purpose: str
    distance_km: Optional[float] = None
    duration_minutes: Optional[int] = None
    coaching_focus: Optional[str] = None""",
    schemas,
    count=1,
    flags=re.S,
)

schemas = re.sub(
    r"class TrainingPlanResponse\(BaseModel\):\s*summary: str\s*planned_weekly_km: float\s*running_days: int\s*workouts: List\[PlannedWorkout\]\s*notes: List\[str\] = \[\]",
    """class TrainingPlanResponse(BaseModel):
    summary: str
    planned_weekly_km: float
    running_days: int
    workouts: List[PlannedWorkout]
    notes: List[str] = []
    connected_analysis_used: bool = False""",
    schemas,
    count=1,
    flags=re.S,
)
write(schemas_path, schemas)


# ---------------------------------------------------------------------------
# Backend: analyzer.py - inject context into prompt and add deterministic focus
# ---------------------------------------------------------------------------
analyzer_path = BACKEND / "analyzer.py"
analyzer = read(analyzer_path)

if "_form_focus_from_issues" not in analyzer:
    helper = r'''

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
'''
    analyzer = analyzer.replace("def generate_plan(plan_input: TrainingPlanInput) -> TrainingPlanResponse:", helper + "\ndef generate_plan(plan_input: TrainingPlanInput) -> TrainingPlanResponse:", 1)

# Update plan prompt rules.
analyzer = analyzer.replace(
    "- Non-running days should NOT appear in the workouts array.",
    "- Non-running days should NOT appear in the workouts array.\n- If form_focus items are supplied, adapt run details and strength/mobility purpose to those issues.\n- Include strength/mobility work that supports the latest detected form issues when available.",
    1,
)

# Include form context in user_message.
analyzer = analyzer.replace(
    '"injury_flag": plan_input.injury_flag, })',
    '"injury_flag": plan_input.injury_flag, "recent_analysis_summary": plan_input.recent_analysis_summary, "recent_analysis_confidence": plan_input.recent_analysis_confidence, "form_focus": _form_focus_from_issues(plan_input), })',
    1,
)

# Add coaching_focus when reading LLM workouts.
analyzer = analyzer.replace(
    "duration_minutes=w.get(\"duration_minutes\"), ) for w in data.get(\"workouts\", []) ] return TrainingPlanResponse(",
    "duration_minutes=w.get(\"duration_minutes\"), coaching_focus=w.get(\"coaching_focus\"), ) for w in data.get(\"workouts\", []) ] form_focus = _form_focus_from_issues(plan_input) workouts = _apply_form_focus_to_workouts(workouts, form_focus) return TrainingPlanResponse(",
    1,
)

# Mark response as connected and add notes.
analyzer = analyzer.replace(
    "notes=data.get(\"notes\", []), )",
    "notes=(data.get(\"notes\", []) + ([\"Plan adapted from your latest RunForm analysis.\"] if _form_focus_from_issues(plan_input) else [])), connected_analysis_used=bool(_form_focus_from_issues(plan_input)), )",
    1,
)
write(analyzer_path, analyzer)

print("\nPhase 5A patch complete: Analyze -> Plan connected coaching loop added.")
