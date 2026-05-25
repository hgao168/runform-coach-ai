package com.runformcoach.runformcoachai

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import java.io.File
import java.util.concurrent.TimeUnit

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

object ApiClient {
    private const val BASE_URL = "https://runform-coach-ai-staging.up.railway.app/"

    private val okhttp = OkHttpClient.Builder()
        .connectTimeout(120, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        })
        .build()

    val api: RunFormApi = Retrofit.Builder()
        .baseUrl(BASE_URL)
        .client(okhttp)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
        .create(RunFormApi::class.java)

    fun buildVideoPart(file: File): MultipartBody.Part {
        val requestBody = file.asRequestBody("video/mp4".toMediaType())
        return MultipartBody.Part.createFormData("video", file.name, requestBody)
    }

    fun buildModePart(mode: String): MultipartBody.Part =
        MultipartBody.Part.createFormData("mode", mode)
}

