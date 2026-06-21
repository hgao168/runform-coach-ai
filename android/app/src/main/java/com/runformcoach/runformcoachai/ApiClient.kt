package com.runformcoach.runformcoachai

import okhttp3.MultipartBody
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part

interface RunFormApi {
    // ── Analysis ───────────────────────────────────────────────────────────────

    @Multipart
    @POST("analyze")
    suspend fun analyzeVideo(
        @Part video: MultipartBody.Part,
        @Part mode: MultipartBody.Part
    ): AnalysisResponse

    // ── Training Plan ──────────────────────────────────────────────────────────

    @POST("training-plan")
    suspend fun generatePlan(@Body request: TrainingPlanRequest): TrainingPlanResponse

    // ── Elite Compare ──────────────────────────────────────────────────────────

    /** Fetch the list of elite athletes available for comparison. */
    @GET("athletes")
    suspend fun fetchAthletes(): List<AthleteListItem>

    /** Compare user metrics against a specific elite athlete. */
    @POST("api/v1/compare")
    suspend fun compareWithAthlete(@Body request: CompareRequest): CompareResponse

    // ── Feedback ───────────────────────────────────────────────────────────────

    /** Submit user feedback rating for an analysis. RF-203 */
    @POST("api/v1/feedback")
    suspend fun submitFeedback(@Body request: FeedbackRequest): FeedbackResponse

    // ── Weekly Trends (RF-912) ─────────────────────────────────────────────────

    /** Fetch 4-week training trend data for the weekly insight report. */
    @GET("api/v1/sessions/trends")
    suspend fun fetchWeeklyTrends(): WeeklyTrendsResponse

    // ── RunSession History & Replay (RF-1000) ─────────────────────────────────

    /** Fetch list of historical run sessions. */
    @GET("api/v1/sessions")
    suspend fun fetchSessions(): List<RunSessionSummary>

    /** Fetch a single session with full time-series data for replay. */
    @GET("api/v1/sessions/{sessionId}")
    suspend fun fetchSessionDetail(
        @retrofit2.http.Path("sessionId") sessionId: String
    ): RunSessionDetail

    // ── Challenge (RF-601) ────────────────────────────────────────────────────

    /** List all challenges with optional personal participation state. */
    @GET("api/v1/challenges")
    suspend fun listChallenges(
        @retrofit2.http.Query("ios_user_id") iosUserId: String
    ): List<ChallengeInfo>

    /** Join an active challenge. */
    @POST("api/v1/challenges/{challengeId}/join")
    suspend fun joinChallenge(
        @retrofit2.http.Path("challengeId") challengeId: String,
        @Body request: ChallengeJoinRequest
    ): ChallengeJoinResponse

    /** Get the leaderboard for a challenge. */
    @GET("api/v1/challenges/{challengeId}/leaderboard")
    suspend fun getChallengeLeaderboard(
        @retrofit2.http.Path("challengeId") challengeId: String,
        @retrofit2.http.Query("ios_user_id") iosUserId: String
    ): List<ChallengeLeaderboardEntry>

    /** Daily check-in for an active challenge (C5). */
    @POST("api/v1/challenges/{challengeId}/check-in")
    suspend fun checkInChallenge(
        @retrofit2.http.Path("challengeId") challengeId: String,
        @Body request: ChallengeCheckInRequest
    ): ChallengeCheckInResponse
}
