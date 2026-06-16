import SwiftUI
import AuthenticationServices
import GoogleSignIn

#if canImport(UIKit)
import UIKit
#endif

private enum AuthMode: String, CaseIterable, Identifiable {
    case login = "Login"
    case register = "Register"
    var id: String { rawValue }
}

struct ProfileView: View {
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
    @State private var authMode: AuthMode = .login
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var authName = ""
    @State private var authMessage: String?
    @State private var isAuthBusy = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileHero
                        formCard
                        authCard
                        whyCard
                        if appStore.currentUser != nil {
                            stravaCard
                        } else {
                            stravaLoginRequiredCard
                        }
                    }
                    .padding(18)
                }
                .scrollDismissesKeyboard(.immediately)
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

                ProfileLabeledTextField(
                    label: "Email",
                    placeholder: "you@example.com",
                    text: $email,
                    autocapitalization: .never,
                    keyboardType: .emailAddress,
                    focus: $fieldFocused
                )
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

    private var stravaLoginRequiredCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(
                    LocalizedStringKey("strava.card.title"),
                    subtitle: LocalizedStringKey("strava.card.subtitle"),
                    systemImage: "link.circle.fill"
                )
                Text(String(localized: "strava.auth_required"))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    private var authCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    LocalizedStringKey("auth.card.title"),
                    subtitle: LocalizedStringKey("auth.card.subtitle"),
                    systemImage: "person.badge.key"
                )

                if let currentUser = appStore.currentUser {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: String(localized: "auth.signed_in_as %@"), currentUser.email))
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
                        Label(String(localized: "auth.sign_off"), systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle())
                } else {
                    Picker("", selection: $authMode) {
                        ForEach(AuthMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if authMode == .register {
                        ProfileLabeledTextField(
                            label: LocalizedStringKey("Nickname"),
                            placeholder: LocalizedStringKey("Nickname"),
                            text: $authName,
                            focus: $fieldFocused
                        )
                    }

                    ProfileLabeledTextField(
                        label: LocalizedStringKey("Email"),
                        placeholder: "you@example.com",
                        text: $authEmail,
                        autocapitalization: .never,
                        keyboardType: .emailAddress,
                        focus: $fieldFocused
                    )

                    ProfileLabeledTextField(
                        label: LocalizedStringKey("auth.password"),
                        placeholder: "********",
                        text: $authPassword,
                        autocapitalization: .never,
                        focus: $fieldFocused
                    )

                    Button {
                        runformAuth()
                    } label: {
                        Label(
                            authMode == .login
                                ? String(localized: "auth.runform_login")
                                : String(localized: "auth.runform_register"),
                            systemImage: "person.crop.circle.badge.checkmark"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle(disabled: isAuthBusy))
                    .disabled(isAuthBusy)

                    Button {
                        googleSignIn()
                    } label: {
                        Label(
                            isAuthBusy
                                ? String(localized: "auth.google.signing_in")
                                : String(localized: "auth.google.sign_in"),
                            systemImage: "g.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle(disabled: isAuthBusy))
                    .disabled(isAuthBusy)
                }

                if let authMessage {
                    Text(authMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
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
    }

    private func saveProfile() {
        fieldFocused = false
        dismissKeyboard()

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
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

        Task {
            do {
                _ = try await APIClient.shared.saveProfile(iosUserID: appStore.appUserID, profile: profile)
            } catch {
                await MainActor.run {
                    savedMessage = String(format: String(localized: "profile.save.failed %@"), error.localizedDescription)
                }
            }
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Za-z]{2,}$"
        return value.range(of: pattern, options: .regularExpression) != nil
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
                let payload = try await APIClient.shared.fetchStravaConnectResponse(iosUserID: appStore.appUserID)
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
        defer { stravaAuthSession = nil }

        if let error {
            if let authError = error as? ASWebAuthenticationSessionError,
               authError.code == .canceledLogin {
                stravaMessage = String(localized: "strava.status.cancelled")
            } else {
                stravaMessage = String(format: String(localized: "strava.error.signin %@"), error.localizedDescription)
            }
            return
        }

        guard let callbackURL else {
            stravaMessage = String(localized: "strava.error.callback_missing")
            return
        }

        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let status = components?.queryItems?.first(where: { $0.name == "status" })?.value
        let oauthError = components?.queryItems?.first(where: { $0.name == "error" })?.value

        if let oauthError, !oauthError.isEmpty {
            stravaMessage = String(format: String(localized: "strava.error.oauth %@"), oauthError)
            return
        }

        if status == "connected" {
            stravaMessage = String(localized: "strava.status.connected")
            refreshStravaStatus()
        } else {
            // Some backends may not include status; still attempt a status refresh.
            refreshStravaStatus()
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
                stravaMessage = String(format: String(localized: "strava.sync.success %lld"), response.syncedRunCount)
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
            guard let schemes = entry["CFBundleURLSchemes"] as? [String] else { continue }
            if let scheme = schemes.first, !scheme.isEmpty {
                return scheme
            }
        }
        return nil
    }

    private func signOff() {
        appStore.signOut()
        appStore.updateStravaStatus(nil)
        stravaMessage = nil
        authMessage = String(localized: "auth.signed_off")
    }

    private func runformAuth() {
        let normalizedEmail = authEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            authMessage = String(localized: "profile.email.required")
            return
        }
        guard isValidEmail(normalizedEmail) else {
            authMessage = String(localized: "profile.email.invalid")
            return
        }
        guard !authPassword.isEmpty else {
            authMessage = String(localized: "auth.password.required")
            return
        }

        isAuthBusy = true
        authMessage = nil

        Task {
            do {
                let response: AuthResponse
                if authMode == .login {
                    response = try await APIClient.shared.login(email: normalizedEmail, password: authPassword)
                } else {
                    response = try await APIClient.shared.register(
                        email: normalizedEmail,
                        password: authPassword,
                        name: authName.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                await MainActor.run {
                    appStore.signIn(response)
                    email = response.user.email
                    authMessage = String(localized: "auth.login.success")
                    isAuthBusy = false
                    refreshStravaStatus()
                }
            } catch {
                await MainActor.run {
                    authMessage = String(format: String(localized: "auth.login.failed %@"), error.localizedDescription)
                    isAuthBusy = false
                }
            }
        }
    }

    private func googleSignIn() {
        guard let presentingVC = activeViewController() else {
            authMessage = String(localized: "auth.google.no_presenter")
            return
        }

        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_IOS_CLIENT_ID") as? String,
              !clientID.isEmpty,
              !clientID.contains("$(") else {
            authMessage = String(localized: "auth.google.client_id_missing")
            return
        }

        isAuthBusy = true
        authMessage = nil

        let configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.configuration = configuration
        Task {
            do {
                let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
                let accessToken = signInResult.user.accessToken.tokenString
                if accessToken.isEmpty {
                    authMessage = String(localized: "auth.google.missing_token")
                    isAuthBusy = false
                    return
                }

                let response = try await APIClient.shared.googleAuth(accessToken: accessToken)
                appStore.signIn(response)
                email = response.user.email
                authMessage = String(localized: "auth.login.success")
                isAuthBusy = false
                refreshStravaStatus()
            } catch {
                authMessage = String(format: String(localized: "auth.login.failed %@"), error.localizedDescription)
                isAuthBusy = false
            }
        }
    }

    private func activeViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }

        var current: UIViewController = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

}
