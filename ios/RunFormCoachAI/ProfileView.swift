import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var level: RunnerLevel = .beginner
    @State private var weeklyMileageKm: Double = 15
    @State private var runningDaysPerWeek: Int = 3
    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var target: TrainingTarget = .generalFitness
    @State private var injuryNote = ""
    @State private var gender: ProfileGender = .unspecified
    @State private var shoeSize = ""
    @State private var legLengthCmText = ""
    @State private var shoeBrandModel = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var weeklyExerciseHours: Double = 5
    @State private var savedMessage: String?
    @State private var stravaMessage: String?
    @State private var isLoadingStravaStatus = false
    @State private var isSyncingStravaRuns = false
    @State private var isConnectingStrava = false
    @State private var lastSyncedAt: Date?
    @State private var stravaAuthSession: ASWebAuthenticationSession?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileHero
                        formCard
                        whyCard
                        ProfileStravaCard(
                            stravaMessage: $stravaMessage,
                            lastSyncedAt: $lastSyncedAt,
                            isLoadingStravaStatus: isLoadingStravaStatus,
                            isSyncingStravaRuns: isSyncingStravaRuns,
                            isConnectingStrava: isConnectingStrava,
                            onConnect: connectStrava,
                            onDisconnect: disconnectStrava,
                            onSync: syncStravaRuns
                        )
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Spacer()
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        fieldFocused = false
                        dismissKeyboard()
                    }
                    .foregroundStyle(AppTheme.mint)
                }
            }
            .onAppear {
                loadDraftFromStore()
            }
            .task {
                await refreshStravaStatus()
            }
        }
    }

    private var profileHero: some View {
        GlassCard {
            HStack(spacing: 15) {
                IconBubble(systemImage: "person.crop.circle.fill", gradient: AppTheme.actionGradient, size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    let displayName: String = {
                        let full = "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))".trimmingCharacters(in: .whitespacesAndNewlines)
                        if !full.isEmpty { return full }
                        let nick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        return nick.isEmpty ? "Runner" : nick
                    }()
                    Text(displayName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("\(level.rawValue) • \(Int(weeklyMileageKm)) km/week")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
            }
        }
    }

    private var formCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle("Runner setup", subtitle: "Used to personalize TestFlight feedback", systemImage: "slider.horizontal.3")

                HStack(spacing: 12) {
                    ProfileLabeledTextField(
                        label: "First name",
                        placeholder: "First name",
                        text: $firstName,
                        focus: $fieldFocused
                    )
                    ProfileLabeledTextField(
                        label: "Last name",
                        placeholder: "Last name",
                        text: $lastName,
                        focus: $fieldFocused
                    )
                }

                ProfileLabeledTextField(
                    label: "Nickname",
                    placeholder: "Nickname",
                    text: $nickname,
                    focus: $fieldFocused
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                        .labelsHidden()
                        .tint(AppTheme.mint)
                        .colorScheme(.dark)
                }

                ProfileMenuPicker(label: "Running level", selection: $level) {
                    ForEach(RunnerLevel.allCases) { level in
                        Text(LocalizedStringKey(level.rawValue)).tag(level)
                    }
                }

                ProfileSliderRow(
                    icon: "speedometer",
                    label: "Weekly mileage",
                    value: $weeklyMileageKm,
                    range: 0...120,
                    step: 1,
                    valueText: "\(Int(weeklyMileageKm)) km"
                )

                Stepper("Running days / week: \(runningDaysPerWeek)", value: $runningDaysPerWeek, in: 1...7)
                    .foregroundStyle(.white)
                    .font(.subheadline)

                ProfileSliderRow(
                    icon: "clock.fill",
                    label: "Total exercise hours / week",
                    value: $weeklyExerciseHours,
                    range: 0...30,
                    step: 0.5,
                    valueText: String(format: "%.1f hrs", weeklyExerciseHours)
                )

                ProfileSliderRow(
                    icon: "ruler",
                    label: "Height",
                    value: $heightCm,
                    range: 130...220,
                    step: 1,
                    valueText: "\(Int(heightCm)) cm"
                )

                ProfileSliderRow(
                    icon: "scalemass",
                    label: "Weight",
                    value: $weightKg,
                    range: 30...200,
                    step: 1,
                    valueText: "\(Int(weightKg)) kg"
                )

                ProfileMenuPicker(label: "Goal", selection: $target) {
                    ForEach(TrainingTarget.allCases) { item in
                        Text(LocalizedStringKey(item.rawValue)).tag(item)
                    }
                }

                ProfileMenuPicker(label: "Gender", selection: $gender) {
                    Text("Male").tag(ProfileGender.male)
                    Text("Female").tag(ProfileGender.female)
                    Text("Other").tag(ProfileGender.other)
                    Text("Prefer not to say").tag(ProfileGender.unspecified)
                }

                HStack(spacing: 12) {
                    ProfileLabeledTextField(
                        label: "Shoe size",
                        placeholder: "EU 42 / US 9",
                        text: $shoeSize,
                        autocapitalization: .never,
                        focus: $fieldFocused
                    )
                    ProfileLabeledTextField(
                        label: "Leg length (cm)",
                        placeholder: "85",
                        text: $legLengthCmText,
                        autocapitalization: .never,
                        keyboardType: .decimalPad,
                        focus: $fieldFocused
                    )
                }

                ProfileLabeledTextField(
                    label: "Shoe brand/model",
                    placeholder: "ASICS Nimbus 27",
                    text: $shoeBrandModel,
                    focus: $fieldFocused
                )

                ProfileLabeledTextField(
                    label: "Injury note",
                    placeholder: "Optional",
                    text: $injuryNote,
                    multiline: true,
                    focus: $fieldFocused
                )

                Button {
                    saveProfile()
                } label: {
                    Label("Save Profile", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())

                if let savedMessage {
                    Text(savedMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mint)
                }
            }
        }
    }

    private var whyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle("Why this matters", subtitle: "Better coaching needs context", systemImage: "lightbulb.fill")
                Text("RunForm stores this locally and uses it to understand tester feedback. Future versions can use it to personalize running plans and strength recommendations.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }


    private func loadDraftFromStore() {
        let profile = appStore.profile
        firstName = profile.firstName
        lastName = profile.lastName
        nickname = profile.nickname
        level = profile.level
        weeklyMileageKm = profile.weeklyMileageKm
        runningDaysPerWeek = profile.runningDaysPerWeek
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        if let targetValue = TrainingTarget(rawValue: profile.target) {
            target = targetValue
        } else {
            target = .generalFitness
        }
        injuryNote = profile.injuryNote
        gender = profile.gender
        shoeSize = profile.shoeSize
        shoeBrandModel = profile.shoeBrandModel
        if let legLength = profile.legLengthCm {
            legLengthCmText = String(format: "%.1f", legLength)
        } else {
            legLengthCmText = ""
        }
        dateOfBirth = profile.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        weeklyExerciseHours = profile.weeklyExerciseHours
    }

    @MainActor
    private func refreshStravaStatus() async {
        isLoadingStravaStatus = true
        defer { isLoadingStravaStatus = false }

        do {
            let status = try await APIClient.shared.fetchStravaStatus(iosUserID: appStore.appUserID)
            appStore.updateStravaStatus(status)
            stravaMessage = status.connected ? "Strava connection synced." : nil
        } catch {
            if appStore.stravaStatus == nil {
                stravaMessage = nil
            }
        }
    }

    private func connectStrava() {
        guard !isConnectingStrava else { return }
        isConnectingStrava = true
        stravaMessage = nil

        Task {
            do {
                let response = try await APIClient.shared.fetchStravaConnectResponse(iosUserID: appStore.appUserID)
                await MainActor.run {
                    startStravaSession(authorizeURL: response.authorizeURL)
                }
            } catch {
                await MainActor.run {
                    isConnectingStrava = false
                    if let apiError = error as? APIError,
                       let message = apiError.errorDescription,
                       !message.isEmpty {
                        stravaMessage = "Strava sign-in failed: \(message)"
                    } else {
                        stravaMessage = "Unable to start Strava sign-in: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func disconnectStrava() {
        guard !isConnectingStrava else { return }
        isConnectingStrava = true
        stravaMessage = nil

        Task {
            do {
                let response = try await APIClient.shared.disconnectStrava(iosUserID: appStore.appUserID)
                await MainActor.run {
                    appStore.updateStravaStatus(nil)
                    isConnectingStrava = false
                    stravaMessage = response.message
                }
            } catch {
                await MainActor.run {
                    isConnectingStrava = false
                    if let apiError = error as? APIError,
                       let message = apiError.errorDescription,
                       !message.isEmpty {
                        stravaMessage = "Strava disconnect failed: \(message)"
                    } else {
                        stravaMessage = "Unable to disconnect Strava: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func syncStravaRuns() {
        guard !isSyncingStravaRuns else { return }
        isSyncingStravaRuns = true
        stravaMessage = nil

        Task {
            do {
                let result = try await APIClient.shared.syncStravaActivities(iosUserID: appStore.appUserID)
                await MainActor.run {
                    isSyncingStravaRuns = false
                    lastSyncedAt = Date()
                    let weekLabel = result.weekCount == 1 ? "week" : "weeks"
                    var message = "Synced \(result.syncedRunCount) runs across \(result.weekCount) \(weekLabel)."
                    if let prefill = result.prefilledProfile, !prefill.isEmpty {
                        applyStravaPrefill(prefill)
                        message += " Pre-filled profile: \(prefill.summaryLabel)."
                    }
                    stravaMessage = message
                }
            } catch {
                await MainActor.run {
                    isSyncingStravaRuns = false
                    if let apiError = error as? APIError,
                       let message = apiError.errorDescription,
                       !message.isEmpty {
                        stravaMessage = "Strava sync failed: \(message)"
                    } else {
                        stravaMessage = "Unable to sync Strava runs: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    @MainActor
    private func startStravaSession(authorizeURL: URL) {
        let session = ASWebAuthenticationSession(
            url: authorizeURL,
            callbackURLScheme: "runformcoachai"
        ) { callbackURL, error in
            Task { @MainActor in
                self.isConnectingStrava = false
                self.stravaAuthSession = nil

                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    self.stravaMessage = "Strava connection canceled."
                    return
                }

                if let error {
                    self.stravaMessage = error.localizedDescription
                    return
                }

                guard let callbackURL else {
                    self.stravaMessage = "Strava connection finished without a callback."
                    return
                }

                let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                let queryItems = components?.queryItems ?? []
                let status = queryItems.first(where: { $0.name == "status" })?.value
                let athleteID = queryItems.first(where: { $0.name == "provider_athlete_id" })?.value

                if status == "connected" {
                    if let athleteID {
                        self.stravaMessage = "Strava connected for athlete \(athleteID)."
                    } else {
                        self.stravaMessage = "Strava connected."
                    }
                    await self.refreshStravaStatus()
                } else {
                    self.stravaMessage = "Strava flow completed."
                }
            }
        }
        session.presentationContextProvider = StravaPresentationContextProvider.shared
        session.prefersEphemeralWebBrowserSession = true
        stravaAuthSession = session

        if !session.start() {
            isConnectingStrava = false
            stravaMessage = "Unable to start Strava sign-in. Please close and reopen the Profile page, then try again."
            stravaAuthSession = nil
        }
    }

    private func saveProfile() {
        fieldFocused = false
        dismissKeyboard()
        let profile = TesterProfile(
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            level: level,
            weeklyMileageKm: weeklyMileageKm,
            runningDaysPerWeek: runningDaysPerWeek,
            heightCm: heightCm,
            weightKg: weightKg,
            target: target.rawValue,
            injuryNote: injuryNote,
            dateOfBirth: dateOfBirth,
            weeklyExerciseHours: weeklyExerciseHours,
            gender: gender,
            shoeSize: shoeSize,
            legLengthCm: Double(legLengthCmText.replacingOccurrences(of: ",", with: ".")),
            shoeBrandModel: shoeBrandModel
        )
        appStore.profile = profile
        savedMessage = String(localized: "profile.saved")

        Task {
            _ = try? await APIClient.shared.saveProfile(iosUserID: appStore.appUserID, profile: profile)
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    /// Merge Strava `/athlete` pre-fill values into the local form. Only fills
    /// fields that the user hasn't already filled in (server-side keeps the
    /// same invariant). Also persists the merged profile so it survives reload.
    @MainActor
    private func applyStravaPrefill(_ prefill: StravaProfilePrefill) {
        if let firstName = prefill.firstName, !firstName.isEmpty,
           self.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.firstName = firstName
        }
        if let lastName = prefill.lastName, !lastName.isEmpty,
           self.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.lastName = lastName
        }
        if let gender = prefill.gender, !gender.isEmpty,
           self.gender == .unspecified,
           let parsed = ProfileGender(rawValue: gender) {
            self.gender = parsed
        }
        if let weight = prefill.weightKg, weight > 0,
           // Only overwrite the seed default (70). Any user-edited value is preserved.
           abs(self.weightKg - 70) < 0.001 {
            self.weightKg = weight
        }
        // Persist silently (no focus/keyboard side effects, no "saved" toast).
        let profile = TesterProfile(
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            level: level,
            weeklyMileageKm: weeklyMileageKm,
            runningDaysPerWeek: runningDaysPerWeek,
            heightCm: heightCm,
            weightKg: weightKg,
            target: target.rawValue,
            injuryNote: injuryNote,
            dateOfBirth: dateOfBirth,
            weeklyExerciseHours: weeklyExerciseHours,
            gender: gender,
            shoeSize: shoeSize,
            legLengthCm: Double(legLengthCmText.replacingOccurrences(of: ",", with: ".")),
            shoeBrandModel: shoeBrandModel
        )
        appStore.profile = profile
    }
}
