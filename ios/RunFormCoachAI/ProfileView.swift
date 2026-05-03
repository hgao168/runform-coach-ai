import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var nickname = ""
    @State private var level: RunnerLevel = .beginner
    @State private var weeklyMileageKm: Double = 15
    @State private var target = TrainingTarget.generalFitness.rawValue
    @State private var injuryNote = ""
    @State private var savedMessage: String?
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
        }
    }

    private var profileHero: some View {
        GlassCard {
            HStack(spacing: 15) {
                IconBubble(systemImage: "person.crop.circle.fill", gradient: AppTheme.actionGradient, size: 62)
                VStack(alignment: .leading, spacing: 5) {
                    Text(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Test Runner" : nickname)
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nickname")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    TextField("Nickname", text: $nickname)
                        .textInputAutocapitalization(.words)
                        .focused($fieldFocused)
                        .padding(13)
                        .background(.black.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Running level")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    Picker("Running level", selection: $level) {
                        ForEach(RunnerLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label("Weekly mileage", systemImage: "speedometer")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Text("\(Int(weeklyMileageKm)) km")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.mint)
                    }
                    Slider(value: $weeklyMileageKm, in: 0...120, step: 1)
                        .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    Picker("Goal", selection: $target) {
                        ForEach(TrainingTarget.allCases) { item in
                            Text(item.rawValue).tag(item.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Injury note")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    TextField("Optional", text: $injuryNote, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($fieldFocused)
                        .padding(13)
                        .background(.black.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }

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
        nickname = profile.nickname
        level = profile.level
        weeklyMileageKm = profile.weeklyMileageKm
        if TrainingTarget.allCases.contains(where: { $0.rawValue == profile.target }) {
            target = profile.target
        } else {
            target = TrainingTarget.generalFitness.rawValue
        }
        injuryNote = profile.injuryNote
    }

    private func saveProfile() {
        fieldFocused = false
        dismissKeyboard()
        appStore.profile = TesterProfile(
            nickname: nickname,
            level: level,
            weeklyMileageKm: weeklyMileageKm,
            target: target,
            injuryNote: injuryNote
        )
        savedMessage = "Profile saved"
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
