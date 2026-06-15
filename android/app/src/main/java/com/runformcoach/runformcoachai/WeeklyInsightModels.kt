package com.runformcoach.runformcoachai

import com.google.gson.annotations.SerializedName

// ── Backend Response Models ───────────────────────────────────────────────────

/**
 * Response from GET /sessions/trends — 4-week trend data.
 */
data class WeeklyTrendsResponse(
    @SerializedName("current_week") val currentWeek: WeekSummary,
    @SerializedName("previous_week") val previousWeek: WeekSummary,
    @SerializedName("weekly_trends") val weeklyTrends: List<WeekSummary> = emptyList(),
    @SerializedName("ai_suggestion") val aiSuggestion: String? = null,
    @SerializedName("badges") val badges: List<UserBadge> = emptyList()
)

/**
 * One week's aggregated running metrics.
 */
data class WeekSummary(
    @SerializedName("week_label") val weekLabel: String = "",
    @SerializedName("week_start_iso") val weekStartIso: String = "",
    @SerializedName("avg_cadence_spm") val avgCadenceSPM: Double = 0.0,
    @SerializedName("avg_amplitude_cm") val avgAmplitudeCm: Double = 0.0,
    @SerializedName("avg_gct_ms") val avgGCTMs: Double = 0.0,
    @SerializedName("total_distance_km") val totalDistanceKm: Double = 0.0,
    @SerializedName("total_sessions") val totalSessions: Int = 0,
    @SerializedName("total_duration_min") val totalDurationMin: Double = 0.0
)

/**
 * Achievement badge earned this week.
 */
data class UserBadge(
    @SerializedName("badge_id") val badgeId: String = "",
    @SerializedName("badge_name") val badgeName: String = "",
    @SerializedName("badge_icon") val badgeIcon: String = "",
    @SerializedName("badge_description") val badgeDescription: String = ""
)

// ── ViewModel State ───────────────────────────────────────────────────────────

/**
 * UI state for the weekly insight screen.
 */
sealed class WeeklyInsightState {
    object Loading : WeeklyInsightState()
    data class Success(val data: WeeklyTrendsResponse) : WeeklyInsightState()
    data class Error(val message: String) : WeeklyInsightState()
}

// ── Delta helpers ─────────────────────────────────────────────────────────────

/** Symbolic arrow direction for trend indicators. */
enum class TrendDirection { UP, DOWN, FLAT }

/**
 * Compute the delta and direction between this week and last week.
 */
data class MetricDelta(
    val currentValue: Double,
    val previousValue: Double,
    val delta: Double,
    val deltaPct: Double,
    val direction: TrendDirection,
    val unit: String
)

fun computeDelta(
    current: Double,
    previous: Double,
    unit: String,
    invertGood: Boolean = false  // true when lower is better (e.g. GCT, amplitude)
): MetricDelta {
    val delta = current - previous
    val deltaPct = if (previous != 0.0) (delta / previous) * 100.0 else 0.0
    val rawDirection = when {
        delta > 0.01 -> TrendDirection.UP
        delta < -0.01 -> TrendDirection.DOWN
        else -> TrendDirection.FLAT
    }
    val direction = if (invertGood) {
        when (rawDirection) {
            TrendDirection.UP -> TrendDirection.DOWN
            TrendDirection.DOWN -> TrendDirection.UP
            TrendDirection.FLAT -> TrendDirection.FLAT
        }
    } else rawDirection
    return MetricDelta(current, previous, delta, deltaPct, direction, unit)
}
