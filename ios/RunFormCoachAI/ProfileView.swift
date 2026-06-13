import SwiftUI

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
        let profile = TesterProfile(
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            email: email,
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
