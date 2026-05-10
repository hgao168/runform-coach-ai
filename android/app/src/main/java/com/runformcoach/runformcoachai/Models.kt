package com.runformcoach.runformcoachai

import com.google.gson.annotations.SerializedName

// ── Analysis ──────────────────────────────────────────────────────────────────

data class AnalysisResponse(
    val summary: String,
    val confidence: Double,
    val metrics: List<Metric>,
    val issues: List<Issue>,
    @SerializedName("video_quality_score") val videoQualityScore: Double?,
    @SerializedName("quality_notes") val qualityNotes: List<String> = emptyList()
)

data class Metric(
    val name: String,
    val score: Double,
    val status: String,
    val explanation: String
)

data class Issue(
    val title: String,
    val severity: String,
    val explanation: String,
    @SerializedName("recommended_exercises") val recommendedExercises: List<Exercise>
)

data class Exercise(
    val name: String,
    val category: String,
    val sets: Int,
    val reps: String,
    @SerializedName("frequency_per_week") val frequencyPerWeek: Int,
    val reason: String
)

// ── Profile ───────────────────────────────────────────────────────────────────

data class TesterProfile(
    var firstName: String = "",
    var lastName: String = "",
    var nickname: String = "",
    var level: String = "Beginner",
    var weeklyMileageKm: Double = 15.0,
    var runningDaysPerWeek: Int = 3,
    var heightCm: Double = 170.0,
    var weightKg: Double = 70.0,
    var target: String = "General Fitness",
    var injuryNote: String = "",
    var weeklyExerciseHours: Double = 5.0
) {
    val displayName: String
        get() {
            val full = "$firstName $lastName".trim()
            return when {
                full.isNotEmpty() -> full
                nickname.isNotEmpty() -> nickname
                else -> "Runner"
            }
        }
}

val RUNNER_LEVELS = listOf("Beginner", "Intermediate", "Advanced")
val TRAINING_TARGETS = listOf("5K", "10K", "Half Marathon", "Marathon", "General Fitness")

// ── Training Plan ─────────────────────────────────────────────────────────────

data class FormIssueContext(
    val title: String,
    val severity: String = "Medium",
    val explanation: String = "",
    @SerializedName("exercise_names") val exerciseNames: List<String> = emptyList()
)

data class TrainingPlanRequest(
    @SerializedName("current_weekly_km") val currentWeeklyKm: Double,
    val target: String,
    @SerializedName("available_running_days") val availableRunningDays: Int,
    @SerializedName("selected_run_days") val selectedRunDays: List<String>,
    @SerializedName("injury_flag") val injuryFlag: Boolean,
    @SerializedName("form_issues") val formIssues: List<FormIssueContext> = emptyList(),
    @SerializedName("recent_analysis_summary") val recentAnalysisSummary: String? = null,
    @SerializedName("recent_analysis_confidence") val recentAnalysisConfidence: Double? = null,
    val language: String = "en"
)

data class PlannedWorkout(
    val day: String,
    val title: String,
    val category: String,
    val intensity: String,
    val details: String,
    val purpose: String,
    @SerializedName("distance_km") val distanceKm: Double?,
    @SerializedName("duration_minutes") val durationMinutes: Int?,
    @SerializedName("coaching_focus") val coachingFocus: String?
)

data class TrainingPlanResponse(
    val summary: String,
    @SerializedName("planned_weekly_km") val plannedWeeklyKm: Double,
    @SerializedName("running_days") val runningDays: Int,
    val workouts: List<PlannedWorkout>,
    val notes: List<String> = emptyList(),
    @SerializedName("connected_analysis_used") val connectedAnalysisUsed: Boolean = false
)

// ── History ───────────────────────────────────────────────────────────────────

data class AnalysisHistoryItem(
    val id: String,
    val createdAt: Long,   // epoch millis
    val videoFilename: String,
    val result: AnalysisResponse
)

