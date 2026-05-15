import Foundation

final class APIClient {
    static let shared = APIClient()
    private static let defaultStravaBackendBaseURL = "https://runform-coach-ai-production.up.railway.app"
    private static let maxRetries = 2
    private static let baseRetryDelay: TimeInterval = 0.5

    /// Resolved base URL — throws if not configured, instead of fatalError.
    private static func resolvedBaseURL() throws -> URL {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return url
        }
        throw APIError.configuration("BACKEND_BASE_URL is not configured. Check project.yml build settings.")
    }

    /// Resolved Strava base URL with fallback chain.
    private static func resolvedStravaBaseURL() throws -> URL {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "STRAVA_BACKEND_BASE_URL") as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return url
        }
        if let defaultURL = URL(string: defaultStravaBackendBaseURL) {
            return defaultURL
        }
        if let fallback = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           !fallback.isEmpty,
           let fallbackURL = URL(string: fallback) {
            return fallbackURL
        }
        throw APIError.configuration("BACKEND_BASE_URL is not configured. Check project.yml build settings.")
    }

    // MARK: - Retry policy

    /// Retry an async throwing operation up to `maxRetries` times with exponential backoff.
    private static func withRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error? = nil
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                // Do not retry on cancellation or configuration errors
                if error is CancellationError || error is APIError.ConfigurationError {
                    throw error
                }
                if attempt < maxRetries {
                    let delay = baseRetryDelay * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? APIError.server("Request failed after \(maxRetries + 1) attempts")
    }

    // MARK: - API Methods

    func analyzeMetrics(_ metrics: PoseMetrics) async throws -> AnalysisResponse {
        let baseURL = try Self.resolvedBaseURL()
        let endpoint = baseURL.appendingPathComponent("analyze-metrics")
        return try await Self.withRetry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 45
            request.httpBody = try JSONEncoder().encode(metrics)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            return try JSONDecoder().decode(AnalysisResponse.self, from: data)
        }
    }

    func fetchStravaConnectResponse(iosUserID: String) async throws -> StravaConnectResponse {
        try await requestStrava(
            path: "connect",
            method: "GET",
            iosUserID: iosUserID,
            notFoundMessage: "Strava connect route not found",
            exhaustedMessage: "Unable to load Strava connect URL from available backends."
        )
    }

    func fetchStravaStatus(iosUserID: String) async throws -> StravaStatusResponse {
        try await requestStrava(
            path: "status",
            method: "GET",
            iosUserID: iosUserID,
            notFoundMessage: "Strava status route not found",
            exhaustedMessage: "Unable to load Strava status from available backends."
        )
    }

    func disconnectStrava(iosUserID: String) async throws -> StravaDisconnectResponse {
        try await requestStrava(
            path: "disconnect",
            method: "POST",
            iosUserID: iosUserID,
            body: ["ios_user_id": iosUserID],
            notFoundMessage: "Strava disconnect route not found",
            exhaustedMessage: "Unable to disconnect Strava from available backends."
        )
    }

    func syncStravaActivities(iosUserID: String) async throws -> StravaSyncResponse {
        try await requestStrava(
            path: "sync",
            method: "POST",
            iosUserID: iosUserID,
            body: ["ios_user_id": iosUserID],
            timeout: 30,
            notFoundMessage: "Strava sync route not found",
            exhaustedMessage: "Unable to sync Strava activities from available backends."
        )
    }

    func fetchStravaSummary(iosUserID: String, weeks: Int = 4) async throws -> StravaSummaryResponse {
        let baseURL = try Self.resolvedBaseURL()
        var components = URLComponents(url: baseURL.appendingPathComponent("integrations/strava/summary"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "ios_user_id", value: iosUserID),
            URLQueryItem(name: "weeks", value: String(weeks))
        ]
        guard let endpoint = components?.url else {
            throw APIError.configuration("Failed to build Strava summary URL.")
        }

        return try await Self.withRetry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            return try JSONDecoder().decode(StravaSummaryResponse.self, from: data)
        }
    }

    // Backward-compatible fallback only. Prefer analyzeMetrics(_:), because it sends numeric pose metrics instead of the raw video.
    func analyzeVideo(fileURL: URL) async throws -> AnalysisResponse {
        let baseURL = try Self.resolvedBaseURL()
        let endpoint = baseURL.appendingPathComponent("analyze")
        return try await Self.withRetry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 60

            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            let videoData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent.isEmpty ? "running-video.mov" : fileURL.lastPathComponent
            let mimeType = filename.lowercased().hasSuffix(".mp4") ? "video/mp4" : "video/quicktime"

            request.httpBody = makeMultipartBody(
                fieldName: "video",
                filename: filename,
                mimeType: mimeType,
                data: videoData,
                boundary: boundary
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            return try JSONDecoder().decode(AnalysisResponse.self, from: data)
        }
    }

    func generateTrainingPlan(input: TrainingPlanInput) async throws -> TrainingPlanResponse {
        let baseURL = try Self.resolvedBaseURL()
        let endpoint = baseURL.appendingPathComponent("training-plan")
        return try await Self.withRetry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = try JSONEncoder().encode(input)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            let decoder = JSONDecoder()
            return try decoder.decode(TrainingPlanResponse.self, from: data)
        }
    }

    func fetchAthletes() async throws -> [AthleteListItem] {
        let baseURL = try Self.resolvedBaseURL()
        let endpoint = baseURL.appendingPathComponent("athletes")
        return try await Self.withRetry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            return try JSONDecoder().decode([AthleteListItem].self, from: data)
        }
    }

    func compareWithAthlete(athleteId: String, metrics: PoseMetrics) async throws -> CompareResponse {
        let baseURL = try Self.resolvedBaseURL()
        let endpoint = baseURL.appendingPathComponent("compare")
        return try await Self.withRetry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            let language = Bundle.main.preferredLocalizations.first ?? "en"
            request.httpBody = try JSONEncoder().encode(
                CompareRequest(userMetrics: metrics, athleteId: athleteId, language: language)
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            return try JSONDecoder().decode(CompareResponse.self, from: data)
        }
    }

    func saveProfile(iosUserID: String, profile: TesterProfile) async throws -> ProfileSaveResponse {
        let baseURL = try Self.resolvedBaseURL()
        let endpoint = baseURL.appendingPathComponent("profile")
        return try await Self.withRetry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 20

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]

            let payload = ProfileSaveRequest(
                iosUserId: iosUserID,
                firstName: profile.firstName.isEmpty ? nil : profile.firstName,
                lastName: profile.lastName.isEmpty ? nil : profile.lastName,
                nickname: profile.nickname.isEmpty ? nil : profile.nickname,
                level: profile.level.rawValue,
                weeklyMileageKm: profile.weeklyMileageKm,
                runningDaysPerWeek: profile.runningDaysPerWeek,
                heightCm: profile.heightCm,
                weightKg: profile.weightKg,
                target: profile.target,
                injuryNote: profile.injuryNote.isEmpty ? nil : profile.injuryNote,
                gender: profile.gender.rawValue,
                shoeSize: profile.shoeSize.isEmpty ? nil : profile.shoeSize,
                shoeBrandModel: profile.shoeBrandModel.isEmpty ? nil : profile.shoeBrandModel,
                legLengthCm: profile.legLengthCm,
                dateOfBirth: profile.dateOfBirth.map { dateFormatter.string(from: $0) },
                weeklyExerciseHours: profile.weeklyExerciseHours
            )
            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            return try JSONDecoder().decode(ProfileSaveResponse.self, from: data)
        }
    }

    // MARK: - Private helpers

    private func makeMultipartBody(
        fieldName: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private func stravaEndpoint(path: String, iosUserID: String, baseURL: URL? = nil) throws -> URL {
        let resolvedBaseURL = try baseURL ?? Self.resolvedStravaBaseURL()
        var components = URLComponents(url: resolvedBaseURL.appendingPathComponent("integrations/strava").appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ios_user_id", value: iosUserID)]
        guard let url = components?.url else {
            throw APIError.configuration("Failed to build Strava API URL for path: \(path)")
        }
        return url
    }

    private func stravaBaseURLCandidates() throws -> [URL] {
        var candidates: [URL] = [try Self.resolvedStravaBaseURL()]
        if let productionURL = URL(string: Self.defaultStravaBackendBaseURL) {
            candidates.append(productionURL)
        }
        candidates.append(try Self.resolvedBaseURL())

        var seen = Set<String>()
        return candidates.filter { candidate in
            let key = candidate.absoluteString.lowercased()
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    /// Generic Strava request with backend-URL fallback. Tries each candidate base URL,
    /// returning on the first 2xx and falling through on 404 so callers can degrade across
    /// staging/production. Non-404 errors surface immediately.
    private func requestStrava<T: Decodable>(
        path: String,
        method: String,
        iosUserID: String,
        body: [String: Any]? = nil,
        timeout: TimeInterval = 20,
        notFoundMessage: String,
        exhaustedMessage: String
    ) async throws -> T {
        var lastError: APIError?
        let candidates = try stravaBaseURLCandidates()
        for candidateBaseURL in candidates {
            let endpoint = try stravaEndpoint(path: path, iosUserID: iosUserID, baseURL: candidateBaseURL)
            var request = URLRequest(url: endpoint)
            request.httpMethod = method
            request.timeoutInterval = timeout
            if let body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                continue
            }
            if (200..<300).contains(http.statusCode) {
                return try JSONDecoder().decode(T.self, from: data)
            }
            if http.statusCode != 404 {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            lastError = .server(String(data: data, encoding: .utf8) ?? notFoundMessage)
        }
        throw lastError ?? APIError.server(exhaustedMessage)
    }
}

enum APIError: LocalizedError {
    case server(String)
    case configuration(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .configuration(let message): return message
        }
    }
}

/// Marker protocol for configuration errors that should not be retried.
extension APIError {
    struct ConfigurationError: Error { }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
