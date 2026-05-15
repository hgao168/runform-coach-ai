package com.runformcoach.runformcoachai.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room entity for saved training plans.
 *
 * @param id        Auto-generated primary key.
 * @param userId    Placeholder for multi-user (defaults to "local").
 * @param planJson  Full [TrainingPlanResponse] serialized via Gson.
 * @param planType  Discriminator: "ai" (generated) or "manual".
 * @param createdAt Epoch millis when the plan was created.
 */
@Entity(tableName = "saved_plans")
data class SavedPlanEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "user_id")
    val userId: String = "local",

    @ColumnInfo(name = "plan_json")
    val planJson: String,

    @ColumnInfo(name = "plan_type")
    val planType: String = "ai",

    @ColumnInfo(name = "created_at")
    val createdAt: Long
)
