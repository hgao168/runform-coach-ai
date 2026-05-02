import SwiftUI

struct PlanBuilderView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var currentWeeklyKmText = "20"
    @State private var target: TrainingTarget = .generalFitness
    @State private var availableRunningDays = 3
    @State private var injuryFlag = false
    @State private var isGenerating = false
    @State private var plan: TrainingPlanResponse?
    @State private var errorMessage: String?
    @State private var planSaved = false
    @State private var showSavedPlans = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        introCard
                        inputCard
                        generateButton

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.callout)
                                .padding(.horizontal, 4)
                        }

                        if let plan {
                            TrainingPlanResultView(plan: plan)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSavedPlans = true
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(AppTheme.mint)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if plan != nil {
                        if planSaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.mint)
                        } else {
                            Button("Save Plan") {
                                if let p = plan {
                                    let km = Double(currentWeeklyKmText.replacingOccurrences(of: ",", with: ".")) ?? 0
                                    appStore.savePlan(p, target: target.rawValue, weeklyKm: km)
                                    planSaved = true
                                }
                            }
                            .foregroundStyle(AppTheme.mint)
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSavedPlans) {
                SavedPlansView()
            }
        }
    }

    private var introCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    IconBubble(systemImage: "calendar.badge.plus", gradient: AppTheme.purpleGradient, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Week Plan")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Set your goal, volume, and days. Get a smart weekly plan.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
            }
        }
    }

    private var inputCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("Your inputs", subtitle: nil, systemImage: "slider.horizontal.3")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current weekly km")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("e.g. 20", text: $currentWeeklyKmText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Picker("Target", selection: $target) {
                        ForEach(TrainingTarget.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.mint)
                }

                Stepper("Running days: \(availableRunningDays)", value: $availableRunningDays, in: 1...7)
                    .foregroundStyle(.white)

                Toggle("Injury / pain flag", isOn: $injuryFlag)
                    .tint(AppTheme.mint)

                if injuryFlag {
                    Label("Progression will be reduced; hard sessions replaced with easy runs.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var generateButton: some View {
        Button {
            planSaved = false
            Task { await generatePlan() }
        } label: {
            if isGenerating {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Label("Generate Plan", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isGenerating)
    }

    private func generatePlan() async {
        guard let km = Double(currentWeeklyKmText.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Please enter a valid weekly km number."
            return
        }

        isGenerating = true
        errorMessage = nil

        let input = TrainingPlanInput(
            currentWeeklyKm: km,
            target: target.rawValue,
            availableRunningDays: availableRunningDays,
            injuryFlag: injuryFlag
        )

        do {
            plan = try await APIClient.shared.generateTrainingPlan(input: input)
        } catch {
            errorMessage = "Plan generation failed. Check your connection."
        }

        isGenerating = false
    }
}

// MARK: - Saved Plans sheet

struct SavedPlansView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if appStore.savedPlans.isEmpty {
                    VStack(spacing: 16) {
                        IconBubble(systemImage: "bookmark", gradient: AppTheme.purpleGradient, size: 72)
                        Text("No saved plans yet")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Generate a plan and tap \"Save Plan\" to keep it here.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.horizontal, 34)
                    }
                } else {
                    List {
                        ForEach(appStore.savedPlans) { saved in
                            NavigationLink {
                                SavedPlanDetailView(saved: saved)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(saved.target)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("\(saved.plan.plannedWeeklyKm, specifier: "%.1f") km · \(saved.plan.runningDays) days")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                    Text(saved.createdAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { appStore.savedPlans[$0].id }.forEach { appStore.deleteSavedPlan(id: $0) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                Button("Done") { dismiss() }
                    .foregroundStyle(AppTheme.mint)
            }
        }
    }
}

struct SavedPlanDetailView: View {
    let saved: SavedPlan

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    TrainingPlanResultView(plan: saved.plan)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(saved.target)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Plan result views

struct TrainingPlanResultView: View {
    let plan: TrainingPlanResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryCard
            workoutList
            notesCard
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan Summary")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(plan.summary)
                    .foregroundStyle(.white.opacity(0.75))
                HStack {
                    Label("\(plan.plannedWeeklyKm, specifier: "%.1f") km", systemImage: "figure.run")
                    Spacer()
                    Label("\(plan.runningDays) days", systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var workoutList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workouts")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            ForEach(plan.workouts, id: \.id) { workout in
                WorkoutCard(workout: workout)
            }
        }
    }

    private var notesCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Coach Notes")
                    .font(.headline)
                    .foregroundStyle(.white)
                ForEach(plan.notes, id: \.self) { note in
                    Label(note, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

struct WorkoutCard: View {
    let workout: PlannedWorkout

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.day)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                        .frame(width: 38, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(workout.category)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let distanceKm = workout.distanceKm {
                        Text("\(distanceKm, specifier: "%.1f") km")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else if let durationMinutes = workout.durationMinutes {
                        Text("\(durationMinutes) min")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }

                Text(workout.intensity)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                Text(workout.details)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                Text("Why: \(workout.purpose)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}
