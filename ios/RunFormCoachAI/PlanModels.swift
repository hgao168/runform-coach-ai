import Foundation
import SwiftUI

// MARK: - Training enums

enum TrainingTarget: String, CaseIterable, Codable, Identifiable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "Half Marathon"
    case marathon = "Marathon"
    case generalFitness = "General Fitness"

    var id: String { rawValue }
}

enum TrainingLevel: String, CaseIterable, Codable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }
}

enum MarathonMajor: String, CaseIterable, Codable, Identifiable {
    case tokyo = "Tokyo"
    case boston = "Boston"
    case london = "London"
    case berlin = "Berlin"
    case chicago = "Chicago"
    case newYorkCity = "New York City"
    case sydney = "Sydney"

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

// MARK: - Plan request

struct TrainingPlanInput: Codable {
    let currentWeeklyKm: Double
    let target: String
    let availableRunningDays: Int
    let selectedRunDays: [String]
    let injuryFlag: Bool
    let formIssues: [FormIssueContext]
    let recentAnalysisSummary: String?
    let recentAnalysisConfidence: Double?
    let previousWeekSummary: String?
    let language: String
    let marathonMajor: String?
    let marathonPlanWeeks: Int?
    let includeMarathonBlock: Bool
    let stravaRunCount: Int?
    let stravaLongestRunKm: Double?
    let stravaAvgPaceSPerKm: Double?
    let stravaLoadTrend: String?
    let trainingLevel: String?
    let planDurationWeeks: Int?
    let includeRaceBlock: Bool

    init(
        currentWeeklyKm: Double,
        target: String,
        availableRunningDays: Int,
        selectedRunDays: [String] = [],
        injuryFlag: Bool,
        formIssues: [FormIssueContext] = [],
        recentAnalysisSummary: String? = nil,
        recentAnalysisConfidence: Double? = nil,
        previousWeekSummary: String? = nil,
        language: String = "en",
        marathonMajor: String? = nil,
        marathonPlanWeeks: Int? = nil,
        includeMarathonBlock: Bool = true,
        stravaRunCount: Int? = nil,
        stravaLongestRunKm: Double? = nil,
        stravaAvgPaceSPerKm: Double? = nil,
        stravaLoadTrend: String? = nil,
        trainingLevel: String? = nil,
        planDurationWeeks: Int? = nil,
        includeRaceBlock: Bool = false
    ) {
        self.currentWeeklyKm = currentWeeklyKm
        self.target = target
        self.availableRunningDays = availableRunningDays
        self.selectedRunDays = selectedRunDays
        self.injuryFlag = injuryFlag
        self.formIssues = formIssues
        self.recentAnalysisSummary = recentAnalysisSummary
        self.recentAnalysisConfidence = recentAnalysisConfidence
        self.previousWeekSummary = previousWeekSummary
        self.language = language
        self.marathonMajor = marathonMajor
        self.marathonPlanWeeks = marathonPlanWeeks
        self.includeMarathonBlock = includeMarathonBlock
        self.stravaRunCount = stravaRunCount
        self.stravaLongestRunKm = stravaLongestRunKm
        self.stravaAvgPaceSPerKm = stravaAvgPaceSPerKm
        self.stravaLoadTrend = stravaLoadTrend
        self.trainingLevel = trainingLevel
        self.planDurationWeeks = planDurationWeeks
        self.includeRaceBlock = includeRaceBlock
    }

    enum CodingKeys: String, CodingKey {
        case currentWeeklyKm = "current_weekly_km"
        case target
        case availableRunningDays = "available_running_days"
        case selectedRunDays = "selected_run_days"
        case injuryFlag = "injury_flag"
        case formIssues = "form_issues"
        case recentAnalysisSummary = "recent_analysis_summary"
        case recentAnalysisConfidence = "recent_analysis_confidence"
        case previousWeekSummary = "previous_week_summary"
        case language
        case marathonMajor = "marathon_major"
        case marathonPlanWeeks = "marathon_plan_weeks"
        case includeMarathonBlock = "include_marathon_block"
        case stravaRunCount = "strava_run_count"
        case stravaLongestRunKm = "strava_longest_run_km"
        case stravaAvgPaceSPerKm = "strava_avg_pace_s_per_km"
        case stravaLoadTrend = "strava_load_trend"
        case trainingLevel = "training_level"
        case planDurationWeeks = "plan_duration_weeks"
        case includeRaceBlock = "include_race_block"
    }
}

// MARK: - Plan response

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
    let marathonPlan: MarathonPlanBlock?
    let racePlan: RacePlanBlock?

    enum CodingKeys: String, CodingKey {
        case summary
        case plannedWeeklyKm = "planned_weekly_km"
        case runningDays = "running_days"
        case workouts
        case notes
        case connectedAnalysisUsed = "connected_analysis_used"
        case marathonPlan = "marathon_plan"
        case racePlan = "race_plan"
    }
}

struct MarathonPlanWeek: Codable, Equatable, Identifiable {
    var id: Int { week }
    let week: Int
    let phase: String
    let targetKm: Double
    let longRunKm: Double
    let keyWorkout: String
    let terrainFocus: String
    let workouts: [PlannedWorkout]

    enum CodingKeys: String, CodingKey {
        case week, phase
        case targetKm = "target_km"
        case longRunKm = "long_run_km"
        case keyWorkout = "key_workout"
        case terrainFocus = "terrain_focus"
        case workouts
    }
}

struct MarathonPlanBlock: Codable, Equatable {
    let race: String
    let totalWeeks: Int
    let planProfile: String
    let courseProfile: String
    let elevationNote: String
    let weeks: [MarathonPlanWeek]

    enum CodingKeys: String, CodingKey {
        case race
        case totalWeeks = "total_weeks"
        case planProfile = "plan_profile"
        case courseProfile = "course_profile"
        case elevationNote = "elevation_note"
        case weeks
    }
}

struct RacePlanWeek: Codable, Equatable, Identifiable {
    var id: Int { week }
    let week: Int
    let phase: String
    let targetKm: Double
    let longRunKm: Double
    let keyWorkout: String
    let workouts: [PlannedWorkout]

    enum CodingKeys: String, CodingKey {
        case week, phase
        case targetKm = "target_km"
        case longRunKm = "long_run_km"
        case keyWorkout = "key_workout"
        case workouts
    }
}

struct RacePlanBlock: Codable, Equatable {
    let target: String
    let totalWeeks: Int
    let level: String
    let weeks: [RacePlanWeek]

    enum CodingKeys: String, CodingKey {
        case target
        case totalWeeks = "total_weeks"
        case level
        case weeks
    }
}

// MARK: - Workout logging & saved plans

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

extension String {
    /// Repairs common mojibake tokens seen in backend-generated plan text.
    var normalizedPlanText: String {
        replacingOccurrences(of: "â€¢", with: "•")
            .replacingOccurrences(of: "Â " , with: " ")
            .replacingOccurrences(of: "Â", with: "")
    }
}
