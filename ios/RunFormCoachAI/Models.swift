import Foundation

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
    let frameCount: Int
    let videoDurationSeconds: Double
    let notes: [String]
    let videoQualityScore: Double
    let poseDetectionRate: Double
    let qualityNotes: [String]
    var videoMode: String = "side"

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
        case frameCount = "frame_count"
        case videoDurationSeconds = "video_duration_seconds"
        case notes
        case videoQualityScore = "video_quality_score"
        case poseDetectionRate = "pose_detection_rate"
        case qualityNotes = "quality_notes"
        case videoMode = "video_mode"
    }
}

enum RunnerLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
}

struct TesterProfile: Codable, Equatable {
    var nickname: String = ""
    var level: RunnerLevel = .beginner
    var weeklyMileageKm: Double = 15
    var target: String = "General fitness"
    var injuryNote: String = ""
}

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

enum VideoMode: String, Codable, CaseIterable, Identifiable {
    case side
    case rear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .side: return "Side"
        case .rear: return "Rear"
        }
    }

    var icon: String {
        switch self {
        case .side: return "rectangle.portrait.on.rectangle.portrait"
        case .rear: return "figure.run"
        }
    }

    var metrics: String {
        switch self {
        case .side: return "cadence, overstride, trunk lean"
        case .rear: return "hip stability, knee tracking"
        }
    }
}
