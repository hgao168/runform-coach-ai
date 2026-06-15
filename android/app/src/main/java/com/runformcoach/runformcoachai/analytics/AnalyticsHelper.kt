package com.runformcoach.runformcoachai.analytics

import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Centralised analytics + crash-reporting helper (RF-215).
 *
 * Fire-and-forget wrappers so callers don't need to know about Firebase specifics.
 */
@Singleton
class AnalyticsHelper @Inject constructor(
    private val firebaseAnalytics: FirebaseAnalytics
) {
    // ── Screen Views ─────────────────────────────────────────────────────────

    fun logScreenView(screenName: String, screenClass: String = "") {
        val params = Bundle().apply {
            putString(FirebaseAnalytics.Param.SCREEN_NAME, screenName)
            putString(FirebaseAnalytics.Param.SCREEN_CLASS, screenClass)
        }
        firebaseAnalytics.logEvent(FirebaseAnalytics.Event.SCREEN_VIEW, params)
    }

    // ── Analysis Events ──────────────────────────────────────────────────────

    /** Logged when the user taps "Analyze" after picking a video. */
    fun logAnalysisStarted(mode: String, hasCompression: Boolean) {
        val params = Bundle().apply {
            putString("analysis_mode", mode)
            putBoolean("compression_enabled", hasCompression)
        }
        firebaseAnalytics.logEvent("analysis_started", params)
    }

    /** Logged when the server returns a successful analysis. */
    fun logAnalysisCompleted(confidence: Double, metricsCount: Int, issuesCount: Int) {
        val params = Bundle().apply {
            putDouble("confidence", confidence)
            putInt("metrics_count", metricsCount)
            putInt("issues_count", issuesCount)
        }
        firebaseAnalytics.logEvent("analysis_completed", params)
    }

    /** Logged when the live guidance recording finishes and analysis begins. */
    fun logLiveGuidanceRecordingCompleted(durationSeconds: Long, poseDetected: Boolean) {
        val params = Bundle().apply {
            putLong("duration_seconds", durationSeconds)
            putBoolean("pose_detected", poseDetected)
        }
        firebaseAnalytics.logEvent("live_guidance_recording_completed", params)
    }

    // ── Plan Events ──────────────────────────────────────────────────────────

    fun logPlanGenerated(planType: String, weeks: Int) {
        val params = Bundle().apply {
            putString("plan_type", planType)
            putInt("weeks", weeks)
        }
        firebaseAnalytics.logEvent("plan_generated", params)
    }

    // ── Error Logging (Crashlytics non-fatal) ────────────────────────────────

    fun logNonFatal(throwable: Throwable) {
        FirebaseCrashlytics.getInstance().recordException(throwable)
    }

    fun logNonFatal(message: String) {
        FirebaseCrashlytics.getInstance().log(message)
    }
}
