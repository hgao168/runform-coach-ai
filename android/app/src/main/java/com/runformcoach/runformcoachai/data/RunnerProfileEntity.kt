package com.runformcoach.runformcoachai.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room entity for the runner profile.
 * Only one row per user is expected (enforced by [ProfileDao.upsert]).
 *
 * @param id         Auto-generated primary key.
 * @param userId     Placeholder for multi-user (defaults to "local").
 * @param profileJson Full [TesterProfile] serialized via Gson.
 * @param updatedAt   Epoch millis of the last update.
 */
@Entity(tableName = "runner_profiles")
data class RunnerProfileEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "user_id")
    val userId: String = "local",

    @ColumnInfo(name = "profile_json")
    val profileJson: String,

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long
)
