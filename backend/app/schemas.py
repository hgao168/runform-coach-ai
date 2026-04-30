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
