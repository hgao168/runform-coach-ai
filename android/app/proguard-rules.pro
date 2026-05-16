# ── RF-214: R8 / ProGuard rules for RunForm Coach AI ────────────────────────

# ── Retrofit / OkHttp ─────────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-dontwarn retrofit2.**
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Gson ──────────────────────────────────────────────────────────────────────
-keepclassmembers class com.runformcoach.runformcoachai.** {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.runformcoach.runformcoachai.AnalysisResponse { *; }
-keep class com.runformcoach.runformcoachai.TrainingPlanResponse { *; }
-keep class com.runformcoach.runformcoachai.TrainingPlanRequest { *; }
-keep class com.runformcoach.runformcoachai.TesterProfile { *; }
-keep class com.runformcoach.runformcoachai.Metric { *; }
-keep class com.runformcoach.runformcoachai.Issue { *; }
-keep class com.runformcoach.runformcoachai.Exercise { *; }
-keep class com.runformcoach.runformcoachai.FormIssueContext { *; }
-keep class com.runformcoach.runformcoachai.PlannedWorkout { *; }
-keep class com.runformcoach.runformcoachai.MarathonPlan { *; }
-keep class com.runformcoach.runformcoachai.MarathonPlanWeek { *; }
-keep class com.runformcoach.runformcoachai.RacePlan { *; }
-keep class com.runformcoach.runformcoachai.RacePlanWeek { *; }
-keep class com.runformcoach.runformcoachai.CompareRequest { *; }
-keep class com.runformcoach.runformcoachai.CompareResponse { *; }
-keep class com.runformcoach.runformcoachai.AthleteListItem { *; }
-keep class com.runformcoach.runformcoachai.FeedbackRequest { *; }
-keep class com.runformcoach.runformcoachai.FeedbackResponse { *; }
-keep class com.runformcoach.runformcoachai.AnalysisHistoryItem { *; }

# ── Room ──────────────────────────────────────────────────────────────────────
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-dontwarn androidx.room.paging.**

# ── Hilt / Dagger ─────────────────────────────────────────────────────────────
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
-keep class * extends dagger.hilt.android.internal.managers.ViewComponentManager$FragmentContextWrapper { *; }

# ── ML Kit Pose Detection (RF-209) ────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ── Firebase (RF-215) ─────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── CameraX (RF-209) ──────────────────────────────────────────────────────────
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ── Compose / Kotlin ──────────────────────────────────────────────────────────
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-dontwarn kotlinx.coroutines.**

# ── Keep BuildConfig so API_BASE_URL survives minification ────────────────────
-keep class com.runformcoach.runformcoachai.BuildConfig { *; }
