package com.runformcoach.runformcoachai.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface FeedbackDao {

    /** Insert pending feedback; returns row ID. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: FeedbackEntity): Long

    /** Observe all unsynced feedback (for background sync). */
    @Query("SELECT * FROM pending_feedback WHERE synced = 0 ORDER BY created_at ASC")
    fun observeUnsynced(): Flow<List<FeedbackEntity>>

    /** Get all unsynced feedback as a one-shot (for manual sync). */
    @Query("SELECT * FROM pending_feedback WHERE synced = 0 ORDER BY created_at ASC")
    suspend fun getUnsynced(): List<FeedbackEntity>

    /** Mark a feedback as synced. */
    @Query("UPDATE pending_feedback SET synced = 1 WHERE id = :id")
    suspend fun markSynced(id: Long)

    /** Delete synced feedback older than retention period. */
    @Query("DELETE FROM pending_feedback WHERE synced = 1 AND created_at < :before")
    suspend fun deleteSyncedOlderThan(before: Long)

    /** Count pending unsynced feedback. */
    @Query("SELECT COUNT(*) FROM pending_feedback WHERE synced = 0")
    suspend fun countUnsynced(): Int
}
