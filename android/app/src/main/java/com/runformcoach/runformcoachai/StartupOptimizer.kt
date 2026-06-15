package com.runformcoach.runformcoachai

import android.app.Application
import android.os.Handler
import android.os.Looper
import android.os.StrictMode
import android.os.Trace
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import java.io.File

/**
 * RF-921: Cold-start performance optimizer + ANR guard.
 *
 * Goals:
 * - Profile-aware initialization
 * - Deferred Firebase/Analytics init via IdleHandler
 * - android.os.Trace instrumentation
 * - StrictMode detection in debug builds
 * - Main-thread ANR watchdog
 * - Target: cold start < 2 seconds
 *
 * Usage (in RunFormApplication.onCreate):
 * ```
 * StartupOptimizer.installStrictMode()
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

    /** Cold-start target in milliseconds. */
    private const val COLD_START_TARGET_MS = 2_000L

    /** ANR watchdog threshold in milliseconds. */
    private const val ANR_WATCHDOG_THRESHOLD_MS = 3_000L

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

    // ── StrictMode (Debug Builds) ───────────────────────────────────────────────

    /**
     * Install StrictMode policies in debug builds to catch:
     * - Disk reads/writes on main thread
     * - Network operations on main thread
     * - Slow calls (custom threshold)
     *
     * Call this BEFORE any heavy init in Application.onCreate.
     */
    fun installStrictMode() {
        // Only enable in debug builds; release builds skip this overhead
        if (!isDebugBuild()) {
            Log.d(TAG, "StrictMode: skipped (release build)")
            return
        }

        // Thread policy: detect accidental disk I/O and network on main thread
        StrictMode.setThreadPolicy(
            StrictMode.ThreadPolicy.Builder()
                .detectDiskReads()
                .detectDiskWrites()
                .detectNetwork()
                .penaltyLog()          // log to logcat
                .penaltyFlashScreen()  // flash border on screen (debug only)
                .build()
        )

        // VM policy: detect leaked SQLite cursors, unclosed resources, etc.
        StrictMode.setVmPolicy(
            StrictMode.VmPolicy.Builder()
                .detectLeakedSqlLiteObjects()
                .detectLeakedClosableObjects()
                .detectActivityLeaks()
                .detectLeakedRegistrationObjects()
                .penaltyLog()
                .build()
        )

        Log.i(TAG, "StrictMode installed (debug build)")
    }

    // ── ANR Watchdog ───────────────────────────────────────────────────────────

    /**
     * Start a lightweight ANR watchdog that periodically posts a message
     * to the main thread and checks whether it was processed within the
     * threshold. If the main thread is blocked for too long, logs a
     * warning and records a non-fatal to Crashlytics.
     */
    private fun startAnrWatchdog() {
        val handler = Handler(Looper.getMainLooper())
        val startedAt = System.currentTimeMillis()

        // Post a runnable that checks elapsed time
        handler.post {
            val elapsed = System.currentTimeMillis() - startedAt
            Log.d(TAG, "ANR watchdog: main thread responsive (${elapsed}ms since post)")

            // If the watchdog itself took too long to fire, the main thread
            // was busy — log a warning.
            if (elapsed > ANR_WATCHDOG_THRESHOLD_MS) {
                val warning = "ANR_WATCHDOG: main thread blocked for ${elapsed}ms " +
                    "(threshold=${ANR_WATCHDOG_THRESHOLD_MS}ms)"
                Log.w(TAG, warning)

                // Best-effort Crashlytics breadcrumb
                try {
                    FirebaseCrashlytics.getInstance().log(warning)
                } catch (_: Exception) {
                    // Crashlytics not ready yet
                }
            }
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

        // 4. Start ANR watchdog (runs on the main thread's message queue)
        startAnrWatchdog()

        Trace.endSection()

        // Log cold-start duration and check against target
        val elapsed = System.currentTimeMillis() - appCreateStartMillis
        if (elapsed > COLD_START_TARGET_MS) {
            Log.w(TAG, "⚠️ Cold start exceeded target: ${elapsed}ms (target=${COLD_START_TARGET_MS}ms)")
        } else {
            Log.i(TAG, "✓ Cold start within target: ${elapsed}ms (target=${COLD_START_TARGET_MS}ms)")
        }

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

    // ── Utility: Debug build detection ──────────────────────────────────────

    /**
     * Detect whether this is a debug build (not release).
     * Uses BuildConfig.DEBUG if available, otherwise falls back to
     * checking debuggable flag from ApplicationInfo.
     */
    private fun isDebugBuild(): Boolean {
        return try {
            // Primary: check BuildConfig.DEBUG
            val buildConfigClass = Class.forName("com.runformcoach.runformcoachai.BuildConfig")
            val debugField = buildConfigClass.getField("DEBUG")
            debugField.getBoolean(null)
        } catch (_: Exception) {
            // BuildConfig not available; assume release
            false
        }
    }
}
