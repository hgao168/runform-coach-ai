import Foundation

final class APIClient {
    static let shared = APIClient()
    private static let defaultStravaBackendBaseURL = "https://runform-coach-ai-production.up.railway.app"

    private let baseURL: URL = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
            !urlString.isEmpty,
            let url = URL(string: urlString)
        else {
            // BACKEND_BASE_URL must be set via project.yml configs (Debug/Release).
            fatalError("BACKEND_BASE_URL is not configured. Check project.yml build settings.")
        }
        return url
    }()

    private let stravaBaseURL: URL = {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "STRAVA_BACKEND_BASE_URL") as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return url
        }

        if let defaultURL = URL(string: APIClient.defaultStravaBackendBaseURL) {
            return defaultURL
        }

        guard
            let fallback = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
            !fallback.isEmpty,
            let fallbackURL = URL(string: fallback)
        else {
            fatalError("BACKEND_BASE_URL is not configured. Check project.yml build settings.")
        }
        return fallbackURL
    }()

    func analyzeMetrics(_ metrics: PoseMetrics) async throws -> AnalysisResponse {
        let endpoint = baseURL.appendingPathComponent("analyze-metrics")
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

    func fetchStravaConnectResponse(iosUserID: String) async throws -> StravaConnectResponse {
        var lastError: APIError?
        for candidateBaseURL in stravaBaseURLCandidates() {
            let endpoint = stravaEndpoint(path: "connect", iosUserID: iosUserID, baseURL: candidateBaseURL)
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                continue
            }
            if (200..<300).contains(http.statusCode) {
                return try JSONDecoder().decode(StravaConnectResponse.self, from: data)
            }
            if http.statusCode != 404 {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            lastError = .server(String(data: data, encoding: .utf8) ?? "Strava connect route not found")
        }
        throw lastError ?? APIError.server("Unable to load Strava connect URL from available backends.")
    }

    func fetchStravaStatus(iosUserID: String) async throws -> StravaStatusResponse {
        var lastError: APIError?
        for candidateBaseURL in stravaBaseURLCandidates() {
            let endpoint = stravaEndpoint(path: "status", iosUserID: iosUserID, baseURL: candidateBaseURL)
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                continue
            }
            if (200..<300).contains(http.statusCode) {
                return try JSONDecoder().decode(StravaStatusResponse.self, from: data)
            }
            if http.statusCode != 404 {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            lastError = .server(String(data: data, encoding: .utf8) ?? "Strava status route not found")
        }
        throw lastError ?? APIError.server("Unable to load Strava status from available backends.")
    }

    func disconnectStrava(iosUserID: String) async throws -> StravaDisconnectResponse {
        var lastError: APIError?
        for candidateBaseURL in stravaBaseURLCandidates() {
            let endpoint = stravaEndpoint(path: "disconnect", iosUserID: iosUserID, baseURL: candidateBaseURL)
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20

            let payload = ["ios_user_id": iosUserID]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                continue
            }
            if (200..<300).contains(http.statusCode) {
                return try JSONDecoder().decode(StravaDisconnectResponse.self, from: data)
            }
            if http.statusCode != 404 {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            lastError = .server(String(data: data, encoding: .utf8) ?? "Strava disconnect route not found")
        }
        throw lastError ?? APIError.server("Unable to disconnect Strava from available backends.")
    }

    func syncStravaActivities(iosUserID: String) async throws -> StravaSyncResponse {
        var lastError: APIError?
        for candidateBaseURL in stravaBaseURLCandidates() {
            let endpoint = stravaEndpoint(path: "sync", iosUserID: iosUserID, baseURL: candidateBaseURL)
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 30

            let payload = ["ios_user_id": iosUserID]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                continue
            }
            if (200..<300).contains(http.statusCode) {
                return try JSONDecoder().decode(StravaSyncResponse.self, from: data)
            }
            if http.statusCode != 404 {
                let message = String(data: data, encoding: .utf8) ?? "Bad server response"
                throw APIError.server(message)
            }
            lastError = .server(String(data: data, encoding: .utf8) ?? "Strava sync route not found")
        }
        throw lastError ?? APIError.server("Unable to sync Strava activities from available backends.")
    }

    func fetchStravaSummary(iosUserID: String, weeks: Int = 4) async throws -> StravaSummaryResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("integrations/strava/summary"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "ios_user_id", value: iosUserID),
            URLQueryItem(name: "weeks", value: String(weeks))
        ]
        guard let endpoint = components?.url else {
            fatalError("Failed to build Strava summary URL.")
        }

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

    // Backward-compatible fallback only. Prefer analyzeMetrics(_:), because it sends numeric pose metrics instead of the raw video.
    func analyzeVideo(fileURL: URL) async throws -> AnalysisResponse {
        let endpoint = baseURL.appendingPathComponent("analyze")
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

    private func stravaEndpoint(path: String, iosUserID: String, baseURL: URL? = nil) -> URL {
        let resolvedBaseURL = baseURL ?? stravaBaseURL
        var components = URLComponents(url: resolvedBaseURL.appendingPathComponent("integrations/strava").appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ios_user_id", value: iosUserID)]
        guard let url = components?.url else {
            fatalError("Failed to build Strava API URL for path: \(path)")
        }
        return url
    }

    private func stravaBaseURLCandidates() -> [URL] {
        var candidates: [URL] = [stravaBaseURL]
        if let productionURL = URL(string: APIClient.defaultStravaBackendBaseURL) {
            candidates.append(productionURL)
        }
        candidates.append(baseURL)

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

    func generateTrainingPlan(input: TrainingPlanInput) async throws -> TrainingPlanResponse {
        let endpoint = baseURL.appendingPathComponent("training-plan")
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

    func fetchAthletes() async throws -> [AthleteListItem] {
        let endpoint = baseURL.appendingPathComponent("athletes")
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

    func compareWithAthlete(athleteId: String, metrics: PoseMetrics) async throws -> CompareResponse {
        let endpoint = baseURL.appendingPathComponent("compare")
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

    func saveProfile(iosUserID: String, profile: TesterProfile) async throws -> ProfileSaveResponse {
        let endpoint = baseURL.appendingPathComponent("profile")
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

enum APIError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
