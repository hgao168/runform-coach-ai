import Foundation

// MARK: - Strava OAuth & connection

struct StravaConnectResponse: Codable, Equatable {
    let authorizeURL: URL
    let state: String

    enum CodingKeys: String, CodingKey {
        case authorizeURL = "authorize_url"
        case state
    }
}

struct StravaStatusResponse: Codable, Equatable {
    let connected: Bool
    let provider: String
    let providerAthleteId: String?
    let scope: String?
    let expiresAt: String?
    let lastRefreshAt: String?

    enum CodingKeys: String, CodingKey {
        case connected
        case provider
        case providerAthleteId = "provider_athlete_id"
        case scope
        case expiresAt = "expires_at"
        case lastRefreshAt = "last_refresh_at"
    }
}

struct StravaDisconnectResponse: Codable, Equatable {
    let disconnected: Bool
    let provider: String
    let iosUserID: String
    let revoked: Bool
    let deletedRunCount: Int
    let deletedWeeklyStatCount: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case disconnected
        case provider
        case iosUserID = "ios_user_id"
        case revoked
        case deletedRunCount = "deleted_run_count"
        case deletedWeeklyStatCount = "deleted_weekly_stat_count"
        case message
    }
}

// MARK: - Strava activity summaries

struct StravaWeeklySummaryItem: Codable, Equatable, Identifiable {
    var id: String { weekStart }
    let weekStart: String
    let totalDistanceKm: Double
    let runCount: Int
    let longestRunKm: Double
    let avgPaceSPerKm: Double?
    let intensityScore: Double?

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case totalDistanceKm = "total_distance_km"
        case runCount = "run_count"
        case longestRunKm = "longest_run_km"
        case avgPaceSPerKm = "avg_pace_s_per_km"
        case intensityScore = "intensity_score"
    }
}

struct StravaSyncResponse: Codable, Equatable {
    let connected: Bool
    let iosUserID: String
    let lookbackDays: Int
    let scannedActivityCount: Int
    let syncedRunCount: Int
    let weekCount: Int
    let syncedAt: String
    let weeklyStats: [StravaWeeklySummaryItem]

    enum CodingKeys: String, CodingKey {
        case connected
        case iosUserID = "ios_user_id"
        case lookbackDays = "lookback_days"
        case scannedActivityCount = "scanned_activity_count"
        case syncedRunCount = "synced_run_count"
        case weekCount = "week_count"
        case syncedAt = "synced_at"
        case weeklyStats = "weekly_stats"
    }
}

struct StravaSummaryResponse: Codable, Equatable {
    let connected: Bool
    let iosUserID: String
    let weeks: Int
    let weeklyStats: [StravaWeeklySummaryItem]
    let totalDistanceKm: Double
    let averageWeeklyKm: Double
    let runCount: Int
    let longestRunKm: Double
    let avgPaceSPerKm: Double?
    let intensityEstimate: Double?
    let loadTrend: String
    let trendDeltaPct: Double?
    let lastSyncAt: String?

    enum CodingKeys: String, CodingKey {
        case connected
        case iosUserID = "ios_user_id"
        case weeks
        case weeklyStats = "weekly_stats"
        case totalDistanceKm = "total_distance_km"
        case averageWeeklyKm = "average_weekly_km"
        case runCount = "run_count"
        case longestRunKm = "longest_run_km"
        case avgPaceSPerKm = "avg_pace_s_per_km"
        case intensityEstimate = "intensity_estimate"
        case loadTrend = "load_trend"
        case trendDeltaPct = "trend_delta_pct"
        case lastSyncAt = "last_sync_at"
    }
}
