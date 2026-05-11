import SwiftUI

struct WorkoutCard: View {
    @EnvironmentObject private var appStore: AppStore
    let workout: PlannedWorkout
    let planID: UUID?

    private var currentStatus: WorkoutStatus? {
        guard let planID else { return nil }
        return appStore.workoutStatus(planID: planID, workoutID: workout.id)
    }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.day)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                        .frame(width: 38, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(workout.title))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(LocalizedStringKey(workout.category))
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
                if let focus = workout.coachingFocus {
                    Label(focus, systemImage: "figure.run.circle")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                }
                Text("Why: \(workout.purpose)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))

                if let planID {
                    WorkoutStatusRow(
                        workoutID: workout.id,
                        planID: planID,
                        currentStatus: currentStatus
                    )
                }
            }
        }
    }
}

struct WorkoutStatusRow: View {
    @EnvironmentObject private var appStore: AppStore
    let workoutID: String
    let planID: UUID
    let currentStatus: WorkoutStatus?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WorkoutStatus.allCases) { status in
                Button {
                    // Tap again to deselect
                    let next: WorkoutStatus? = currentStatus == status ? nil : status
                    if let next {
                        appStore.logWorkout(planID: planID, workoutID: workoutID, status: next)
                    } else {
                        appStore.clearWorkoutLog(planID: planID, workoutID: workoutID)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                        Text(LocalizedStringKey(status.rawValue))
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(currentStatus == status ? .black : .white.opacity(0.65))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(currentStatus == status ? status.color : Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: currentStatus)
            }
        }
        .padding(.top, 4)
    }
}
