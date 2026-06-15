package com.runformcoach.runformcoachai.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface AnalysisDao {

    /** Insert a new analysis record; returns the generated row ID. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: AnalysisHistoryEntity): Long

    /** Flow-emitting all records, newest first (reactive UI). */
    @Query("SELECT * FROM analysis_history ORDER BY created_at DESC")
    fun observeAll(): Flow<List<AnalysisHistoryEntity>>

    /** One-shot query for migration helpers. */
    @Query("SELECT * FROM analysis_history ORDER BY created_at DESC")
    suspend fun getAll(): List<AnalysisHistoryEntity>

    /** Fetch single record by ID. */
    @Query("SELECT * FROM analysis_history WHERE id = :id")
    suspend fun getById(id: Long): AnalysisHistoryEntity?

    /** Delete a specific record. */
    @Delete
    suspend fun delete(entity: AnalysisHistoryEntity)

    /** Delete all records (e.g. clear history). */
    @Query("DELETE FROM analysis_history")
    suspend fun deleteAll()

    /** Count total records for this user. */
    @Query("SELECT COUNT(*) FROM analysis_history WHERE user_id = :userId")
    suspend fun countByUser(userId: String = "local"): Int
}
