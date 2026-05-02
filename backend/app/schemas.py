from typing import List, Optional, Literal
from pydantic import BaseModel, Field


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


class VideoQuality(BaseModel):
    score: float = Field(ge=0, le=1)
    status: str
    reasons: List[str] = []
    tips: List[str] = []


class AnalysisResponse(BaseModel):
    summary: str
    confidence: float
    quality: Optional[VideoQuality] = None
    metrics: List[Metric]
    issues: List[Issue]


class PoseMetricsInput(BaseModel):
    cadence_estimate_spm: float = 0
    cadence_score: float = 0.5
    cadence_status: str = "Not measurable"
    cadence_quality: str = "Low"
    cadence_step_count: int = 0
    overstride_risk_score: float
    overstride_status: str
    trunk_lean_degrees: float
    trunk_lean_score: float
    trunk_lean_status: str
    hip_drop_risk_score: float = 0.75
    hip_drop_status: str = "Good"
    arm_swing_score: float = 0.5
    arm_swing_status: str = "Good"
    frame_count: int
    sampled_frame_count: int = 0
    video_duration_seconds: float
    pose_detection_rate: float = 0
    ankle_visibility_rate: float = 0
    video_quality_score: float = 0.5
    quality_reasons: List[str] = []
    notes: List[str] = []


TrainingTarget = Literal["5K", "10K", "Half Marathon", "General Fitness"]


class TrainingPlanInput(BaseModel):
    current_weekly_km: float = Field(ge=0, le=250)
    target: TrainingTarget = "General Fitness"
    available_running_days: int = Field(ge=1, le=7)
    injury_flag: bool = False


class PlannedWorkout(BaseModel):
    day: str
    title: str
    category: str
    distance_km: Optional[float] = None
    duration_minutes: Optional[int] = None
    intensity: str
    details: str
    purpose: str


class TrainingPlanResponse(BaseModel):
    summary: str
    target: TrainingTarget
    current_weekly_km: float
    planned_weekly_km: float
    running_days: int
    injury_adjusted: bool
    workouts: List[PlannedWorkout]
    notes: List[str]
