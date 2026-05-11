import SwiftUI

struct RacePlanDetailView: View {
    let planBlock: RacePlanBlock
    let onUseWeekKm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    private var raceDistanceKm: Double {
        switch planBlock.target {
        case "5K": return 5.0
        case "10K": return 10.0
        default: return 21.1  // Half Marathon
        }
    }

    private var phaseGroups: [(phase: String, weeks: [RacePlanWeek])] {
        let sorted = planBlock.weeks.sorted { $0.week < $1.week }
        var result: [(phase: String, weeks: [RacePlanWeek])] = []
        for week in sorted {
            if let last = result.last, last.phase == week.phase {
                result[result.count - 1].weeks.append(week)
            } else {
                result.append((phase: week.phase, weeks: [week]))
            }
        }
        return result
    }

    private func isLastWeek(_ week: RacePlanWeek) -> Bool {
        planBlock.weeks.sorted { $0.week < $1.week }.last?.week == week.week
    }

    private func buildDisplayWorkouts(for week: RacePlanWeek) -> [PlannedWorkout] {
        guard isLastWeek(week) else { return week.workouts }
        return week.workouts.map { workout in
            guard workout.day.lowercased().contains("sun") else { return workout }
            let raceLabel: String
            switch planBlock.target {
            case "5K":          raceLabel = "Race day - 5K"
            case "10K":         raceLabel = "Race day - 10K"
            default:            raceLabel = "Race day - 21.1K Half Marathon"
            }
            return PlannedWorkout(
                day: workout.day,
                title: "\(planBlock.target) Race",
                category: workout.category,
                intensity: "race",
                details: raceLabel,
                purpose: workout.purpose,
                distanceKm: raceDistanceKm,
                durationMinutes: workout.durationMinutes,
                coachingFocus: workout.coachingFocus
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        DarkCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(planBlock.target) Training Block")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(planBlock.level) • \(planBlock.totalWeeks) weeks")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.mint)
                                Text("Base → BuildUp → Peak → Taper periodization.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }

                        ForEach(phaseGroups, id: \.phase) { group in
                            let startWeek = group.weeks.first?.week ?? 0
                            let endWeek = group.weeks.last?.week ?? 0
                            DarkCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(group.phase) W\(startWeek)-W\(endWeek)")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    ForEach(group.weeks) { week in
                                        let isRace = isLastWeek(week)
                                        let displayTargetKm = isRace ? raceDistanceKm : week.targetKm

                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text("Week \(week.week)")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.white)
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("\(displayTargetKm, specifier: "%.1f") km")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(AppTheme.mint)
                                                    if isRace {
                                                        Text("(Race day)")
                                                            .font(.caption2)
                                                            .foregroundStyle(AppTheme.orange)
                                                    }
                                                }
                                                Button {
                                                    onUseWeekKm(week.targetKm)
                                                    dismiss()
                                                } label: {
                                                    Label("Use", systemImage: "arrow.up.circle.fill")
                                                        .font(.caption2)
                                                        .foregroundStyle(AppTheme.mint)
                                                }
                                                .buttonStyle(.plain)
                                            }

                                            if !isRace {
                                                Text("Long run: \(week.longRunKm, specifier: "%.1f") km")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.66))
                                            }
                                            Text(week.keyWorkout)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.78))

                                            if !week.workouts.isEmpty {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Weekly activities")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(AppTheme.mint)
                                                    ForEach(buildDisplayWorkouts(for: week), id: \.id) { workout in
                                                        HStack(alignment: .top, spacing: 6) {
                                                            Text(workout.day)
                                                                .font(.caption2.bold())
                                                                .foregroundStyle(.white)
                                                                .frame(width: 28, alignment: .leading)
                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text("\(workout.title) • \(workout.distanceKm ?? 0, specifier: "%.1f") km")
                                                                    .font(.caption2.bold())
                                                                    .foregroundStyle(.white.opacity(0.88))
                                                                Text(workout.details)
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.white.opacity(0.68))
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(8)
                                        .background(.white.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("\(planBlock.target) Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.mint)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
