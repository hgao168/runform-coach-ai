import Foundation
import SwiftUI

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
    let verticalOscillationScore: Double
    let verticalOscillationStatus: String
    let shoulderElevationScore: Double
    let shoulderElevationStatus: String
    let armSwingScore: Double
    let armSwingStatus: String
    let pelvicDropScore: Double
    let pelvicDropStatus: String
    let stepSymmetryScore: Double
    let stepSymmetryStatus: String
    let headForwardScore: Double
    let headForwardStatus: String
    let frameCount: Int
    let videoDurationSeconds: Double
    let notes: [String]
    let videoQualityScore: Double
    let poseDetectionRate: Double
    let qualityNotes: [String]
    var videoMode: String = "side"
    var language: String = "en"

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
        case pelvicDropScore = "pelvic_drop_score"
        case pelvicDropStatus = "pelvic_drop_status"
        case stepSymmetryScore = "step_symmetry_score"
        case stepSymmetryStatus = "step_symmetry_status"
        case headForwardScore = "head_forward_score"
        case headForwardStatus = "head_forward_status"
        case frameCount = "frame_count"
        case videoDurationSeconds = "video_duration_seconds"
        case notes
        case videoQualityScore = "video_quality_score"
        case poseDetectionRate = "pose_detection_rate"
        case qualityNotes = "quality_notes"
        case videoMode = "video_mode"
        case language
    }
}

enum RunnerLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
}

struct TesterProfile: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var nickname: String = ""
    var level: RunnerLevel = .beginner
    var weeklyMileageKm: Double = 15
    var runningDaysPerWeek: Int = 3
    var heightCm: Double = 170
    var weightKg: Double = 70
    var target: String = "General Fitness"
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

struct ViewMetricCapability: Identifiable {
    let id = UUID()
    let metric: String
    let icon: String
    let level: String  // "Best", "Good", "Limited"
}

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
    let language: String

    init(
        currentWeeklyKm: Double,
        target: String,
        availableRunningDays: Int,
        injuryFlag: Bool,
        formIssues: [FormIssueContext] = [],
        recentAnalysisSummary: String? = nil,
        recentAnalysisConfidence: Double? = nil,
        previousWeekSummary: String? = nil,
        language: String = "en"
    ) {
        self.currentWeeklyKm = currentWeeklyKm
        self.target = target
        self.availableRunningDays = availableRunningDays
        self.injuryFlag = injuryFlag
        self.formIssues = formIssues
        self.recentAnalysisSummary = recentAnalysisSummary
        self.recentAnalysisConfidence = recentAnalysisConfidence
        self.previousWeekSummary = previousWeekSummary
        self.language = language
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
        case language
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
    case done = "Done"
    case skipped = "Skipped"
    case tooHard = "Too Hard"
    case pain = "Pain"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .done: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        case .tooHard: return "exclamationmark.circle"
        case .pain: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .done: return Color(red: 0.25, green: 0.96, blue: 0.76)
        case .skipped: return Color(red: 1.0, green: 0.62, blue: 0.22)
        case .tooHard: return Color(red: 1.0, green: 0.85, blue: 0.20)
        case .pain: return Color(red: 1.0, green: 0.30, blue: 0.30)
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

struct ManualWeekDayPlan: Codable, Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let dayName: String
    var planText: String
}

struct ManualNextWeekPlan: Codable, Identifiable, Equatable {
    let id: UUID
    let weekStartMonday: Date
    let weekEndSunday: Date
    let createdAt: Date
    var updatedAt: Date
    var days: [ManualWeekDayPlan]
}

// ── Elite athlete comparison ─────────────────────────────────────────────────

struct AthleteListItem: Codable, Identifiable {
    let id: String
    let name: String
    let event: String
    let nationality: String
    let achievement: String
    let photoUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name, event, nationality, achievement
        case photoUrl = "photo_url"
    }
}

struct AthleteProfile: Codable {
    let id: String
    let name: String
    let event: String
    let nationality: String
    let achievement: String
    let bio: String
    let photoUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name, event, nationality, achievement, bio
        case photoUrl = "photo_url"
    }
}

struct MetricComparison: Codable, Identifiable {
    var id: String { metricKey }
    let metric: String
    let metricKey: String
    let userScore: Double
    let athleteScore: Double
    let userLabel: String
    let athleteLabel: String
    let userValue: Double
    let athleteValue: Double
    let gap: Double
    let gapPct: Double
    let status: String  // "gap" | "on_par" | "ahead"

    enum CodingKeys: String, CodingKey {
        case metric
        case metricKey = "metric_key"
        case userScore = "user_score"
        case athleteScore = "athlete_score"
        case userLabel = "user_label"
        case athleteLabel = "athlete_label"
        case userValue = "user_value"
        case athleteValue = "athlete_value"
        case gap
        case gapPct = "gap_pct"
        case status
    }
}

struct CompareRequest: Codable {
    let userMetrics: PoseMetrics
    let athleteId: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case userMetrics = "user_metrics"
        case athleteId = "athlete_id"
        case language
    }
}

struct CompareResponse: Codable {
    let athlete: AthleteProfile
    let comparisons: [MetricComparison]
    let topGaps: [String]
    let coachingNarrative: String
    let overallSimilarityScore: Double

    enum CodingKeys: String, CodingKey {
        case athlete, comparisons
        case topGaps = "top_gaps"
        case coachingNarrative = "coaching_narrative"
        case overallSimilarityScore = "overall_similarity_score"
    }
}
