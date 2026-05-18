package com.runformcoach.runformcoachai

import android.app.Application
import android.os.Looper
import android.os.Trace
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import java.io.File

/**
 * RF-921: Cold-start performance optimizer.
 *
 * Goals:
 * - Profile-aware initialization
 * - Deferred Firebase/Analytics init via IdleHandler
 * - android.os.Trace instrumentation
 * - Target: cold start < 2 seconds
 *
 * Usage (in RunFormApplication.onCreate):
 * ```
 * StartupOptimizer.installTraceSections()
 * StartupOptimizer.onApplicationCreate(this) {
 *     // Critical-path init here
 * }
 * ```
 */
object StartupOptimizer {

    private const val TAG = "StartupOptimizer"
    private const val TRACE_APP_CREATE = "RunForm:app_onCreate"
    private const val TRACE_CRITICAL_INIT = "RunForm:critical_init"
    private const val TRACE_LAZY_INIT = "RunForm:lazy_init"

    /** Whether we are running under a benchmark/profile configuration. */
    var isProfileInstalled: Boolean = false
        private set

    /** Timestamp of Application.onCreate start. Used for cold-start timing. */
    var appCreateStartMillis: Long = 0L
        private set

    // ── Profile Detection ─────────────────────────────────────────────────────

    /**
     * Detect whether a performance profile (baseline profile, benchmark mode, or
     * AOT profile) is active. This information can be used to tune init paths.
     *
     * Checks:
     * 1. ART profile existence (primary dex profiles)
     * 2. Whether we're executing from a pre-compiled state
     */
    private fun detectProfile(application: Application) {
        try {
            // Check for ART profile files — these indicate the runtime has
            // AOT-compiled code from baseline/cloud profiles.
            val packageName = application.packageName
            val profileDir = File("/data/misc/profiles/ref/$packageName")
            val hasPrimaryProfile = profileDir.exists() &&
                profileDir.listFiles()?.any { it.name == "primary.prof" } == true

            // Check if the app is running under benchmark by looking for the
            // Jetpack Benchmark argument.
            val isBenchmark = application.packageName.contains(".benchmark") ||
                try {
                    Class.forName("androidx.benchmark.macro.CompilationMode")
                    true
                } catch (_: ClassNotFoundException) {
                    false
                }

            isProfileInstalled = hasPrimaryProfile || isBenchmark

            Log.i(TAG, "Profile installed: $isProfileInstalled " +
                "(hasPrimaryProfile=$hasPrimaryProfile, isBenchmark=$isBenchmark)")
        } catch (e: Exception) {
            Log.w(TAG, "Profile detection failed", e)
            isProfileInstalled = false
        }
    }

    // ── Trace Sections ────────────────────────────────────────────────────────

    /**
     * Install custom trace section names recognized by Perfetto/systrace.
     * Call this BEFORE any traced operations.
     */
    fun installTraceSections() {
        // No explicit registration needed; android.os.Trace uses string-based sections.
        // We pre-load the section constants to ensure code paths are compiled.
        Log.d(TAG, "Trace sections installed: " +
            "$TRACE_APP_CREATE, $TRACE_CRITICAL_INIT, $TRACE_LAZY_INIT")
    }

    // ── Main Entry ────────────────────────────────────────────────────────────

    /**
     * The main initialization orchestrator. Call from [Application.onCreate].
     *
     * @param application the Application instance
     * @param onCriticalInit lambda containing the ABSOLUTE minimum init (Room, DI graph)
     */
    fun onApplicationCreate(
        application: Application,
        onCriticalInit: () -> Unit
    ) {
        appCreateStartMillis = System.currentTimeMillis()

        Trace.beginSection(TRACE_APP_CREATE)

        // 1. Profile detection
        detectProfile(application)

        // 2. Critical-path init (Room, DI, etc.)
        Trace.beginSection(TRACE_CRITICAL_INIT)
        try {
            onCriticalInit()
        } finally {
            Trace.endSection()
        }

        // 3. Defer Firebase/Analytics init to IdleHandler
        scheduleLazyInit(application)

        Trace.endSection()

        // Log cold-start duration
        val elapsed = System.currentTimeMillis() - appCreateStartMillis
        Log.i(TAG, "Critical init completed in ${elapsed}ms")

        // NOTE: Do NOT record to Crashlytics here — it isn't initialized yet.
        // The lazy init handler will log the full startup time once available.
    }

    // ── Lazy Init via IdleHandler ─────────────────────────────────────────────

    /**
     * Schedule Firebase initialization and other non-critical tasks
     * on the main thread's IdleHandler — they run only after the first frame
     * has been drawn and the message queue is empty.
     */
    private fun scheduleLazyInit(application: Application) {
        Looper.myQueue().addIdleHandler {
            Trace.beginSection(TRACE_LAZY_INIT)
            try {
                val startedAt = System.currentTimeMillis()

                // ── Firebase Analytics (costly init) ──
                try {
                    FirebaseApp.initializeApp(application)
                    Log.d(TAG, "Firebase initialized lazily")
                } catch (e: Exception) {
                    Log.w(TAG, "Firebase lazy init failed", e)
                }

                // ── Crashlytics global handler ──
                try {
                    val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
                    Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
                        FirebaseCrashlytics.getInstance().recordException(throwable)
                        defaultHandler?.uncaughtException(thread, throwable)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Crashlytics handler setup failed", e)
                }

                // ── Log full startup duration now that Crashlytics is live ──
                val totalStartupMs = System.currentTimeMillis() - appCreateStartMillis
                Log.i(TAG, "Full startup (including lazy init) completed in ${totalStartupMs}ms")

                // Record as non-fatal breadcrumb if Crashlytics is available
                try {
                    FirebaseCrashlytics.getInstance().log(
                        "Cold start: ${totalStartupMs}ms " +
                        "(profile=${isProfileInstalled})"
                    )
                } catch (_: Exception) {
                    // Crashlytics might not be ready yet; this is best-effort
                }

                val lazyInitMs = System.currentTimeMillis() - startedAt
                Log.i(TAG, "Lazy init finished in ${lazyInitMs}ms")
            } finally {
                Trace.endSection()
            }

            // Return false to unregister this IdleHandler after one execution
            false
        }
    }

    // ── Utility: Wall-clock since Application.onCreate ───────────────────────

    /**
     * Returns milliseconds elapsed since Application.onCreate started.
     * Useful for logging intermediate milestones.
     */
    fun elapsedSinceAppCreate(): Long =
        if (appCreateStartMillis == 0L) 0L
        else System.currentTimeMillis() - appCreateStartMillis
}
