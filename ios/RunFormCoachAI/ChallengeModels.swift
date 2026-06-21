import Foundation

// MARK: - Challenge models

struct ChallengeInfo: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let startDate: String
    let endDate: String
    let days: Int
    let participantCount: Int
    let status: String          // "active" | "ended"
    let joined: Bool?
    let completedDays: Int?
    let todayCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, days, status
        case startDate = "start_date"
        case endDate = "end_date"
        case participantCount = "participant_count"
        case joined
        case completedDays = "completed_days"
        case todayCompleted = "today_completed"
    }

    var isActive: Bool { status == "active" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate) ?? ""
        endDate = try c.decodeIfPresent(String.self, forKey: .endDate) ?? ""
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        participantCount = try c.decodeIfPresent(Int.self, forKey: .participantCount) ?? 0
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "active"
        joined = try c.decodeIfPresent(Bool.self, forKey: .joined)
        completedDays = try c.decodeIfPresent(Int.self, forKey: .completedDays)
        todayCompleted = try c.decodeIfPresent(Bool.self, forKey: .todayCompleted)
    }
}

struct ChallengeJoinRequest: Encodable {
    let iosUserId: String

    enum CodingKeys: String, CodingKey {
        case iosUserId = "ios_user_id"
    }
}

struct ChallengeJoinResponse: Decodable {
    let joined: Bool
    let challengeId: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case joined
        case challengeId = "challenge_id"
        case message
    }
}

struct ChallengeCheckInRequest: Encodable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct ChallengeCheckInResponse: Decodable {
    let status: String
    let checkInCount: Int
    let streakDays: Int
    let todayMetrics: ChallengeTodayMetrics?

    enum CodingKeys: String, CodingKey {
        case status
        case checkInCount = "check_in_count"
        case streakDays = "streak_days"
        case todayMetrics = "today_metrics"
    }
}

/// Decoded from the `today_metrics` dict in ChallengeCheckInResponse.
struct ChallengeTodayMetrics: Codable {
    let cadence: Double?
    let verticalOscillation: Double?
    let gct: Double?
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case cadence
        case verticalOscillation = "vertical_oscillation"
        case gct
        case score
    }
}

struct ChallengeLeaderboardEntry: Codable, Identifiable {
    let iosUserId: String
    let cadenceImprovementPct: Double?
    let oscillationImprovementPct: Double?
    let overallScoreChange: Double?
    let rank: Int
    let displayName: String?
    let name: String?
    let nickname: String?
    let days: Int
    let completedDays: Int
    let isMe: Bool

    var id: String { iosUserId }

    enum CodingKeys: String, CodingKey {
        case iosUserId = "ios_user_id"
        case cadenceImprovementPct = "cadence_improvement_pct"
        case oscillationImprovementPct = "oscillation_improvement_pct"
        case overallScoreChange = "overall_score_change"
        case rank
        case displayName = "display_name"
        case name
        case nickname
        case days
        case completedDays = "completed_days"
        case isMe = "is_me"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        iosUserId = try c.decode(String.self, forKey: .iosUserId)
        cadenceImprovementPct = try c.decodeIfPresent(Double.self, forKey: .cadenceImprovementPct)
        oscillationImprovementPct = try c.decodeIfPresent(Double.self, forKey: .oscillationImprovementPct)
        overallScoreChange = try c.decodeIfPresent(Double.self, forKey: .overallScoreChange)
        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        completedDays = try c.decodeIfPresent(Int.self, forKey: .completedDays) ?? 0
        isMe = try c.decodeIfPresent(Bool.self, forKey: .isMe) ?? false
    }
}
