package com.runformcoach.runformcoachai.di

import com.runformcoach.runformcoachai.BuildConfig
import com.runformcoach.runformcoachai.RunFormApi
import com.runformcoach.runformcoachai.auth.AuthInterceptor
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.File
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object ApiModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(authInterceptor: AuthInterceptor): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(120, TimeUnit.SECONDS)
            .readTimeout(120, TimeUnit.SECONDS)
            .writeTimeout(120, TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)
            .addInterceptor(HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BASIC
            })
            .build()
    }

    @Provides
    @Singleton
    fun provideRunFormApi(okhttp: OkHttpClient): RunFormApi {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(okhttp)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(RunFormApi::class.java)
    }

    @Provides
    fun provideVideoPartFactory(): VideoPartFactory = VideoPartFactory
}

/**
 * Utility for building multipart video parts (stateless, so provided as singleton object).
 */
object VideoPartFactory {
    fun buildVideoPart(file: File): MultipartBody.Part {
        val requestBody = file.asRequestBody("video/mp4".toMediaType())
        return MultipartBody.Part.createFormData("video", file.name, requestBody)
    }

    fun buildModePart(mode: String): MultipartBody.Part =
        MultipartBody.Part.createFormData("mode", mode)
}
