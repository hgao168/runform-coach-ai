from pydantic import BaseModel, Field
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
    strava_run_count: Optional[int] = None
    strava_longest_run_km: Optional[float] = None
    strava_avg_pace_s_per_km: Optional[float] = None
    strava_load_trend: Optional[str] = None
    training_level: Optional[str] = None
    plan_duration_weeks: Optional[int] = None
    include_race_block: bool = False

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


class RacePlanWeek(BaseModel):
    week: int
    phase: str
    target_km: float
    long_run_km: float
    key_workout: str
    workouts: List[PlannedWorkout] = []


class RacePlanBlock(BaseModel):
    target: str
    total_weeks: int
    level: str
    weeks: List[RacePlanWeek]


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
    race_plan: Optional[RacePlanBlock] = None


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
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )


class StravaDisconnectResponse(BaseModel):
    disconnected: bool = True
    provider: str = "strava"
    ios_user_id: str
    revoked: bool = False
    deleted_run_count: int = 0
    deleted_weekly_stat_count: int = 0
    message: str


class StravaSyncRequest(BaseModel):
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )


class StravaWeeklySummaryItem(BaseModel):
    week_start: str
    total_distance_km: float
    run_count: int
    longest_run_km: float
    avg_pace_s_per_km: Optional[float] = None
    intensity_score: Optional[float] = None


class StravaProfilePrefill(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    weight_kg: Optional[float] = None


class StravaSyncResponse(BaseModel):
    connected: bool = True
    ios_user_id: str
    lookback_days: int
    scanned_activity_count: int
    synced_run_count: int
    week_count: int
    synced_at: str
    weekly_stats: List[StravaWeeklySummaryItem] = []
    prefilled_profile: Optional[StravaProfilePrefill] = None


class StravaSummaryResponse(BaseModel):
    connected: bool = True
    ios_user_id: str
    weeks: int
    weekly_stats: List[StravaWeeklySummaryItem] = []
    total_distance_km: float
    average_weekly_km: float
    run_count: int
    longest_run_km: float
    avg_pace_s_per_km: Optional[float] = None
    intensity_estimate: Optional[float] = None
    load_trend: str
    trend_delta_pct: Optional[float] = None
    last_sync_at: Optional[str] = None


class StravaCallbackResponse(BaseModel):
    connected: bool
    ios_user_id: str
    provider_athlete_id: str


class ProfileSaveRequest(BaseModel):
    ios_user_id: str = Field(
        ...,
        min_length=3,
        max_length=128,
        pattern=r'^[a-zA-Z0-9._\-]+$',
        description="iOS user identifier",
    )
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    nickname: Optional[str] = None
    level: Optional[str] = None
    weekly_mileage_km: Optional[float] = None
    running_days_per_week: Optional[int] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    target: Optional[str] = None
    injury_note: Optional[str] = None
    gender: Optional[str] = None
    shoe_size: Optional[str] = None
    shoe_brand_model: Optional[str] = None
    leg_length_cm: Optional[float] = None
    date_of_birth: Optional[str] = None
    weekly_exercise_hours: Optional[float] = None


class ProfileSaveResponse(BaseModel):
    saved: bool
    ios_user_id: str

# ── Tester feedback ─────────────────────────────────────────────────────
# Mirrors the iOS AnalysisFeedback / FeedbackRating models

class FeedbackSubmitRequest(BaseModel):
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )
    analysis_id: str          # UUID of the AnalysisHistoryItem from iOS
    rating: str               # "Accurate" | "Partly accurate" | "Not accurate" | "Confusing"
    comment: str = ""

class FeedbackSubmitResponse(BaseModel):
    accepted: bool
    message: str


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


# ── Run Session schemas ─────────────────────────────────────────────────────

class RunSessionCreate(BaseModel):
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )
    start_time: str  # ISO 8601
    end_time: Optional[str] = None  # ISO 8601
    duration_sec: Optional[float] = None
    avg_cadence: Optional[float] = None
    avg_vertical_oscillation: Optional[float] = None
    avg_gct: Optional[float] = None
    metrics_json: Optional[dict] = None


class RunSessionResponse(BaseModel):
    id: int
    user_id: int
    ios_user_id: Optional[str] = None
    start_time: str
    end_time: Optional[str] = None
    duration_sec: Optional[float] = None
    avg_cadence: Optional[float] = None
    avg_vertical_oscillation: Optional[float] = None
    avg_gct: Optional[float] = None
    metrics_json: Optional[dict] = None
    created_at: str


class SessionTrendsResponse(BaseModel):
    ios_user_id: str
    session_count: int
    cadence: List[Optional[float]]
    vertical_oscillation: List[Optional[float]]
    gct: List[Optional[float]]


class SessionCompareRequest(BaseModel):
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )
    session_id_a: int
    session_id_b: int


class SessionMetricPair(BaseModel):
    metric: str
    session_a_value: Optional[float] = None
    session_b_value: Optional[float] = None
    delta: Optional[float] = None
    delta_pct: Optional[float] = None


class SessionCompareResponse(BaseModel):
    ios_user_id: str
    session_a: RunSessionResponse
    session_b: RunSessionResponse
    comparisons: List[SessionMetricPair]


# ── Weekly Insight schemas ─────────────────────────────────────────────────

class WeeklyInsightMetric(BaseModel):
    """Week-over-week change for a single metric."""
    metric: str                          # e.g. 'avg_cadence', 'avg_oscillation', 'avg_gct', 'distance', 'session_count'
    label: str                           # human-readable label
    current_week_avg: Optional[float] = None
    previous_week_avg: Optional[float] = None
    delta: Optional[float] = None        # absolute change
    delta_pct: Optional[float] = None    # percentage change
    trend: str = 'stable'                # 'improving' | 'declining' | 'stable'


class WeeklyInsightBadge(BaseModel):
    """Achievement badge earned this week."""
    id: str                              # e.g. 'consistency_streak', 'cadence_milestone'
    name: str
    description: str
    icon: str = ''                       # emoji or icon name


class WeeklyInsightResponse(BaseModel):
    """Aggregated weekly insight for the iOS/Android weekly report screen."""
    ios_user_id: str
    week_start: str                      # ISO date of the current week's Monday
    week_end: str                        # ISO date of the current week's Sunday
    current_week_session_count: int
    previous_week_session_count: int
    metrics: List[WeeklyInsightMetric]   # cadence, oscillation, gct, distance, sessions
    ai_coach_advice: str                 # AI-generated coaching narrative
    badges: List[WeeklyInsightBadge] = []


# ── RF-600: Invite code schemas ───────────────────────────────────────────

class InviteCodeGenerateRequest(BaseModel):
    user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )


class InviteCodeGenerateResponse(BaseModel):
    code: str
    created_at: str
    remaining: int


class InviteRedeemRequest(BaseModel):
    user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )
    code: str = Field(..., min_length=8, max_length=8)


class InviteRedeemResponse(BaseModel):
    success: bool
    message: str


class InviteStatusRedeemedUser(BaseModel):
    nickname: Optional[str] = None
    joined_at: str


class InviteStatusCodeItem(BaseModel):
    code: str
    created_at: str
    redeemed_count: int
    redeemed_users: List[InviteStatusRedeemedUser] = []


class InviteStatusResponse(BaseModel):
    codes: List[InviteStatusCodeItem] = []
    total_invited: int = 0


# ── RF-601: Challenge schemas ─────────────────────────────────────────────

class ChallengeInfo(BaseModel):
    id: str
    name: str
    description: str
    start_date: str
    end_date: str
    days: int  # duration of challenge in days
    participant_count: int
    status: str  # "active" | "ended"
    # N3: Personal participation state (only set when ios_user_id is provided)
    joined: Optional[bool] = None
    completed_days: Optional[int] = None
    today_completed: Optional[bool] = None


class ChallengeJoinRequest(BaseModel):
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )


class ChallengeJoinResponse(BaseModel):
    joined: bool
    challenge_id: str
    message: str


class ChallengeLeaderboardEntry(BaseModel):
    ios_user_id: str
    cadence_improvement_pct: Optional[float] = None
    oscillation_improvement_pct: Optional[float] = None
    overall_score_change: Optional[float] = None
    rank: int
    # N4: Rendering fields for frontend display
    display_name: Optional[str] = None
    completed_days: Optional[int] = None
    is_me: bool = False


# ── C5: Challenge check-in schemas ────────────────────────────────────────

class ChallengeCheckInRequest(BaseModel):
    user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\\-]+$'
    )


class ChallengeCheckInResponse(BaseModel):
    status: str
    check_in_count: int
    streak_days: int
    today_metrics: dict = {}


# ── C4: Club leaderboard schemas ──────────────────────────────────────────

class ClubLeaderboardEntry(BaseModel):
    rank: int
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    cadence: Optional[float] = None
    form_score: Optional[float] = None
    score_change: str = "→"  # "+" | "-" | "→"
    is_me: bool = False


class ClubLeaderboardResponse(BaseModel):
    members: list[ClubLeaderboardEntry] = []
    coming_soon: bool = False


# ── RF-602: Coach panel schemas ────────────────────────────────────────────


class CoachCodeGenerateRequest(BaseModel):
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )


class CoachCodeResponse(BaseModel):
    code: str
    student_limit: int
    created_at: str
    is_active: bool


class CoachJoinRequest(BaseModel):
    ios_user_id: str = Field(
        ..., min_length=3, max_length=128, pattern=r'^[a-zA-Z0-9._\-]+$'
    )
    code: str = Field(..., min_length=8, max_length=8)


class CoachJoinResponse(BaseModel):
    joined: bool
    coach_ios_user_id: str
    message: str


class CoachStudentResponse(BaseModel):
    ios_user_id: str
    nickname: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    joined_at: str
    student_note: Optional[str] = None


class CoachStudentFormSummary(BaseModel):
    """Latest run session form metrics for a student."""
    session_count: int
    latest_session_at: Optional[str] = None
    avg_cadence: Optional[float] = None
    avg_vertical_oscillation: Optional[float] = None
    avg_gct: Optional[float] = None
    overall_score: Optional[float] = None


class CoachDashboardResponse(BaseModel):
    coach_ios_user_id: str
    student_count: int
    students: List[CoachStudentResponse]
    form_summaries: List[CoachStudentFormSummary]
