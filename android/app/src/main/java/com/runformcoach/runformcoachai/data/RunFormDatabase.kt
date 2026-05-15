package com.runformcoach.runformcoachai.data

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * Main Room database for RunForm Coach AI.
 *
 * Schema version history:
 *   version 1 — Initial schema (analysis_history, saved_plans, runner_profiles)
 *   version 2 — Added pending_feedback table for offline feedback cache (RF-203)
 */
@Database(
    entities = [
        AnalysisHistoryEntity::class,
        SavedPlanEntity::class,
        RunnerProfileEntity::class,
        FeedbackEntity::class
    ],
    version = 2,
    exportSchema = true
)
abstract class RunFormDatabase : RoomDatabase() {
    abstract fun analysisDao(): AnalysisDao
    abstract fun planDao(): PlanDao
    abstract fun profileDao(): ProfileDao
    abstract fun feedbackDao(): FeedbackDao
}
