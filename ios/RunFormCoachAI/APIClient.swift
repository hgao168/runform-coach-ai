import Foundation

final class APIClient {
    static let shared = APIClient()

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
        let endpoint = stravaEndpoint(path: "connect", iosUserID: iosUserID)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw APIError.server(message)
        }
        return try JSONDecoder().decode(StravaConnectResponse.self, from: data)
    }

    func fetchStravaStatus(iosUserID: String) async throws -> StravaStatusResponse {
        let endpoint = stravaEndpoint(path: "status", iosUserID: iosUserID)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw APIError.server(message)
        }
        return try JSONDecoder().decode(StravaStatusResponse.self, from: data)
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

    private func stravaEndpoint(path: String, iosUserID: String) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("integrations/strava").appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "ios_user_id", value: iosUserID)]
        guard let url = components?.url else {
            fatalError("Failed to build Strava API URL for path: \(path)")
        }
        return url
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
