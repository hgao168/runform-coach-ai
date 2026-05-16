package com.runformcoach.runformcoachai

import android.app.Application
import com.google.firebase.FirebaseApp
import com.google.firebase.crashlytics.FirebaseCrashlytics
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class RunFormApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // RF-215: Initialise Firebase
        FirebaseApp.initializeApp(this)

        // RF-215: Global uncaught exception → Crashlytics non-fatal
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            FirebaseCrashlytics.getInstance().recordException(throwable)
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}
