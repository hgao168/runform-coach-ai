import Foundation
import SwiftUI

struct AnalysisResponse: Codable, Identifiable, Equatable {
    var id: String { summary + String(confidence) + metrics.map(\.name).joined() }
    let summary: String
    let confidence: Double
    let quality: VideoQuality?
    let metrics: [Metric]
    let issues: [Issue]
}

struct VideoQuality: Codable, Equatable {
    let score: Double
    let status: String
    let reasons: [String]
    let tips: [String]
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
        case title
        case severity
        case explanation
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
        case name
        case category
        case sets
        case reps
        case frequencyPerWeek = "frequency_per_week"
        case reason
    }
}

// MARK: - Pose metrics sent to backend

struct PoseMetrics: Codable {
    let cadenceEstimateSPM: Double
    let cadenceScore: Double
    let cadenceStatus: String
    let cadenceQuality: String
    let cadenceStepCount: Int
    let overstrideRiskScore: Double
    let overstrideStatus: String
    let trunkLeanDegrees: Double
    let trunkLeanScore: Double
    let trunkLeanStatus: String
    let kneeValgusRiskScore: Double
    let kneeValgusStatus: String
    let hipDropRiskScore: Double
    let hipDropStatus: String
    let frameCount: Int
    let sampledFrameCount: Int
    let videoDurationSeconds: Double
    let poseDetectionRate: Double
    let ankleVisibilityRate: Double
    let videoQualityScore: Double
    let qualityReasons: [String]
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case cadenceEstimateSPM = "cadence_estimate_spm"
        case cadenceScore = "cadence_score"
        case cadenceStatus = "cadence_status"
        case cadenceQuality = "cadence_quality"
        case cadenceStepCount = "cadence_step_count"
        case overstrideRiskScore = "overstride_risk_score"
        case overstrideStatus = "overstride_status"
        case trunkLeanDegrees = "trunk_lean_degrees"
        case trunkLeanScore = "trunk_lean_score"
        case trunkLeanStatus = "trunk_lean_status"
        case kneeValgusRiskScore = "knee_valgus_risk_score"
        case kneeValgusStatus = "knee_valgus_status"
        case hipDropRiskScore = "hip_drop_risk_score"
        case hipDropStatus = "hip_drop_status"
        case frameCount = "frame_count"
        case sampledFrameCount = "sampled_frame_count"
        case videoDurationSeconds = "video_duration_seconds"
        case poseDetectionRate = "pose_detection_rate"
        case ankleVisibilityRate = "ankle_visibility_rate"
        case videoQualityScore = "video_quality_score"
        case qualityReasons = "quality_reasons"
        case notes
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

// MARK: - Training plan

enum TrainingTarget: String, CaseIterable, Codable, Identifiable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "Half Marathon"
    case marathon = "Marathon"
    case generalFitness = "General Fitness"
    var id: String { rawValue }
}


struct FormIssueContext: Codable, Identifiable, Equatable {
    var id: String { title + severity }
    let title: String
    let severity: String
    let explanation: String
    let exerciseNames: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case severity
        case explanation
        case exerciseNames = "exercise_names"
    }
}

struct TrainingPlanInput: Codable {
    let currentWeeklyKm: Double
    let target: String
    let availableRunningDays: Int
    let injuryFlag: Bool
    let formIssues: [FormIssueContext]
    let recentAnalysisSummary: String?
    let recentAnalysisConfidence: Double?
    let previousWeekSummary: String?

    init(
        currentWeeklyKm: Double,
        target: String,
        availableRunningDays: Int,
        injuryFlag: Bool,
        formIssues: [FormIssueContext] = [],
        recentAnalysisSummary: String? = nil,
        recentAnalysisConfidence: Double? = nil,
        previousWeekSummary: String? = nil
    ) {
        self.currentWeeklyKm = currentWeeklyKm
        self.target = target
        self.availableRunningDays = availableRunningDays
        self.injuryFlag = injuryFlag
        self.formIssues = formIssues
        self.recentAnalysisSummary = recentAnalysisSummary
        self.recentAnalysisConfidence = recentAnalysisConfidence
        self.previousWeekSummary = previousWeekSummary
    }

    enum CodingKeys: String, CodingKey {
        case currentWeeklyKm = "current_weekly_km"
        case target
        case availableRunningDays = "available_running_days"
        case injuryFlag = "injury_flag"
        case formIssues = "form_issues"
        case recentAnalysisSummary = "recent_analysis_summary"
        case recentAnalysisConfidence = "recent_analysis_confidence"
        case previousWeekSummary = "previous_week_summary"
    }
}

struct PlannedWorkout: Codable, Identifiable, Equatable {
    var id: String { day + title }
    let day: String
    let title: String
    let category: String
    let intensity: String
    let details: String
    let purpose: String
    let distanceKm: Double?
    let durationMinutes: Int?
    let coachingFocus: String?

    enum CodingKeys: String, CodingKey {
        case day, title, category, intensity, details, purpose
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case coachingFocus = "coaching_focus"
    }
}

struct TrainingPlanResponse: Codable, Equatable {
    let summary: String
    let plannedWeeklyKm: Double
    let runningDays: Int
    let workouts: [PlannedWorkout]
    let notes: [String]
    let connectedAnalysisUsed: Bool

    enum CodingKeys: String, CodingKey {
        case summary
        case plannedWeeklyKm = "planned_weekly_km"
        case runningDays = "running_days"
        case workouts
        case notes
        case connectedAnalysisUsed = "connected_analysis_used"
    }
}

enum WorkoutStatus: String, Codable, CaseIterable, Identifiable {
    case done     = "Done"
    case skipped  = "Skipped"
    case tooHard  = "Too Hard"
    case pain     = "Pain"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .done:    return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        case .tooHard: return "exclamationmark.circle"
        case .pain:    return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .done:    return Color(red: 0.25, green: 0.96, blue: 0.76)  // mint
        case .skipped: return Color(red: 1.0, green: 0.62, blue: 0.22)   // orange
        case .tooHard: return Color(red: 1.0, green: 0.85, blue: 0.20)   // yellow
        case .pain:    return Color(red: 1.0, green: 0.30, blue: 0.30)   // red
        }
    }
}

struct SavedPlan: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let target: String
    let weeklyKm: Double
    let plan: TrainingPlanResponse
    var workoutLogs: [String: WorkoutStatus] = [:]
}
