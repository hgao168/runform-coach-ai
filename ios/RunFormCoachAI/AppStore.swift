import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var profile: TesterProfile {
        didSet { saveProfile() }
    }

    @Published private(set) var history: [AnalysisHistoryItem] = []
    @Published private(set) var savedPlans: [SavedPlan] = []

    private let profileKey = "tester.profile.v1"
    private let historyKey = "analysis.history.v1"
    private let savedPlansKey = "saved.plans.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: profileKey),
           let savedProfile = try? decoder.decode(TesterProfile.self, from: data) {
            profile = savedProfile
        } else {
            profile = TesterProfile()
        }

        loadHistory()
        loadSavedPlans()
    }

    func addHistory(result: AnalysisResponse, videoURL: URL?) {
        let item = AnalysisHistoryItem(
            id: UUID(),
            createdAt: Date(),
            videoFilename: videoURL?.lastPathComponent ?? "running-video.mov",
            result: result,
            feedback: nil
        )
        history.insert(item, at: 0)
        saveHistory()
    }

    func updateFeedback(for itemID: UUID, feedback: AnalysisFeedback) {
        guard let index = history.firstIndex(where: { $0.id == itemID }) else { return }
        history[index].feedback = feedback
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func savePlan(_ plan: TrainingPlanResponse, target: String, weeklyKm: Double) {
        let item = SavedPlan(
            id: UUID(),
            createdAt: Date(),
            target: target,
            weeklyKm: weeklyKm,
            plan: plan
        )
        savedPlans.insert(item, at: 0)
        saveSavedPlans()
    }

    func deleteSavedPlan(id: UUID) {
        savedPlans.removeAll { $0.id == id }
        saveSavedPlans()
    }

    private func saveProfile() {
        guard let data = try? encoder.encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let savedHistory = try? decoder.decode([AnalysisHistoryItem].self, from: data) else {
            history = []
            return
        }
        history = savedHistory.sorted { $0.createdAt > $1.createdAt }
    }

    private func saveHistory() {
        guard let data = try? encoder.encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func loadSavedPlans() {
        guard let data = UserDefaults.standard.data(forKey: savedPlansKey),
              let plans = try? decoder.decode([SavedPlan].self, from: data) else {
            savedPlans = []
            return
        }
        savedPlans = plans.sorted { $0.createdAt > $1.createdAt }
    }

    private func saveSavedPlans() {
        guard let data = try? encoder.encode(savedPlans) else { return }
        UserDefaults.standard.set(data, forKey: savedPlansKey)
    }
}
