import Foundation

// MARK: - Analysis result

struct AnalysisResponse: Codable, Identifiable, Equatable {
    var id: String { summary + String(confidence) + metrics.map(\.name).joined() }
    let summary: String
    let confidence: Double
    let metrics: [Metric]
    let issues: [Issue]
    let videoQualityScore: Double?
    let qualityNotes: [String]?

    enum CodingKeys: String, CodingKey {
        case summary, confidence, metrics, issues
        case videoQualityScore = "video_quality_score"
        case qualityNotes = "quality_notes"
    }
}

struct Metric: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let score: Double
    let status: String
    let explanation: String
}

struct Issue: Codable, Identifiable, Equatable {
    var id: String { title }
    let title: String
    let severity: String
    let explanation: String
    let recommendedExercises: [Exercise]
    enum CodingKeys: String, CodingKey {
        case title, severity, explanation
        case recommendedExercises = "recommended_exercises"
    }
}

struct Exercise: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let category: String
    let sets: Int
    let reps: String
    let frequencyPerWeek: Int
    let reason: String
    enum CodingKeys: String, CodingKey {
        case name, category, sets, reps, reason
        case frequencyPerWeek = "frequency_per_week"
    }
}

// MARK: - Pose metrics (on-device extraction → backend)

struct PoseMetrics: Codable {
    let cadenceEstimateSPM: Double
    let cadenceScore: Double
    let cadenceStatus: String
    let overstrideRiskScore: Double
    let overstrideStatus: String
    let trunkLeanDegrees: Double
    let trunkLeanScore: Double
    let trunkLeanStatus: String
    let kneeValgusRiskScore: Double
    let kneeValgusStatus: String
    let verticalOscillationScore: Double
    let verticalOscillationStatus: String
    let shoulderElevationScore: Double
    let shoulderElevationStatus: String
    let armSwingScore: Double
    let armSwingStatus: String
    let armCrossingScore: Double
    let armCrossingStatus: String
    let armCrossingDirection: String
    let backwardElbowDriveScore: Double
    let backwardElbowDriveStatus: String
    let backwardElbowDriveAngleDegrees: Double
    let elbowAngleScore: Double
    let elbowAngleStatus: String
    let elbowAngleDegrees: Double
    let shoulderArmIndependenceScore: Double
    let shoulderArmIndependenceStatus: String
    let pelvicDropScore: Double
    let pelvicDropStatus: String
    let stepSymmetryScore: Double
    let stepSymmetryStatus: String
    let headForwardScore: Double
    let headForwardStatus: String
    let postureScore: Double
    let efficiencyScore: Double
    let stabilityScore: Double
    let propulsionScore: Double
    let armMechanicsScore: Double
    let symmetryScore: Double
    let injuryRiskScore: Double
    let frameCount: Int
    let videoDurationSeconds: Double
    let notes: [String]
    let videoQualityScore: Double
    let poseDetectionRate: Double
    let qualityNotes: [String]
    var videoMode: String = "side"
    var language: String = "en"
    var gender: String? = nil
    var shoeSize: String? = nil
    var legLengthCm: Double? = nil
    var shoeBrandModel: String? = nil

    enum CodingKeys: String, CodingKey {
        case cadenceEstimateSPM = "cadence_estimate_spm"
        case cadenceScore = "cadence_score"
        case cadenceStatus = "cadence_status"
        case overstrideRiskScore = "overstride_risk_score"
        case overstrideStatus = "overstride_status"
        case trunkLeanDegrees = "trunk_lean_degrees"
        case trunkLeanScore = "trunk_lean_score"
        case trunkLeanStatus = "trunk_lean_status"
        case kneeValgusRiskScore = "knee_valgus_risk_score"
        case kneeValgusStatus = "knee_valgus_status"
        case verticalOscillationScore = "vertical_oscillation_score"
        case verticalOscillationStatus = "vertical_oscillation_status"
        case shoulderElevationScore = "shoulder_elevation_score"
        case shoulderElevationStatus = "shoulder_elevation_status"
        case armSwingScore = "arm_swing_score"
        case armSwingStatus = "arm_swing_status"
        case armCrossingScore = "arm_crossing_score"
        case armCrossingStatus = "arm_crossing_status"
        case armCrossingDirection = "arm_crossing_direction"
        case backwardElbowDriveScore = "backward_elbow_drive_score"
        case backwardElbowDriveStatus = "backward_elbow_drive_status"
        case backwardElbowDriveAngleDegrees = "backward_elbow_drive_angle_degrees"
        case elbowAngleScore = "elbow_angle_score"
        case elbowAngleStatus = "elbow_angle_status"
        case elbowAngleDegrees = "elbow_angle_degrees"
        case shoulderArmIndependenceScore = "shoulder_arm_independence_score"
        case shoulderArmIndependenceStatus = "shoulder_arm_independence_status"
        case pelvicDropScore = "pelvic_drop_score"
        case pelvicDropStatus = "pelvic_drop_status"
        case stepSymmetryScore = "step_symmetry_score"
        case stepSymmetryStatus = "step_symmetry_status"
        case headForwardScore = "head_forward_score"
        case headForwardStatus = "head_forward_status"
        case postureScore = "posture_score"
        case efficiencyScore = "efficiency_score"
        case stabilityScore = "stability_score"
        case propulsionScore = "propulsion_score"
        case armMechanicsScore = "arm_mechanics_score"
        case symmetryScore = "symmetry_score"
        case injuryRiskScore = "injury_risk_score"
        case frameCount = "frame_count"
        case videoDurationSeconds = "video_duration_seconds"
        case notes
        case videoQualityScore = "video_quality_score"
        case poseDetectionRate = "pose_detection_rate"
        case qualityNotes = "quality_notes"
        case videoMode = "video_mode"
        case language
        case gender
        case shoeSize = "shoe_size"
        case legLengthCm = "leg_length_cm"
        case shoeBrandModel = "shoe_brand_model"
    }
}

// MARK: - Feedback & history

enum FeedbackRating: String, Codable, CaseIterable, Identifiable {
    case accurate = "Accurate"
    case partlyAccurate = "Partly accurate"
    case notAccurate = "Not accurate"
    case confusing = "Confusing"
    var id: String { rawValue }
}

struct AnalysisFeedback: Codable, Identifiable, Equatable {
    let id: UUID
    let rating: FeedbackRating
    let comment: String
    let createdAt: Date
}

struct AnalysisHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let videoFilename: String
    let result: AnalysisResponse
    var feedback: AnalysisFeedback?
}

struct ViewMetricCapability: Identifiable {
    let id = UUID()
    let metric: String
    let icon: String
    let level: String  // "Best", "Good", "Limited"
}

// MARK: - Video framing mode

enum VideoMode: String, Codable, CaseIterable, Identifiable {
    case side
    case rear
    case front

    var id: String { rawValue }

    var label: String {
        switch self {
        case .side: return String(localized: "Side")
        case .rear: return String(localized: "Rear")
        case .front: return String(localized: "Front")
        }
    }

    var icon: String {
        switch self {
        case .side: return "rectangle.portrait.on.rectangle.portrait"
        case .rear: return "figure.run"
        case .front: return "person.fill.viewfinder"
        }
    }

    var metrics: String {
        switch self {
        case .side: return String(localized: "cadence, overstride, trunk lean")
        case .rear: return String(localized: "hip stability, knee tracking")
        case .front: return String(localized: "knee valgus, hip symmetry")
        }
    }

    var capabilities: [ViewMetricCapability] {
        switch self {
        case .side:
            return [
                ViewMetricCapability(metric: String(localized: "Cadence"), icon: "metronome", level: String(localized: "Best")),
                ViewMetricCapability(metric: String(localized: "Overstride"), icon: "arrow.forward", level: String(localized: "Best")),
                ViewMetricCapability(metric: String(localized: "Trunk lean"), icon: "arrow.up.forward", level: String(localized: "Best")),
                ViewMetricCapability(metric: String(localized: "Knee valgus"), icon: "figure.run", level: String(localized: "Limited")),
            ]
        case .rear:
            return [
                ViewMetricCapability(metric: String(localized: "Cadence"), icon: "metronome", level: String(localized: "Good")),
                ViewMetricCapability(metric: String(localized: "Knee valgus"), icon: "figure.run", level: String(localized: "Best")),
                ViewMetricCapability(metric: String(localized: "Trunk lean"), icon: "arrow.up.forward", level: String(localized: "Limited")),
                ViewMetricCapability(metric: String(localized: "Overstride"), icon: "arrow.forward", level: String(localized: "Limited")),
            ]
        case .front:
            return [
                ViewMetricCapability(metric: String(localized: "Cadence"), icon: "metronome", level: String(localized: "Good")),
                ViewMetricCapability(metric: String(localized: "Knee valgus"), icon: "figure.run", level: String(localized: "Best")),
                ViewMetricCapability(metric: String(localized: "Trunk lean"), icon: "arrow.up.forward", level: String(localized: "Good")),
                ViewMetricCapability(metric: String(localized: "Overstride"), icon: "arrow.forward", level: String(localized: "Limited")),
            ]
        }
    }
}
