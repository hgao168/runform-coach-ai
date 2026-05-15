package com.runformcoach.runformcoachai.data

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * Main Room database for RunForm Coach AI.
 *
 * Schema version history:
 *   version 1 — Initial schema (analysis_history, saved_plans, runner_profiles)
 */
@Database(
    entities = [
        AnalysisHistoryEntity::class,
        SavedPlanEntity::class,
        RunnerProfileEntity::class
    ],
    version = 1,
    exportSchema = true
)
abstract class RunFormDatabase : RoomDatabase() {
    abstract fun analysisDao(): AnalysisDao
    abstract fun planDao(): PlanDao
    abstract fun profileDao(): ProfileDao
}
