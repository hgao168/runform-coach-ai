import Foundation

// MARK: - Backend Response Models

/// Response from GET /api/v1/sessions/trends — weekly trend data.
struct WeeklyTrendsResponse: Codable {
    let currentWeek: WeekSummary
    let previousWeek: WeekSummary
    let weeklyTrends: [WeekSummary]
    let aiSuggestion: String?
    let badges: [UserBadge]

    enum CodingKeys: String, CodingKey {
        case currentWeek = "current_week"
        case previousWeek = "previous_week"
        case weeklyTrends = "weekly_trends"
        case aiSuggestion = "ai_suggestion"
        case badges
    }
}

/// One week's aggregated running metrics.
struct WeekSummary: Codable {
    let weekLabel: String
    let weekStartIso: String
    let avgCadenceSPM: Double
    let avgAmplitudeCm: Double
    let avgGCTMs: Double
    let totalDistanceKm: Double
    let totalSessions: Int
    let totalDurationMin: Double

    enum CodingKeys: String, CodingKey {
        case weekLabel = "week_label"
        case weekStartIso = "week_start_iso"
        case avgCadenceSPM = "avg_cadence_spm"
        case avgAmplitudeCm = "avg_amplitude_cm"
        case avgGCTMs = "avg_gct_ms"
        case totalDistanceKm = "total_distance_km"
        case totalSessions = "total_sessions"
        case totalDurationMin = "total_duration_min"
    }
}

/// Achievement badge earned this week.
struct UserBadge: Codable, Identifiable {
    var id: String { badgeId }
    let badgeId: String
    let badgeName: String
    let badgeIcon: String
    let badgeDescription: String

    enum CodingKeys: String, CodingKey {
        case badgeId = "badge_id"
        case badgeName = "badge_name"
        case badgeIcon = "badge_icon"
        case badgeDescription = "badge_description"
    }
}

// MARK: - ViewModel State

enum WeeklyInsightState {
    case loading
    case success(WeeklyTrendsResponse)
    case error(String)
}

// MARK: - Delta Helpers

enum TrendDirection {
    case up, down, flat
}

struct MetricDelta {
    let currentValue: Double
    let previousValue: Double
    let delta: Double
    let deltaPct: Double
    let direction: TrendDirection
    let unit: String
}

func computeDelta(
    current: Double,
    previous: Double,
    unit: String,
    invertGood: Bool = false
) -> MetricDelta {
    let delta = current - previous
    let deltaPct = previous != 0 ? (delta / previous) * 100.0 : 0.0
    let rawDirection: TrendDirection = {
        if delta > 0.01 { return .up }
        if delta < -0.01 { return .down }
        return .flat
    }()
    let direction: TrendDirection = invertGood
        ? (rawDirection == .up ? .down : rawDirection == .down ? .up : .flat)
        : rawDirection
    return MetricDelta(
        currentValue: current,
        previousValue: previous,
        delta: delta,
        deltaPct: deltaPct,
        direction: direction,
        unit: unit
    )
}
