package com.runformcoach.runformcoachai

import com.google.gson.annotations.SerializedName
import kotlin.math.roundToInt

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
    var weeklyExerciseHours: Double = 5.0,
    // ── RF-208: Gear & Fit fields ─────────────────────────────────────────
    var shoeSizeEU: Int = 42,
    var legLengthCm: Double = 85.0,
    var shoeBrand: String = "",
    var shoeModel: String = ""
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

    companion object {
        /** Convert EU shoe size to US men's. */
        fun euToUS(eu: Int): Double = if (eu <= 37) (eu - 33).toDouble()
            else (eu - 33.5).toDouble()

        /** Convert EU shoe size to UK men's. */
        fun euToUK(eu: Int): Double = if (eu <= 37) (eu - 34).toDouble()
            else (eu - 34.5).toDouble()

        /** Convert US shoe size back to EU. */
        fun usToEU(us: Double): Int = (us + 33.5).roundToInt()

        /** Convert UK shoe size back to EU. */
        fun ukToEU(uk: Double): Int = (uk + 34.5).roundToInt()
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
    val language: String = "en",
    // ── Marathon / Race fields ──
    @SerializedName("marathon_major") val marathonMajor: String? = null,
    @SerializedName("marathon_plan_weeks") val marathonPlanWeeks: Int? = null,
    @SerializedName("include_marathon_block") val includeMarathonBlock: Boolean = false,
    @SerializedName("include_race_block") val includeRaceBlock: Boolean = false,
    @SerializedName("training_level") val trainingLevel: String? = null,
    @SerializedName("plan_duration_weeks") val planDurationWeeks: Int? = null
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
    @SerializedName("connected_analysis_used") val connectedAnalysisUsed: Boolean = false,
    // ── Marathon / Race blocks ──
    @SerializedName("marathon_plan") val marathonPlan: MarathonPlan? = null,
    @SerializedName("race_plan") val racePlan: RacePlan? = null
)

// ── Marathon Plan Models ──────────────────────────────────────────────────────

/** A full marathon training block (12–16 weeks). */
data class MarathonPlan(
    val race: String,
    @SerializedName("plan_profile") val planProfile: String,
    @SerializedName("total_weeks") val totalWeeks: Int,
    val weeks: List<MarathonPlanWeek>
)

/** One week inside a marathon training block. */
data class MarathonPlanWeek(
    val week: Int,
    val phase: String,
    @SerializedName("target_km") val targetKm: Double,
    @SerializedName("long_run_km") val longRunKm: Double,
    val workouts: List<PlannedWorkout> = emptyList(),
    val notes: String? = null
)

// ── Race Plan Models (5K / 10K / Half Marathon) ──────────────────────────────

/** A race-specific training block (8–16 weeks). */
data class RacePlan(
    val target: String,
    val level: String,
    @SerializedName("total_weeks") val totalWeeks: Int,
    val weeks: List<RacePlanWeek>
)

/** One week inside a race training block. */
data class RacePlanWeek(
    val week: Int,
    val phase: String,
    @SerializedName("target_km") val targetKm: Double,
    @SerializedName("long_run_km") val longRunKm: Double,
    val workouts: List<PlannedWorkout> = emptyList(),
    val notes: String? = null
)

/** Phase boundary helper (computed locally). */
data class MarathonPhaseLink(
    val id: String,
    val label: String,
    val startWeek: Int,
    val endWeek: Int,
    val startTargetKm: Double,
    val endTargetKm: Double,
    val startLongRunKm: Double,
    val endLongRunKm: Double
)

// ── Marathon Majors ───────────────────────────────────────────────────────────

val MARATHON_MAJORS = listOf(
    "Berlin", "Boston", "Chicago", "London", "New York City", "Tokyo", "Custom"
)

// ── Training Level ────────────────────────────────────────────────────────────

val TRAINING_LEVELS = listOf("Beginner", "Intermediate", "Advanced")

// ── History ───────────────────────────────────────────────────────────────────

data class AnalysisHistoryItem(
    val id: String,
    val createdAt: Long,   // epoch millis
    val videoFilename: String,
    val result: AnalysisResponse
)

// ── Feedback ──────────────────────────────────────────────────────────────────

/**
 * Star rating for analysis feedback.
 * Mirrors iOS FeedbackRating enum.
 */
enum class FeedbackRating(val value: Int, val labelKey: String) {
    VERY_INACCURATE(1, "feedback_very_inaccurate"),
    PARTLY_ACCURATE(2, "feedback_partly_accurate"),
    MOSTLY_ACCURATE(3, "feedback_mostly_accurate"),
    ACCURATE(4, "feedback_accurate"),
    VERY_ACCURATE(5, "feedback_very_accurate");
}

/** Request body for POST /feedback */
data class FeedbackRequest(
    @SerializedName("analysis_id") val analysisId: String,
    @SerializedName("rating") val rating: Int,
    @SerializedName("comment") val comment: String = ""
)

/** Response from POST /feedback */
data class FeedbackResponse(
    @SerializedName("received") val received: Boolean,
    @SerializedName("message") val message: String = ""
)
