package com.runformcoach.runformcoachai.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room entity for offline feedback storage.
 * Pending feedback is stored locally and synced when the network is available.
 *
 * @param id          Auto-generated primary key.
 * @param analysisId  The ID of the analysis this feedback pertains to.
 * @param rating      Star rating 1–5.
 * @param comment     Optional text comment.
 * @param synced      Whether this feedback has been successfully sent to the server.
 * @param createdAt   Epoch millis when the feedback was created.
 */
@Entity(tableName = "pending_feedback")
data class FeedbackEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "analysis_id")
    val analysisId: String,

    val rating: Int,

    val comment: String = "",

    val synced: Boolean = false,

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis()
)
