package com.runformcoach.runformcoachai

import com.google.gson.annotations.SerializedName

/**
 * Elite athlete list item (returned by GET /athletes).
 * Aligned with iOS AthleteListItem.
 */
data class AthleteListItem(
    val id: String,
    val name: String,
    val event: String,
    val nationality: String,
    val achievement: String,
    @SerializedName("photo_url") val photoUrl: String
)

/**
 * Full athlete profile returned inside CompareResponse.
 * Aligned with iOS AthleteProfile.
 */
data class AthleteProfile(
    val id: String,
    val name: String,
    val event: String,
    val nationality: String,
    val achievement: String,
    val bio: String,
    @SerializedName("photo_url") val photoUrl: String
)

/**
 * Side-by-side metric comparison row.
 * Aligned with iOS MetricComparison.
 */
data class MetricComparison(
    val metric: String,
    @SerializedName("metric_key") val metricKey: String,
    @SerializedName("user_score") val userScore: Double,
    @SerializedName("athlete_score") val athleteScore: Double,
    @SerializedName("user_label") val userLabel: String,
    @SerializedName("athlete_label") val athleteLabel: String,
    @SerializedName("user_value") val userValue: Double,
    @SerializedName("athlete_value") val athleteValue: Double,
    val gap: Double,
    @SerializedName("gap_pct") val gapPct: Double,
    val status: String  // "gap" | "on_par" | "ahead"
)

/**
 * Request body for POST /compare.
 * Aligned with iOS CompareRequest.
 */
data class CompareRequest(
    @SerializedName("user_metrics") val userMetrics: PoseMetrics,
    @SerializedName("athlete_id") val athleteId: String,
    val language: String
)

/**
 * Response from POST /compare.
 * Aligned with iOS CompareResponse.
 */
data class CompareResponse(
    val athlete: AthleteProfile,
    val comparisons: List<MetricComparison>,
    @SerializedName("top_gaps") val topGaps: List<String>,
    @SerializedName("coaching_narrative") val coachingNarrative: String,
    @SerializedName("overall_similarity_score") val overallSimilarityScore: Double
)

/**
 * User-side metrics sent to the compare endpoint.
 * Mirrors the iOS PoseMetrics struct fields the /compare API expects.
 */
data class PoseMetrics(
    @SerializedName("cadence_estimate_spm") val cadenceEstimateSPM: Double = 170.0,
    @SerializedName("cadence_score") val cadenceScore: Double = 0.8,
    @SerializedName("cadence_status") val cadenceStatus: String = "good",
    @SerializedName("overstride_risk_score") val overstrideRiskScore: Double = 0.6,
    @SerializedName("overstride_status") val overstrideStatus: String = "warning",
    @SerializedName("trunk_lean_degrees") val trunkLeanDegrees: Double = 5.0,
    @SerializedName("trunk_lean_score") val trunkLeanScore: Double = 0.75,
    @SerializedName("trunk_lean_status") val trunkLeanStatus: String = "good",
    @SerializedName("knee_valgus_risk_score") val kneeValgusRiskScore: Double = 0.4,
    @SerializedName("knee_valgus_status") val kneeValgusStatus: String = "good",
    @SerializedName("vertical_oscillation_score") val verticalOscillationScore: Double = 0.7,
    @SerializedName("vertical_oscillation_status") val verticalOscillationStatus: String = "good",
    @SerializedName("shoulder_elevation_score") val shoulderElevationScore: Double = 0.8,
    @SerializedName("shoulder_elevation_status") val shoulderElevationStatus: String = "good",
    @SerializedName("arm_swing_score") val armSwingScore: Double = 0.75,
    @SerializedName("arm_swing_status") val armSwingStatus: String = "good",
    @SerializedName("arm_crossing_score") val armCrossingScore: Double = 0.65,
    @SerializedName("arm_crossing_status") val armCrossingStatus: String = "warning",
    @SerializedName("arm_crossing_direction") val armCrossingDirection: String = "center",
    @SerializedName("backward_elbow_drive_score") val backwardElbowDriveScore: Double = 0.78,
    @SerializedName("backward_elbow_drive_status") val backwardElbowDriveStatus: String = "good",
    @SerializedName("backward_elbow_drive_angle_degrees") val backwardElbowDriveAngleDegrees: Double = 85.0,
    @SerializedName("elbow_angle_score") val elbowAngleScore: Double = 0.72,
    @SerializedName("elbow_angle_status") val elbowAngleStatus: String = "good",
    @SerializedName("elbow_angle_degrees") val elbowAngleDegrees: Double = 92.0,
    @SerializedName("shoulder_arm_independence_score") val shoulderArmIndependenceScore: Double = 0.76,
    @SerializedName("shoulder_arm_independence_status") val shoulderArmIndependenceStatus: String = "good",
    @SerializedName("pelvic_drop_score") val pelvicDropScore: Double = 0.68,
    @SerializedName("pelvic_drop_status") val pelvicDropStatus: String = "warning",
    @SerializedName("step_symmetry_score") val stepSymmetryScore: Double = 0.82,
    @SerializedName("step_symmetry_status") val stepSymmetryStatus: String = "excellent",
    @SerializedName("head_forward_score") val headForwardScore: Double = 0.74,
    @SerializedName("head_forward_status") val headForwardStatus: String = "good",
    @SerializedName("posture_score") val postureScore: Double = 0.79,
    @SerializedName("efficiency_score") val efficiencyScore: Double = 0.77,
    @SerializedName("stability_score") val stabilityScore: Double = 0.73,
    @SerializedName("propulsion_score") val propulsionScore: Double = 0.75,
    @SerializedName("arm_mechanics_score") val armMechanicsScore: Double = 0.74,
    @SerializedName("symmetry_score") val symmetryScore: Double = 0.80,
    @SerializedName("injury_risk_score") val injuryRiskScore: Double = 0.35,
    @SerializedName("frame_count") val frameCount: Int = 300,
    @SerializedName("video_duration_seconds") val videoDurationSeconds: Double = 10.0,
    val notes: List<String> = emptyList(),
    @SerializedName("video_quality_score") val videoQualityScore: Double = 0.85,
    @SerializedName("pose_detection_rate") val poseDetectionRate: Double = 0.95,
    @SerializedName("quality_notes") val qualityNotes: List<String> = emptyList()
)
