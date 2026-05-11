import Foundation

// MARK: - Elite athlete comparison

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
