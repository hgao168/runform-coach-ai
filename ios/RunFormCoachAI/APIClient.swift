import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL = {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }()

    func analyzeVideo(fileURL: URL) async throws -> AnalysisResponse {
        let endpoint = baseURL.appendingPathComponent("analyze")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let videoData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent.isEmpty ? "running-video.mov" : fileURL.lastPathComponent
        request.httpBody = makeMultipartBody(
            fieldName: "video",
            filename: filename,
            mimeType: "video/quicktime",
            data: videoData,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AnalysisResponse.self, from: data)
    }

    func generateTrainingPlan(input: TrainingPlanInput) async throws -> TrainingPlanResponse {
        let endpoint = baseURL.appendingPathComponent("training-plan")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(input)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TrainingPlanResponse.self, from: data)
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
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
