import Foundation

struct AnalysisResponse: Codable {
    let summary: String
    let confidence: Double
    let metrics: [Metric]
    let issues: [Issue]
}

struct Metric: Codable, Identifiable {
    var id: String { name }
    let name: String
    let score: Double
    let status: String
    let explanation: String
}

struct Issue: Codable, Identifiable {
    var id: String { title }
    let title: String
    let severity: String
    let explanation: String
    let recommendedExercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case title
        case severity
        case explanation
        case recommendedExercises = "recommended_exercises"
    }
}

struct Exercise: Codable, Identifiable {
    var id: String { name }
    let name: String
    let category: String
    let sets: Int
    let reps: String
    let frequencyPerWeek: Int
    let reason: String

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case sets
        case reps
        case frequencyPerWeek = "frequency_per_week"
        case reason
    }
}
