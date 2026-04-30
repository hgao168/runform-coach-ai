from .schemas import AnalysisResponse, Metric, Issue, Exercise


def analyze_running_video_mock(filename: str) -> AnalysisResponse:
    """
    V1 mock analyzer.

    Replace this with real pose-analysis logic later:
    1. Extract frames from video.
    2. Detect landmarks using Apple Vision, MediaPipe, or OpenCV.
    3. Calculate joint angles and gait events.
    4. Map movement patterns to strength recommendations.
    """
    metrics = [
        Metric(
            name="Hip stability",
            score=0.62,
            status="Needs work",
            explanation="Detected possible hip drop during stance phase. This often indicates weak glute medius or poor single-leg control.",
        ),
        Metric(
            name="Knee tracking",
            score=0.68,
            status="Moderate",
            explanation="Knee alignment may drift inward under load. Improve hip external rotation and foot stability.",
        ),
        Metric(
            name="Trunk control",
            score=0.74,
            status="Good",
            explanation="Upper-body position looks mostly stable, with minor rotation that can be improved with core work.",
        ),
        Metric(
            name="Overstride risk",
            score=0.58,
            status="Needs work",
            explanation="Foot may be landing too far ahead of center of mass. Cadence drills and posterior-chain strength can help.",
        ),
    ]

    hip_exercises = [
        Exercise(
            name="Side plank with top-leg raise",
            category="Strength",
            sets=3,
            reps="8–10 each side",
            frequency_per_week=2,
            reason="Targets glute medius and lateral hip stability to reduce hip drop.",
        ),
        Exercise(
            name="Single-leg Romanian deadlift",
            category="Strength",
            sets=3,
            reps="8 each side",
            frequency_per_week=2,
            reason="Builds single-leg control, hamstring strength, and pelvis stability.",
        ),
    ]

    overstride_exercises = [
        Exercise(
            name="A-march drill",
            category="Run drill",
            sets=3,
            reps="20 meters",
            frequency_per_week=2,
            reason="Improves foot placement under the body and reinforces rhythm.",
        ),
        Exercise(
            name="Calf raise iso hold",
            category="Strength",
            sets=3,
            reps="30 seconds",
            frequency_per_week=2,
            reason="Improves ankle stiffness and push-off control.",
        ),
    ]

    issues = [
        Issue(
            title="Possible hip drop",
            severity="Medium",
            explanation="Your pelvis may drop slightly on one side during stance. Prioritize lateral hip strength and single-leg balance.",
            recommended_exercises=hip_exercises,
        ),
        Issue(
            title="Possible overstride",
            severity="Medium",
            explanation="Your foot may be landing ahead of your center of mass. Combine cadence awareness with calf and posterior-chain work.",
            recommended_exercises=overstride_exercises,
        ),
    ]

    return AnalysisResponse(
        summary=f"Analyzed {filename}. V1 mock result: focus on hip stability, knee tracking, and overstride control.",
        confidence=0.72,
        metrics=metrics,
        issues=issues,
    )
