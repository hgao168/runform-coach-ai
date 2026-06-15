package com.runformcoach.runformcoachai.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface ProfileDao {

    /** Upsert: keep only one profile row per userId. */
    @androidx.room.Transaction
    suspend fun upsert(entity: RunnerProfileEntity) {
        deleteByUser(entity.userId)
        insert(entity)
    }

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: RunnerProfileEntity): Long

    @Query("SELECT * FROM runner_profiles WHERE user_id = :userId ORDER BY updated_at DESC LIMIT 1")
    suspend fun getByUser(userId: String = "local"): RunnerProfileEntity?

    @Query("SELECT * FROM runner_profiles WHERE user_id = :userId ORDER BY updated_at DESC LIMIT 1")
    fun observeByUser(userId: String = "local"): Flow<RunnerProfileEntity?>

    @Query("DELETE FROM runner_profiles WHERE user_id = :userId")
    suspend fun deleteByUser(userId: String = "local")
}
