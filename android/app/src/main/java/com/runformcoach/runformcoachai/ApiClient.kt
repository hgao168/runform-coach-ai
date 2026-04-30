package com.runformcoach.runformcoachai

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import java.io.File
import java.util.concurrent.TimeUnit

interface RunFormApi {
    @Multipart
    @POST("analyze")
    suspend fun analyzeVideo(
        @Part video: MultipartBody.Part
    ): AnalysisResponse
}

object ApiClient {
    // For emulator use 10.0.2.2 (maps to host machine localhost).
    // For physical Android device use your computer LAN IP e.g. 192.168.1.20
    private const val BASE_URL = "http://10.0.2.2:8000/"

    private val okhttp = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
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
}
