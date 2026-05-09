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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First name")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.62))
                        TextField("First name", text: $firstName)
                            .textInputAutocapitalization(.words)
                            .focused($fieldFocused)
                            .padding(13)
                            .background(.black.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last name")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.62))
                        TextField("Last name", text: $lastName)
                            .textInputAutocapitalization(.words)
                            .focused($fieldFocused)
                            .padding(13)
                            .background(.black.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }

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
                    Text("Date of Birth")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                        .labelsHidden()
                        .tint(AppTheme.mint)
                        .colorScheme(.dark)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Running level")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    Picker("Running level", selection: $level) {
                        ForEach(RunnerLevel.allCases) { level in
                            Text(LocalizedStringKey(level.rawValue)).tag(level)
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

                Stepper("Running days / week: \(runningDaysPerWeek)", value: $runningDaysPerWeek, in: 1...7)
                    .foregroundStyle(.white)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label("Total exercise hours / week", systemImage: "clock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Text(String(format: "%.1f hrs", weeklyExerciseHours))
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.mint)
                    }
                    Slider(value: $weeklyExerciseHours, in: 0...30, step: 0.5)
                        .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label("Height", systemImage: "ruler")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Text("\(Int(heightCm)) cm")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.mint)
                    }
                    Slider(value: $heightCm, in: 130...220, step: 1)
                        .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label("Weight", systemImage: "scalemass")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Text("\(Int(weightKg)) kg")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.mint)
                    }
                    Slider(value: $weightKg, in: 30...200, step: 1)
                        .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    Picker("Goal", selection: $target) {
                        ForEach(TrainingTarget.allCases) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.mint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag(ProfileGender.male)
                        Text("Female").tag(ProfileGender.female)
                        Text("Other").tag(ProfileGender.other)
                        Text("Prefer not to say").tag(ProfileGender.unspecified)
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.mint)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shoe size")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.62))
                        TextField("EU 42 / US 9", text: $shoeSize)
                            .focused($fieldFocused)
                            .padding(13)
                            .background(.black.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Leg length (cm)")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.62))
                        TextField("85", text: $legLengthCmText)
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                            .padding(13)
                            .background(.black.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Shoe brand/model")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    TextField("ASICS Nimbus 27", text: $shoeBrandModel)
                        .textInputAutocapitalization(.words)
                        .focused($fieldFocused)
                        .padding(13)
                        .background(.black.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
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
        appStore.profile = TesterProfile(
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
        savedMessage = String(localized: "profile.saved")
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
