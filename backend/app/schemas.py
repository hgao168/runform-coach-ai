from pydantic import BaseModel
from typing import List, Optional

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
    pelvic_drop_score: float = 0.0
    pelvic_drop_status: str = "Not measurable"
    step_symmetry_score: float = 0.0
    step_symmetry_status: str = "Not measurable"
    head_forward_score: float = 0.0
    head_forward_status: str = "Not measurable"
    frame_count: int
    video_duration_seconds: float
    notes: List[str] = []
    video_quality_score: float = 0.7
    pose_detection_rate: float = 0.0
    quality_notes: List[str] = []
    video_mode: str = "side"


class FormIssueContext(BaseModel):
    title: str
    severity: str = "Medium"
    explanation: str = ""
    exercise_names: List[str] = []


class TrainingPlanInput(BaseModel):
    current_weekly_km: float
    target: str
    available_running_days: int = 3
    injury_flag: bool = False
    form_issues: List[FormIssueContext] = []
    recent_analysis_summary: Optional[str] = None
    recent_analysis_confidence: Optional[float] = None
    previous_week_summary: Optional[str] = None


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
