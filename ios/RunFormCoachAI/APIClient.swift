import Foundation

final class APIClient {
    static let shared = APIClient()

    // For simulator use 127.0.0.1. For physical iPhone use your computer LAN IP.
    private let baseURL = URL(string: "http://127.0.0.1:8000")!

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
