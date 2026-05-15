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
    @POST("compare")
    suspend fun compareWithAthlete(@Body request: CompareRequest): CompareResponse

    // ── Feedback ───────────────────────────────────────────────────────────────

    /** Submit user feedback rating for an analysis. RF-203 */
    @POST("feedback")
    suspend fun submitFeedback(@Body request: FeedbackRequest): FeedbackResponse
}
