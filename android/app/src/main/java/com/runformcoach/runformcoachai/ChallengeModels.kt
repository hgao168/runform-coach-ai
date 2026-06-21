package com.runformcoach.runformcoachai

import com.google.gson.annotations.SerializedName

// ═══════════════════════════════════════════════════════════════════════════════
// Challenge API Data Models
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Response from GET /api/v1/challenges — list of challenges with optional
 * personal participation state (N3).
 */
data class ChallengeInfo(
    @SerializedName("id") val id: String,
    @SerializedName("name") val name: String,
    @SerializedName("description") val description: String,
    @SerializedName("start_date") val startDate: String,
    @SerializedName("end_date") val endDate: String,
    @SerializedName("days") val days: Int,
    @SerializedName("participant_count") val participantCount: Int,
    @SerializedName("status") val status: String,  // "active" | "ended"
    @SerializedName("joined") val joined: Boolean? = null,
    @SerializedName("completed_days") val completedDays: Int? = null,
    @SerializedName("today_completed") val todayCompleted: Boolean? = null
)

/**
 * Request body for POST /api/v1/challenges/{id}/join
 */
data class ChallengeJoinRequest(
    @SerializedName("ios_user_id") val iosUserId: String
)

/**
 * Response from POST /api/v1/challenges/{id}/join
 */
data class ChallengeJoinResponse(
    @SerializedName("joined") val joined: Boolean,
    @SerializedName("challenge_id") val challengeId: String,
    @SerializedName("message") val message: String
)

/**
 * Entry in GET /api/v1/challenges/{id}/leaderboard response list.
 */
data class ChallengeLeaderboardEntry(
    @SerializedName("ios_user_id") val iosUserId: String,
    @SerializedName("cadence_improvement_pct") val cadenceImprovementPct: Double? = null,
    @SerializedName("oscillation_improvement_pct") val oscillationImprovementPct: Double? = null,
    @SerializedName("overall_score_change") val overallScoreChange: Double? = null,
    @SerializedName("rank") var rank: Int,
    @SerializedName("display_name") val displayName: String? = null,
    @SerializedName("name") val name: String? = null,
    @SerializedName("nickname") val nickname: String? = null,
    @SerializedName("days") val days: Int? = null,
    @SerializedName("completed_days") val completedDays: Int? = null,
    @SerializedName("is_me") val isMe: Boolean = false
)

/**
 * Typed today-metrics sub-object returned by the check-in endpoint.
 */
data class ChallengeTodayMetrics(
    @SerializedName("cadence") val cadence: Double? = null,
    @SerializedName("vertical_oscillation") val verticalOscillation: Double? = null,
    @SerializedName("ground_contact_time") val gct: Double? = null,
    @SerializedName("score") val score: Double? = null
)

/**
 * Request body for POST /api/v1/challenges/{id}/check-in (C5).
 */
data class ChallengeCheckInRequest(
    @SerializedName("user_id") val userId: String
)

/**
 * Response from POST /api/v1/challenges/{id}/check-in (C5).
 */
data class ChallengeCheckInResponse(
    @SerializedName("status") val status: String,
    @SerializedName("check_in_count") val checkInCount: Int,
    @SerializedName("streak_days") val streakDays: Int,
    @SerializedName("today_metrics") val todayMetrics: ChallengeTodayMetrics? = null
)

// ═══════════════════════════════════════════════════════════════════════════════
// ViewModel UI State
// ═══════════════════════════════════════════════════════════════════════════════

sealed class ChallengeListState {
    object Loading : ChallengeListState()
    data class Success(val challenges: List<ChallengeInfo>) : ChallengeListState()
    data class Error(val message: String) : ChallengeListState()
}

sealed class ChallengeJoinState {
    object Idle : ChallengeJoinState()
    object Joining : ChallengeJoinState()
    data class Joined(val response: ChallengeJoinResponse) : ChallengeJoinState()
    data class Error(val message: String) : ChallengeJoinState()
}

sealed class ChallengeCheckInState {
    object Idle : ChallengeCheckInState()
    object CheckingIn : ChallengeCheckInState()
    data class CheckedIn(val response: ChallengeCheckInResponse) : ChallengeCheckInState()
    data class AlreadyCheckedIn(val message: String) : ChallengeCheckInState()
    data class Error(val message: String) : ChallengeCheckInState()
}

sealed class ChallengeLeaderboardState {
    object Loading : ChallengeLeaderboardState()
    data class Success(val entries: List<ChallengeLeaderboardEntry>, val myRank: Int?) : ChallengeLeaderboardState()
    object Empty : ChallengeLeaderboardState()
    data class Error(val message: String) : ChallengeLeaderboardState()
}
