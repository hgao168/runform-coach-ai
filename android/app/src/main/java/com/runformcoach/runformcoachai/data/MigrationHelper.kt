package com.runformcoach.runformcoachai.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.runformcoach.runformcoachai.AnalysisHistoryItem
import com.runformcoach.runformcoachai.AnalysisResponse
import com.runformcoach.runformcoachai.TesterProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * One-shot migration from the legacy SharedPreferences store into Room.
 *
 * After a successful migration the "runform_prefs" keys are cleared so the
 * migration runs only once.
 */
object MigrationHelper {

    private const val PREF_NAME = "runform_prefs"
    private const val KEY_HISTORY = "history"
    private const val KEY_PROFILE = "profile"
    private const val KEY_MIGRATED = "migrated_to_room_v1"

    private val gson = Gson()

    /**
     * Execute migration if it hasn't already been done.
     * Safe to call from any coroutine scope (e.g. ViewModel init).
     */
    suspend fun migrateIfNeeded(context: Context, database: RunFormDatabase) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_MIGRATED, false)) return

        withContext(Dispatchers.IO) {
            migrateHistory(prefs, database)
            migrateProfile(prefs, database)
            prefs.edit { putBoolean(KEY_MIGRATED, true) }
        }
    }

    private suspend fun migrateHistory(prefs: SharedPreferences, db: RunFormDatabase) {
        val json = prefs.getString(KEY_HISTORY, "[]") ?: "[]"
        val items: List<AnalysisHistoryItem> = runCatching {
            val type = object : TypeToken<List<AnalysisHistoryItem>>() {}.type
            gson.fromJson<List<AnalysisHistoryItem>>(json, type) ?: emptyList()
        }.getOrDefault(emptyList())

        if (items.isEmpty()) return

        val dao = db.analysisDao()
        items.forEach { item ->
            dao.insert(
                AnalysisHistoryEntity(
                    userId = "local",
                    videoUri = item.videoFilename,
                    analysisJson = gson.toJson(item.result),
                    metricsJson = gson.toJson(item.result.metrics),
                    confidence = item.result.confidence,
                    createdAt = item.createdAt
                )
            )
        }
    }

    private suspend fun migrateProfile(prefs: SharedPreferences, db: RunFormDatabase) {
        val json = prefs.getString(KEY_PROFILE, null) ?: return
        val profile: TesterProfile = runCatching {
            gson.fromJson(json, TesterProfile::class.java)
        }.getOrNull() ?: return

        db.profileDao().upsert(
            RunnerProfileEntity(
                userId = "local",
                profileJson = gson.toJson(profile),
                updatedAt = System.currentTimeMillis()
            )
        )
    }
}
