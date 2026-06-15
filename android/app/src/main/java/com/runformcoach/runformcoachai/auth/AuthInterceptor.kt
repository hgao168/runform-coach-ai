package com.runformcoach.runformcoachai.auth

import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

/**
 * OkHttp Interceptor that attaches Bearer token to every request.
 * Handles 401 responses by attempting token refresh (if a refresh token is available).
 */
@Singleton
class AuthInterceptor @Inject constructor(
    private val tokenManager: TokenManager
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()

        // Skip auth for requests that don't need it (if the request already has a header, skip)
        val request = if (originalRequest.header("Authorization") == null) {
            val token = tokenManager.accessToken
            if (!token.isNullOrBlank()) {
                originalRequest.newBuilder()
                    .header("Authorization", "Bearer $token")
                    .build()
            } else {
                originalRequest
            }
        } else {
            originalRequest
        }

        val response = chain.proceed(request)

        // Handle 401 — attempt token refresh
        if (response.code == 401) {
            response.close()

            val refreshToken = tokenManager.refreshToken
            if (!refreshToken.isNullOrBlank()) {
                // Attempt refresh; if successful, retry original request
                val newAccessToken = performTokenRefresh(chain, refreshToken)
                if (newAccessToken != null) {
                    tokenManager.accessToken = newAccessToken
                    val retryRequest = originalRequest.newBuilder()
                        .header("Authorization", "Bearer $newAccessToken")
                        .build()
                    return chain.proceed(retryRequest)
                }
            }

            // Refresh failed or no refresh token — clear tokens
            tokenManager.clear()
            throw IOException("Authentication failed (401)")
        }

        return response
    }

    /**
     * Calls the token refresh endpoint. Returns new access token or null.
     */
    private fun performTokenRefresh(chain: Interceptor.Chain, refreshToken: String): String? {
        return try {
            val refreshRequest = chain.request().newBuilder()
                .url(chain.request().url.newBuilder().addPathSegment("auth").addPathSegment("refresh").build())
                .header("Authorization", "Bearer $refreshToken")
                .get()
                .build()
            val refreshResponse = chain.proceed(refreshRequest)
            if (refreshResponse.isSuccessful) {
                val body = refreshResponse.body?.string()
                refreshResponse.close()
                // Try to parse access_token from JSON response
                parseAccessToken(body)
            } else {
                refreshResponse.close()
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun parseAccessToken(json: String?): String? {
        if (json == null) return null
        return try {
            // Simple JSON parsing to avoid adding Gson dependency here
            val marker = "\"access_token\""
            val start = json.indexOf(marker)
            if (start == -1) return null
            val colon = json.indexOf(':', start + marker.length)
            if (colon == -1) return null
            val valueStart = json.indexOf('"', colon + 1)
            if (valueStart == -1) return null
            val valueEnd = json.indexOf('"', valueStart + 1)
            if (valueEnd == -1) return null
            json.substring(valueStart + 1, valueEnd)
        } catch (_: Exception) {
            null
        }
    }
}
