package com.runformcoach.runformcoachai

import okhttp3.MultipartBody
import retrofit2.http.Body
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part

interface RunFormApi {
    @Multipart
    @POST("analyze")
    suspend fun analyzeVideo(
        @Part video: MultipartBody.Part,
        @Part mode: MultipartBody.Part
    ): AnalysisResponse

    @POST("training-plan")
    suspend fun generatePlan(@Body request: TrainingPlanRequest): TrainingPlanResponse
}
