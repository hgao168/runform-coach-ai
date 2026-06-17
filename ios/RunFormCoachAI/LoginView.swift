import SwiftUI

private enum LoginAuthMode: String, CaseIterable, Identifiable {
    case login = "Login"
    case register = "Register"
    var id: String { rawValue }
}

private enum LoginAuthUIError: LocalizedError {
    case accountAlreadyExists

    var errorDescription: String? {
        switch self {
        case .accountAlreadyExists:
            return "This email is already registered. Please log in with your password."
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var authMode: LoginAuthMode = .login
    @State private var authEmail: String
    @State private var authPassword = ""
    @State private var authName = ""
    @State private var authMessage: String?
    @State private var isAuthBusy = false

    private let onLoginSuccess: (() -> Void)?

    init(initialEmail: String = "", onLoginSuccess: (() -> Void)? = nil) {
        _authEmail = State(initialValue: initialEmail)
        self.onLoginSuccess = onLoginSuccess
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(
                                "Login",
                                subtitle: "Sign in to sync your profile and data",
                                systemImage: "person.badge.key"
                            )

                            Picker("", selection: $authMode) {
                                ForEach(LoginAuthMode.allCases) { mode in
                                    Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if authMode == .register {
                                ProfileLabeledTextField(
                                    label: "Nickname",
                                    placeholder: "Nickname",
                                    text: $authName
                                )
                            }

                            ProfileLabeledTextField(
                                label: "Email",
                                placeholder: "you@example.com",
                                text: $authEmail,
                                autocapitalization: .never,
                                keyboardType: .emailAddress
                            )

                            ProfileLabeledTextField(
                                label: "Password",
                                placeholder: "********",
                                text: $authPassword,
                                autocapitalization: .never,
                                isSecure: true
                            )

                            Button {
                                runformAuth()
                            } label: {
                                Label(
                                    authMode == .login ? "Login" : "Register",
                                    systemImage: "person.crop.circle.badge.checkmark"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GradientButtonStyle(disabled: isAuthBusy))
                            .disabled(isAuthBusy)

                            if authMode == .login {
                                Button {
                                    forgotPassword()
                                } label: {
                                    Text("Forgot password?")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(AppTheme.mint)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .disabled(isAuthBusy)
                            }

                            if let authMessage {
                                Text(authMessage)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.mint)
                }
            }
        }
    }

    private func runformAuth() {
        let normalizedEmail = authEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            authMessage = "Email is required."
            return
        }
        guard isValidEmail(normalizedEmail) else {
            authMessage = "Please enter a valid email."
            return
        }
        guard !authPassword.isEmpty else {
            authMessage = "Password is required."
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
                    do {
                        response = try await APIClient.shared.register(
                            email: normalizedEmail,
                            password: authPassword,
                            name: authName.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    } catch {
                        if shouldFallbackToLogin(after: error) {
                            throw LoginAuthUIError.accountAlreadyExists
                        }
                        throw error
                    }
                }

                await MainActor.run {
                    appStore.signIn(response)
                    authMessage = "Login successful."
                    isAuthBusy = false
                    onLoginSuccess?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    authMessage = userFriendlyAuthMessage(for: error, mode: authMode)
                    isAuthBusy = false
                }
            }
        }
    }

    private func forgotPassword() {
        let normalizedEmail = authEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            authMessage = "Enter your email first, then tap Forgot password."
            return
        }
        guard isValidEmail(normalizedEmail) else {
            authMessage = "Please enter a valid email."
            return
        }

        isAuthBusy = true
        authMessage = nil

        Task {
            do {
                _ = try await APIClient.shared.requestPasswordReset(email: normalizedEmail)
                await MainActor.run {
                    authMessage = "If this email is registered, a password reset link has been sent."
                    isAuthBusy = false
                }
            } catch {
                await MainActor.run {
                    authMessage = "Unable to send reset email right now. Please try again."
                    isAuthBusy = false
                }
            }
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else {
            return false
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, options: [], range: range) else {
            return false
        }
        return match.range == range && match.url?.scheme == "mailto"
    }

    private func shouldFallbackToLogin(after error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("already")
            || message.contains("exists")
            || message.contains("registered")
            || message.contains("duplicate")
            || message.contains("taken")
    }

    private func userFriendlyAuthMessage(for error: Error, mode: LoginAuthMode) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription,
           localized == LoginAuthUIError.accountAlreadyExists.errorDescription {
            return localized
        }

        let normalized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("invalid email or password") {
            return "Email or password is incorrect. Please try again."
        }
        if normalized.contains("already registered") || normalized.contains("already exists") {
            return "This email is already registered. Please log in instead."
        }
        if normalized.contains("not found") || normalized.contains("route not found") {
            return "Service is temporarily unavailable. Please try again shortly."
        }
        if normalized.contains("timed out") || normalized.contains("network") || normalized.contains("offline") {
            return "Network error. Check your connection and try again."
        }

        if mode == .login {
            return "Unable to sign in right now. Please try again."
        }
        return "Unable to create account right now. Please try again."
    }
}
