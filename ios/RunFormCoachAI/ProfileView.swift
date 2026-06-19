import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    private static let stravaCallbackScheme = "runformcoachai"
    private static let stravaCallbackURL = "runformcoachai://strava/callback"

    @EnvironmentObject private var appStore: AppStore
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var email = ""
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
    @State private var emailError: String?
    @State private var stravaMessage: String?
    @State private var lastSyncedAt: Date?
    @State private var isLoadingStravaStatus = false
    @State private var isSyncingStravaRuns = false
    @State private var isConnectingStrava = false
    @State private var stravaAuthSession: ASWebAuthenticationSession?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if appStore.currentUser == nil {
                    LoginView(
                        initialEmail: email,
                        onLoginSuccess: nil,
                        showsCloseButton: false,
                        wrapsInNavigation: false,
                        dismissOnSuccess: false
                    )
                    .environmentObject(appStore)
                } else {
                    ZStack {
                        AppBackground()
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                profileHero
                                formCard
                                authCard
                                whyCard
                                stravaCard
                            }
                            .padding(18)
                        }
                        .scrollDismissesKeyboard(.immediately)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
                if appStore.currentUser != nil {
                    refreshStravaStatus()
                }
            }
            .onChange(of: appStore.currentUser) { currentUser in
                loadDraftFromStore()
                if currentUser != nil {
                    refreshStravaStatus()
                }
            }
        }
    }

    private var profileHero: some View {
        GlassCard {
            HStack(spacing: 15) {
                IconBubble(systemImage: "person.crop.circle.fill", gradient: AppTheme.actionGradient, size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    let displayName: String = {
                        if let currentUser = appStore.currentUser,
                           let dbName = currentUser.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !dbName.isEmpty {
                            return dbName
                        }
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

                ProfileLabeledTextField(
                    label: "Email",
                    placeholder: "you@example.com",
                    text: $email,
                    autocapitalization: .never,
                    keyboardType: .emailAddress,
                    focus: $fieldFocused
                )
                .disabled(appStore.currentUser != nil)
                .opacity(appStore.currentUser != nil ? 0.7 : 1)
                .onChange(of: email) { _ in
                    emailError = nil
                }
                if let emailError {
                    Text(emailError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

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

    private var stravaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    LocalizedStringKey("strava.card.title"),
                    subtitle: LocalizedStringKey("strava.card.subtitle"),
                    systemImage: "link.circle.fill"
                )
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.mint.opacity(0.6))
                        Text("Coming Soon")
                            .font(.headline)
                            .foregroundStyle(AppTheme.mint)
                        Text("Strava integration is being upgraded.\nCheck back shortly!")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
    }
//    private var stravaCard: some View {
//        ProfileStravaCard(
//            stravaMessage: $stravaMessage,
//            lastSyncedAt: $lastSyncedAt,
//            isLoadingStravaStatus: isLoadingStravaStatus,
//            isSyncingStravaRuns: isSyncingStravaRuns,
//            isConnectingStrava: isConnectingStrava,
//            onConnect: connectStrava,
//            onDisconnect: disconnectStrava,
//            onSync: syncStravaRuns
//        )
//    }

    private var authCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    "Account",
                    subtitle: "Use login to sync your profile to backend",
                    systemImage: "person.badge.key"
                )

                if let currentUser = appStore.currentUser {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Logged in as \(currentUser.email)")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.82))
                        if let name = currentUser.name, !name.isEmpty {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    Button(role: .destructive) {
                        signOff()
                    } label: {
                        Label("Sign Off", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle())
                } else {
                    Text("You are not logged in. Tap Save Profile to continue to login and sync this profile.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
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
        email = profile.email
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

        if let currentUser = appStore.currentUser {
            let normalizedAuthEmail = currentUser.email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedAuthEmail.isEmpty {
                email = normalizedAuthEmail
            }
            let dbName = currentUser.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !dbName.isEmpty,
               firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nickname = dbName
            }
        }
    }

    private func saveProfile() {
        fieldFocused = false
        dismissKeyboard()

        var normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if let authenticatedEmail = appStore.currentUser?.email.trimmingCharacters(in: .whitespacesAndNewlines),
           !authenticatedEmail.isEmpty {
            normalizedEmail = authenticatedEmail
        }
        if normalizedEmail.isEmpty {
            emailError = String(localized: "profile.email.required")
            savedMessage = nil
            return
        }
        if !isValidEmail(normalizedEmail) {
            emailError = String(localized: "profile.email.invalid")
            savedMessage = nil
            return
        }
        emailError = nil
        email = normalizedEmail

        let profile = TesterProfile(
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            email: normalizedEmail,
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

        syncProfileToBackend(profile)
    }

    private func syncProfileToBackend(_ profile: TesterProfile) {
        Task {
            do {
                _ = try await APIClient.shared.saveProfile(iosUserID: appStore.appUserID, profile: profile)
                await MainActor.run {
                    savedMessage = "Profile synced successfully."
                }
            } catch {
                await MainActor.run {
                    savedMessage = String(format: String(localized: "profile.save.failed %@"), error.localizedDescription)
                }
            }
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else {
            return false
        }

        // NSDataDetector handles many valid RFC-compliant address forms
        // better than a restrictive regex and avoids false negatives.
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, options: [], range: range) else {
            return false
        }
        return match.range == range && match.url?.scheme == "mailto"
    }

    private func refreshStravaStatus() {
        guard appStore.currentUser != nil else {
            appStore.updateStravaStatus(nil)
            return
        }
        Task {
            isLoadingStravaStatus = true
            defer { isLoadingStravaStatus = false }

            do {
                let status = try await APIClient.shared.fetchStravaStatus(iosUserID: appStore.appUserID)
                appStore.updateStravaStatus(status)
                if status.connected {
                    stravaMessage = String(localized: "strava.status.connected")
                }
            } catch {
                stravaMessage = String(format: String(localized: "strava.error.status %@"), error.localizedDescription)
            }
        }
    }

    private func connectStrava() {
        guard appStore.currentUser != nil else {
            stravaMessage = String(localized: "strava.auth_required")
            return
        }
        Task {
            isConnectingStrava = true
            defer { isConnectingStrava = false }

            do {
                let payload = try await APIClient.shared.fetchStravaConnectResponse(
                    iosUserID: appStore.appUserID,
                    appCallbackURL: Self.stravaCallbackURL
                )
                let callbackScheme = stravaCallbackURLScheme()

                let session = ASWebAuthenticationSession(
                    url: payload.authorizeURL,
                    callbackURLScheme: callbackScheme
                ) { callbackURL, error in
                    Task { @MainActor in
                        handleStravaAuthCallback(callbackURL: callbackURL, error: error)
                    }
                }
                session.presentationContextProvider = StravaPresentationContextProvider.shared
                session.prefersEphemeralWebBrowserSession = false

                stravaAuthSession = session
                if !session.start() {
                    stravaMessage = String(localized: "strava.error.start")
                    stravaAuthSession = nil
                }
            } catch {
                stravaMessage = String(format: String(localized: "strava.error.open %@"), error.localizedDescription)
            }
        }
    }

    private func handleStravaAuthCallback(callbackURL: URL?, error: Error?) {
        // Always dismiss the Strava authorize popup once the session ends, even
        // if the in-app browser showed an "address is invalid" page.
        stravaAuthSession?.cancel()
        stravaAuthSession = nil

        // The web view can surface a confusing error or be dismissed by the user
        // even after Strava has already authorized and the backend stored the
        // connection. Instead of trusting the browser's result, verify the real
        // connection state with the backend and only report a failure when the
        // account is genuinely not connected.
        if let error {
            if let authError = error as? ASWebAuthenticationSessionError,
               authError.code == .canceledLogin {
                verifyStravaConnection(fallbackMessage: String(localized: "strava.status.cancelled"))
            } else {
                verifyStravaConnection(
                    fallbackMessage: String(format: String(localized: "strava.error.signin %@"), error.localizedDescription)
                )
            }
            return
        }

        let components = callbackURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let oauthError = components?.queryItems?.first(where: { $0.name == "error" })?.value

        if let oauthError, !oauthError.isEmpty {
            verifyStravaConnection(
                fallbackMessage: String(format: String(localized: "strava.error.oauth %@"), oauthError)
            )
            return
        }

        verifyStravaConnection(fallbackMessage: String(localized: "strava.status.connected"))
    }

    /// Re-checks the real Strava connection state with the backend. Shows a
    /// success message when connected; otherwise falls back to `fallbackMessage`.
    private func verifyStravaConnection(fallbackMessage: String) {
        guard appStore.currentUser != nil else {
            stravaMessage = fallbackMessage
            return
        }
        Task {
            isLoadingStravaStatus = true
            defer { isLoadingStravaStatus = false }

            do {
                let status = try await APIClient.shared.fetchStravaStatus(iosUserID: appStore.appUserID)
                appStore.updateStravaStatus(status)
                stravaMessage = status.connected
                    ? String(localized: "strava.status.connected")
                    : fallbackMessage
            } catch {
                stravaMessage = fallbackMessage
            }
        }
    }

    private func disconnectStrava() {
        guard appStore.currentUser != nil else {
            stravaMessage = String(localized: "strava.auth_required")
            return
        }
        Task {
            isLoadingStravaStatus = true
            defer { isLoadingStravaStatus = false }

            do {
                let response = try await APIClient.shared.disconnectStrava(iosUserID: appStore.appUserID)
                appStore.updateStravaStatus(nil)
                stravaMessage = response.message
            } catch {
                stravaMessage = String(format: String(localized: "strava.error.disconnect %@"), error.localizedDescription)
            }
        }
    }

    private func syncStravaRuns() {
        guard appStore.currentUser != nil else {
            stravaMessage = String(localized: "strava.auth_required")
            return
        }
        Task {
            isSyncingStravaRuns = true
            defer { isSyncingStravaRuns = false }

            do {
                let response = try await APIClient.shared.syncStravaActivities(iosUserID: appStore.appUserID)
                lastSyncedAt = Date()
                stravaMessage = String(
                    format: String(localized: "strava.sync.success %lld %lld"),
                    response.syncedRunCount,
                    response.weekCount
                )
                applyStravaPrefill(response.prefilledProfile)
                refreshStravaStatus()
            } catch {
                stravaMessage = String(format: String(localized: "strava.error.sync %@"), error.localizedDescription)
            }
        }
    }

    private func applyStravaPrefill(_ prefill: StravaProfilePrefill?) {
        guard let prefill else { return }
        if let firstName = prefill.firstName, !firstName.isEmpty {
            self.firstName = firstName
        }
        if let lastName = prefill.lastName, !lastName.isEmpty {
            self.lastName = lastName
        }
        if let gender = prefill.gender {
            self.gender = ProfileGender(rawValue: gender) ?? self.gender
        }
        if let weightKg = prefill.weightKg, weightKg > 0 {
            self.weightKg = weightKg
        }
        saveProfile()
    }

    private func stravaCallbackURLScheme() -> String? {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }
        for entry in urlTypes {
            let urlName = entry["CFBundleURLName"] as? String
            guard let schemes = entry["CFBundleURLSchemes"] as? [String] else { continue }
            if urlName == "runformcoachai.strava.callback",
               schemes.contains(Self.stravaCallbackScheme) {
                return Self.stravaCallbackScheme
            }
        }
        return Self.stravaCallbackScheme
    }

    private func signOff() {
        appStore.signOut()
        appStore.updateStravaStatus(nil)
        stravaMessage = nil
        savedMessage = "Signed out"
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

}
