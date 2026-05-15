package com.runformcoach.runformcoachai.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface PlanDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: SavedPlanEntity): Long

    @Query("SELECT * FROM saved_plans ORDER BY created_at DESC")
    fun observeAll(): Flow<List<SavedPlanEntity>>

    @Query("SELECT * FROM saved_plans ORDER BY created_at DESC")
    suspend fun getAll(): List<SavedPlanEntity>

    @Query("SELECT * FROM saved_plans WHERE id = :id")
    suspend fun getById(id: Long): SavedPlanEntity?

    @Delete
    suspend fun delete(entity: SavedPlanEntity)

    @Query("DELETE FROM saved_plans")
    suspend fun deleteAll()
}
