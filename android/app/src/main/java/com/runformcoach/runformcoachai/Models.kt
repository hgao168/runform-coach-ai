package com.runformcoach.runformcoachai

import com.google.gson.annotations.SerializedName

data class AnalysisResponse(
    val summary: String,
    val confidence: Double,
    val metrics: List<Metric>,
    val issues: List<Issue>
)

data class Metric(
    val name: String,
    val score: Double,
    val status: String,
    val explanation: String
)

data class Issue(
    val title: String,
    val severity: String,
    val explanation: String,
    @SerializedName("recommended_exercises")
    val recommendedExercises: List<Exercise>
)

data class Exercise(
    val name: String,
    val category: String,
    val sets: Int,
    val reps: String,
    @SerializedName("frequency_per_week")
    val frequencyPerWeek: Int,
    val reason: String
)
