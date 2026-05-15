package com.runformcoach.runformcoachai.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Room entity persisting a single video analysis result.
 * Mirrors the iOS CoreData model AnalysisRecord.
 *
 * @param id          Auto-generated primary key.
 * @param userId      Placeholder for future multi-user (defaults to "local").
 * @param videoUri    Content URI string of the uploaded video.
 * @param analysisJson  Full [AnalysisResponse] serialized via Gson.
 * @param metricsJson   Serialized list of [Metric] objects for quick queries.
 * @param confidence    Confidence score 0.0–1.0.
 * @param createdAt     Epoch millis of when the analysis completed.
 */
@Entity(tableName = "analysis_history")
data class AnalysisHistoryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "user_id")
    val userId: String = "local",

    @ColumnInfo(name = "video_uri")
    val videoUri: String,

    @ColumnInfo(name = "analysis_json")
    val analysisJson: String,

    @ColumnInfo(name = "metrics_json")
    val metricsJson: String,

    @ColumnInfo(name = "confidence")
    val confidence: Double,

    @ColumnInfo(name = "created_at")
    val createdAt: Long
)
