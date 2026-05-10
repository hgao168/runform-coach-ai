from pydantic import BaseModel
from typing import List, Optional


class AnalyzeProfileContext(BaseModel):
    gender: str = "unspecified"
    shoe_size: str = ""
    leg_length_cm: Optional[float] = None
    shoe_brand_model: str = ""
    weekly_mileage_km: Optional[float] = None
    running_days_per_week: Optional[int] = None
    injury_note: str = ""

class Metric(BaseModel):
    name: str
    score: float
    status: str
    explanation: str

class Exercise(BaseModel):
    name: str
    category: str
    sets: int
    reps: str
    frequency_per_week: int
    reason: str

class Issue(BaseModel):
    title: str
    severity: str
    explanation: str
    recommended_exercises: List[Exercise]

class AnalysisResponse(BaseModel):
    summary: str
    confidence: float
    metrics: List[Metric]
    issues: List[Issue]
    video_quality_score: Optional[float] = None
    quality_notes: List[str] = []

class PoseMetricsInput(BaseModel):
    cadence_estimate_spm: float
    cadence_score: float
    cadence_status: str
    overstride_risk_score: float
    overstride_status: str
    trunk_lean_degrees: float
    trunk_lean_score: float
    trunk_lean_status: str
    knee_valgus_risk_score: float
    knee_valgus_status: str
    vertical_oscillation_score: float = 0.5
    vertical_oscillation_status: str = "Not measurable"
    shoulder_elevation_score: float = 0.5
    shoulder_elevation_status: str = "Not measurable"
    arm_swing_score: float = 0.0
    arm_swing_status: str = "Not measurable"
    arm_crossing_score: float = 0.0
    arm_crossing_status: str = "Not measurable"
    arm_crossing_direction: str = "Not measurable"
    backward_elbow_drive_score: float = 0.0
    backward_elbow_drive_status: str = "Not measurable"
    backward_elbow_drive_angle_degrees: float = 0.0
    elbow_angle_score: float = 0.0
    elbow_angle_status: str = "Not measurable"
    elbow_angle_degrees: float = 0.0
    shoulder_arm_independence_score: float = 0.0
    shoulder_arm_independence_status: str = "Not measurable"
    pelvic_drop_score: float = 0.0
    pelvic_drop_status: str = "Not measurable"
    step_symmetry_score: float = 0.0
    step_symmetry_status: str = "Not measurable"
    head_forward_score: float = 0.0
    head_forward_status: str = "Not measurable"
    posture_score: float = 0.0
    efficiency_score: float = 0.0
    stability_score: float = 0.0
    propulsion_score: float = 0.0
    arm_mechanics_score: float = 0.0
    symmetry_score: float = 0.0
    injury_risk_score: float = 0.0
    frame_count: int
    video_duration_seconds: float
    notes: List[str] = []
    video_quality_score: float = 0.7
    pose_detection_rate: float = 0.0
    quality_notes: List[str] = []
    video_mode: str = "side"
    language: str = "en"
    gender: Optional[str] = None
    shoe_size: Optional[str] = None
    leg_length_cm: Optional[float] = None
    shoe_brand_model: Optional[str] = None

class FormIssueContext(BaseModel):
    title: str
    severity: str = "Medium"
    explanation: str = ""
    exercise_names: List[str] = []


class TrainingPlanInput(BaseModel):
    current_weekly_km: float
    target: str
    available_running_days: int = 3
    selected_run_days: List[str] = []
    injury_flag: bool = False
    form_issues: List[FormIssueContext] = []
    recent_analysis_summary: Optional[str] = None
    recent_analysis_confidence: Optional[float] = None
    previous_week_summary: Optional[str] = None
    language: str = "en"
    marathon_major: Optional[str] = None
    marathon_plan_weeks: Optional[int] = None
    include_marathon_block: bool = True

class PlannedWorkout(BaseModel):
    day: str
    title: str
    category: str
    intensity: str
    details: str
    purpose: str
    distance_km: Optional[float] = None
    duration_minutes: Optional[int] = None
    coaching_focus: Optional[str] = None


class MarathonPlanWeek(BaseModel):
    week: int
    phase: str
    target_km: float
    long_run_km: float
    key_workout: str
    terrain_focus: str
    workouts: List[PlannedWorkout] = []


class MarathonPlanBlock(BaseModel):
    race: str
    total_weeks: int
    plan_profile: str
    course_profile: str
    elevation_note: str
    weeks: List[MarathonPlanWeek]


class TrainingPlanResponse(BaseModel):
    summary: str
    target: str
    current_weekly_km: float
    planned_weekly_km: float
    running_days: int
    injury_adjusted: bool = False
    workouts: List[PlannedWorkout]
    notes: List[str] = []
    connected_analysis_used: bool = False
    marathon_plan: Optional[MarathonPlanBlock] = None


class StravaConnectResponse(BaseModel):
    authorize_url: str
    state: str


class StravaStatusResponse(BaseModel):
    connected: bool
    provider: str = "strava"
    provider_athlete_id: Optional[str] = None
    scope: Optional[str] = None
    expires_at: Optional[str] = None
    last_refresh_at: Optional[str] = None


class StravaDisconnectRequest(BaseModel):
    ios_user_id: str


class StravaCallbackResponse(BaseModel):
    connected: bool
    ios_user_id: str
    provider_athlete_id: str


# ── Elite athlete comparison ────────────────────────────────────────────────

class AthleteListItem(BaseModel):
    id: str
    name: str
    event: str
    nationality: str
    achievement: str
    photo_url: str


class AthleteProfile(BaseModel):
    id: str
    name: str
    event: str
    nationality: str
    achievement: str
    bio: str
    photo_url: str


class MetricComparison(BaseModel):
    metric: str
    metric_key: str
    user_score: float
    athlete_score: float
    user_label: str
    athlete_label: str
    user_value: float
    athlete_value: float
    gap: float
    gap_pct: float
    status: str  # "gap" | "on_par" | "ahead"


class CompareRequest(BaseModel):
    user_metrics: PoseMetricsInput
    athlete_id: str
    language: str = "en"


class CompareResponse(BaseModel):
    athlete: AthleteProfile
    comparisons: List[MetricComparison]
    top_gaps: List[str]
    coaching_narrative: str
    overall_similarity_score: float
