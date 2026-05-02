from pydantic import BaseModel
from typing import List


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
    frame_count: int
    video_duration_seconds: float
    notes: List[str] = []
