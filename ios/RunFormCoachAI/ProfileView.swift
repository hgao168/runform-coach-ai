import SwiftUI

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
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        formCard
                        whyCard
                        stravaComingSoonCard
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
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Injury note")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))

                ZStack(alignment: .topLeading) {
                    if injuryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Optional")
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 10)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $injuryNote)
                        .focused($fieldFocused)
                        .textInputAutocapitalization(.sentences)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120, maxHeight: 180)
                        .foregroundStyle(.white)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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

    private var stravaComingSoonCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle("Strava integration coming soon", subtitle: "Better plans with real data", systemImage: "shield")
                Text("We’re working on bringing Strava integration to help personalize your training even more. Stay tuned!")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
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

}
