import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var profile: TesterProfile {
        didSet { saveProfile() }
    }

    @Published private(set) var appUserID: String
    @Published private(set) var accessToken: String?
    @Published private(set) var currentUser: UserResponse?
    @Published private(set) var stravaStatus: StravaStatusResponse?

    @Published private(set) var history: [AnalysisHistoryItem] = []
    @Published private(set) var savedPlans: [SavedPlan] = []
    @Published private(set) var nextWeekPlan: SavedPlan?
    @Published private(set) var manualNextWeekPlan: ManualNextWeekPlan?

    @Published private(set) var challenges: [ChallengeInfo] = []
    @Published private(set) var selectedChallenge: ChallengeInfo?
    @Published private(set) var leaderboard: [ChallengeLeaderboardEntry] = []
    @Published private(set) var isFetchingChallenges = false
    @Published private(set) var isJoiningChallenge = false
    @Published private(set) var challengeError: String?

    
    var latestCoachingIssues: [FormIssueContext] {
        guard let latest = history.first else { return [] }
        return latest.result.issues.map { issue in
            FormIssueContext(
                title: issue.title,
                severity: issue.severity,
                explanation: issue.explanation,
                exerciseNames: issue.recommendedExercises.map(\.name)
            )
        }
    }

    var latestAnalysisSummary: String? {
        history.first?.result.summary
    }

    var latestAnalysisConfidence: Double? {
        history.first?.result.confidence
    }

    private let profileKey = "tester.profile.v1"
    private let appUserIDKey = "app.user.id.v1"
    private let accessTokenKey = "auth.access.token.v1"
    private let currentUserKey = "auth.current.user.v1"
    private let stravaStatusKey = "strava.status.v1"
    private let historyKey = "analysis.history.v1"
    private let savedPlansKey = "saved.plans.v1"
    private let nextWeekPlanKey = "next.week.plan.v1"
    private let manualNextWeekPlanKey = "manual.next.week.plan.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        if let storedAppUserID = UserDefaults.standard.string(forKey: appUserIDKey), !storedAppUserID.isEmpty {
            appUserID = storedAppUserID
        } else {
            let newAppUserID = UUID().uuidString
            appUserID = newAppUserID
            UserDefaults.standard.set(newAppUserID, forKey: appUserIDKey)
        }

        if let data = UserDefaults.standard.data(forKey: profileKey),
           let savedProfile = try? decoder.decode(TesterProfile.self, from: data) {
            profile = savedProfile
        } else {
            profile = TesterProfile()
        }

        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        if let data = UserDefaults.standard.data(forKey: currentUserKey),
           let savedUser = try? decoder.decode(UserResponse.self, from: data) {
            currentUser = savedUser
            alignProfileWithAuthenticatedUser(savedUser)
        } else {
            currentUser = nil
        }

        if let data = UserDefaults.standard.data(forKey: stravaStatusKey),
           let savedStatus = try? decoder.decode(StravaStatusResponse.self, from: data) {
            stravaStatus = savedStatus
        } else {
            stravaStatus = nil
        }

        loadHistory()
        loadSavedPlans()
        loadNextWeekPlan()
        loadManualNextWeekPlan()
    }

    func buildDefaultManualNextWeekPlan(referenceDate: Date = Date()) -> ManualNextWeekPlan {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: startOfToday)
        let untilMonday = (9 - weekday) % 7
        let daysToAdd = untilMonday == 0 ? 7 : untilMonday
        let monday = calendar.date(byAdding: .day, value: daysToAdd, to: startOfToday) ?? startOfToday

        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let days = dayNames.enumerated().map { index, dayName in
            ManualWeekDayPlan(
                date: calendar.date(byAdding: .day, value: index, to: monday) ?? monday,
                dayName: dayName,
                planText: ""
            )
        }

        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        return ManualNextWeekPlan(
            id: UUID(),
            weekStartMonday: monday,
            weekEndSunday: sunday,
            createdAt: Date(),
            updatedAt: Date(),
            days: days
        )
    }

    func saveManualNextWeekPlan(days: [ManualWeekDayPlan]) {
        guard let monday = days.first?.date, let sunday = days.last?.date else { return }

        let now = Date()
        let currentID = manualNextWeekPlan?.id ?? UUID()
        let createdAt = manualNextWeekPlan?.createdAt ?? now

        manualNextWeekPlan = ManualNextWeekPlan(
            id: currentID,
            weekStartMonday: monday,
            weekEndSunday: sunday,
            createdAt: createdAt,
            updatedAt: now,
            days: days
        )
        saveManualNextWeekPlanToStorage()
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

    /// Auto-called after plan generation. Sets nextWeekPlan AND adds to history.
    func setNextWeekPlan(_ plan: TrainingPlanResponse, target: String, weeklyKm: Double) {
        let item = SavedPlan(
            id: UUID(),
            createdAt: Date(),
            target: target,
            weeklyKm: weeklyKm,
            plan: plan
        )
        nextWeekPlan = item
        saveNextWeekPlan()
        // Also insert into saved plans history (deduplicate by replacing same target on same day)
        savedPlans.removeAll {
            $0.target == target &&
            Calendar.current.isDate($0.createdAt, inSameDayAs: item.createdAt)
        }
        savedPlans.insert(item, at: 0)
        saveSavedPlans()
    }

    func deleteSavedPlan(id: UUID) {
        savedPlans.removeAll { $0.id == id }
        saveSavedPlans()
    }

    // MARK: - Workout logging

    func logWorkout(planID: UUID, workoutID: String, status: WorkoutStatus) {
        if nextWeekPlan?.id == planID {
            nextWeekPlan?.workoutLogs[workoutID] = status
            saveNextWeekPlan()
        }
        if let idx = savedPlans.firstIndex(where: { $0.id == planID }) {
            savedPlans[idx].workoutLogs[workoutID] = status
            saveSavedPlans()
        }
    }

    func workoutStatus(planID: UUID, workoutID: String) -> WorkoutStatus? {
        if nextWeekPlan?.id == planID {
            return nextWeekPlan?.workoutLogs[workoutID]
        }
        return savedPlans.first(where: { $0.id == planID })?.workoutLogs[workoutID]
    }

    func clearWorkoutLog(planID: UUID, workoutID: String) {
        if nextWeekPlan?.id == planID {
            nextWeekPlan?.workoutLogs.removeValue(forKey: workoutID)
            saveNextWeekPlan()
        }
        if let idx = savedPlans.firstIndex(where: { $0.id == planID }) {
            savedPlans[idx].workoutLogs.removeValue(forKey: workoutID)
            saveSavedPlans()
        }
    }

    // MARK: - Challenges

    func fetchChallenges() async {
        isFetchingChallenges = true
        challengeError = nil
        do {
            challenges = try await APIClient.shared.fetchChallenges(iosUserID: appUserID)
        } catch {
            challengeError = error.localizedDescription
        }
        isFetchingChallenges = false
    }

    func joinChallenge(challengeID: String) async {
        isJoiningChallenge = true
        challengeError = nil
        do {
            let response = try await APIClient.shared.joinChallenge(challengeID: challengeID, iosUserID: appUserID)
            // Refresh challenge list to pick up joined state
            challenges = try await APIClient.shared.fetchChallenges(iosUserID: appUserID)
            if let updated = challenges.first(where: { $0.id == challengeID }) {
                selectedChallenge = updated
            }
        } catch {
            challengeError = error.localizedDescription
        }
        isJoiningChallenge = false
    }

    func fetchLeaderboard(for challengeID: String) async {
        challengeError = nil
        do {
            leaderboard = try await APIClient.shared.fetchLeaderboard(challengeID: challengeID, iosUserID: appUserID)
        } catch {
            challengeError = error.localizedDescription
        }
    }

    func checkIn(for challengeID: String) async {
        challengeError = nil
        do {
            let response = try await APIClient.shared.checkIn(challengeID: challengeID, userID: appUserID)
            // Refresh challenge list to update completed_days / today_completed
            challenges = try await APIClient.shared.fetchChallenges(iosUserID: appUserID)
            if let updated = challenges.first(where: { $0.id == challengeID }) {
                selectedChallenge = updated
            }
        } catch {
            challengeError = error.localizedDescription
        }
    }

    private func saveProfile() {
        guard let data = try? encoder.encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    func updateStravaStatus(_ status: StravaStatusResponse?) {
        stravaStatus = status
        saveStravaStatus()
    }

    func signIn(_ response: AuthResponse) {
        accessToken = response.accessToken
        currentUser = response.user
        appUserID = response.user.id

        // Keep local profile aligned with the authenticated backend user.
        alignProfileWithAuthenticatedUser(response.user)
        if let backendName = response.user.name?.trimmingCharacters(in: .whitespacesAndNewlines), !backendName.isEmpty {
            let nicknameEmpty = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let firstNameEmpty = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let lastNameEmpty = profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if nicknameEmpty || (firstNameEmpty && lastNameEmpty) {
                profile.nickname = backendName
            }
        }

        UserDefaults.standard.set(response.accessToken, forKey: accessTokenKey)
        UserDefaults.standard.set(response.user.id, forKey: appUserIDKey)
        if let userData = try? encoder.encode(response.user) {
            UserDefaults.standard.set(userData, forKey: currentUserKey)
        }
    }

    private func alignProfileWithAuthenticatedUser(_ user: UserResponse) {
        let authenticatedEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !authenticatedEmail.isEmpty else { return }

        if profile.email != authenticatedEmail {
            profile.email = authenticatedEmail
            saveProfile()
        }
    }

    func signOut() {
        accessToken = nil
        currentUser = nil
        stravaStatus = nil
        let newAppUserID = UUID().uuidString
        appUserID = newAppUserID

        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: currentUserKey)
        UserDefaults.standard.removeObject(forKey: stravaStatusKey)
        UserDefaults.standard.set(newAppUserID, forKey: appUserIDKey)
    }

    private func saveStravaStatus() {
        guard let stravaStatus,
              let data = try? encoder.encode(stravaStatus) else {
            UserDefaults.standard.removeObject(forKey: stravaStatusKey)
            return
        }
        UserDefaults.standard.set(data, forKey: stravaStatusKey)
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

    private func loadNextWeekPlan() {
        guard let data = UserDefaults.standard.data(forKey: nextWeekPlanKey),
              let item = try? decoder.decode(SavedPlan.self, from: data) else {
            nextWeekPlan = nil
            return
        }
        nextWeekPlan = item
    }

    private func saveNextWeekPlan() {
        guard let item = nextWeekPlan,
              let data = try? encoder.encode(item) else { return }
        UserDefaults.standard.set(data, forKey: nextWeekPlanKey)
    }

    private func loadManualNextWeekPlan() {
        guard let data = UserDefaults.standard.data(forKey: manualNextWeekPlanKey),
              let item = try? decoder.decode(ManualNextWeekPlan.self, from: data) else {
            manualNextWeekPlan = nil
            return
        }
        manualNextWeekPlan = item
    }

    private func saveManualNextWeekPlanToStorage() {
        guard let item = manualNextWeekPlan,
              let data = try? encoder.encode(item) else { return }
        UserDefaults.standard.set(data, forKey: manualNextWeekPlanKey)
    }
}
