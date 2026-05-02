import SwiftUI

struct PlanBuilderView: View {
    @State private var currentWeeklyKmText = "20"
    @State private var target: TrainingTarget = .generalFitness
    @State private var availableRunningDays = 3
    @State private var injuryFlag = false
    @State private var isGenerating = false
    @State private var plan: TrainingPlanResponse?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introCard
                    inputCard
                    generateButton

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }

                    if let plan {
                        TrainingPlanResultView(plan: plan)
                    }
                }
                .padding()
            }
            .navigationTitle("Next Week Plan")
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personalized running week")
                .font(.title2.bold())
            Text("Enter your current weekly volume, goal, available days, and injury status. RunForm will generate easy, quality, long, and strength/mobility sessions.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inputs")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Current weekly km")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. 20", text: $currentWeeklyKmText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Target", selection: $target) {
                ForEach(TrainingTarget.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)

            Stepper("Available running days: \(availableRunningDays)", value: $availableRunningDays, in: 1...7)

            Toggle("Injury or pain flag", isOn: $injuryFlag)

            if injuryFlag {
                Text("RunForm will reduce progression and replace harder work with easy running or mobility.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 1)
    }

    private var generateButton: some View {
        Button {
            Task { await generatePlan() }
        } label: {
            if isGenerating {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Label("Generate Plan", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
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
            errorMessage = "Plan generation failed. Check backend URL and Railway deployment."
        }

        isGenerating = false
    }
}

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
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan Summary")
                .font(.headline)
            Text(plan.summary)
                .foregroundStyle(.secondary)
            HStack {
                Label("\(plan.plannedWeeklyKm, specifier: "%.1f") km", systemImage: "figure.run")
                Spacer()
                Label("\(plan.runningDays) days", systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var workoutList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workouts")
                .font(.headline)
            ForEach(plan.workouts) { workout in
                WorkoutCard(workout: workout)
            }
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coach Notes")
                .font(.headline)
            ForEach(plan.notes, id: \.self) { note in
                Label(note, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 1)
    }
}

struct WorkoutCard: View {
    let workout: PlannedWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.day)
                    .font(.headline)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline)
                    Text(workout.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                Spacer()
                if let distanceKm = workout.distanceKm {
                    Text("\(distanceKm, specifier: "%.1f") km")
                        .font(.headline)
                } else if let durationMinutes = workout.durationMinutes {
                    Text("\(durationMinutes) min")
                        .font(.headline)
                }
            }

            Text(workout.intensity)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(workout.details)
                .font(.callout)
            Text("Why: \(workout.purpose)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 1)
    }
}
