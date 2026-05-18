package com.runformcoach.runformcoachai

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * RF-215 / RF-921: Application entry point with cold-start optimization.
 *
 * Firebase initialization is deferred to [StartupOptimizer]'s IdleHandler
 * so the first frame renders before Firebase blocks the main thread.
 */
@HiltAndroidApp
class RunFormApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // RF-921: Profile-aware, traced, deferred-init cold start
        StartupOptimizer.installTraceSections()
        StartupOptimizer.onApplicationCreate(this) {
            // Critical-path initialization (Hilt injects dependencies here)
            // Room DB is initialized by Hilt when first injected.
            // No Firebase/analytics here — deferred to IdleHandler.
        }
    }
}
