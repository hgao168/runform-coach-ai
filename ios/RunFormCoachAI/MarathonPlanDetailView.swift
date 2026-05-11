import SwiftUI

struct MarathonPhaseLink: Identifiable {
    let id: String
    let label: String
    let startWeek: Int
    let endWeek: Int
    let startTargetKm: Double
    let endTargetKm: Double
    let startLongRunKm: Double
    let endLongRunKm: Double
    let weeks: [MarathonPlanWeek]
}

struct MarathonPlanDetailView: View {
    let planBlock: MarathonPlanBlock
    let onUseWeekKm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    private var phaseGroups: [MarathonPhaseLink] {
        let sorted = planBlock.weeks.sorted { $0.week < $1.week }
        guard let first = sorted.first else { return [] }

        var groups: [[MarathonPlanWeek]] = [[first]]
        for week in sorted.dropFirst() {
            if groups[groups.count - 1][0].phase == week.phase {
                groups[groups.count - 1].append(week)
            } else {
                groups.append([week])
            }
        }

        return groups.compactMap { group in
            guard let start = group.first, let end = group.last else { return nil }
            return MarathonPhaseLink(
                id: "\(start.phase)-\(start.week)-\(end.week)",
                label: start.phase,
                startWeek: start.week,
                endWeek: end.week,
                startTargetKm: start.targetKm,
                endTargetKm: end.targetKm,
                startLongRunKm: start.longRunKm,
                endLongRunKm: end.longRunKm,
                weeks: group
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
                                Text("\(planBlock.race) Marathon Block")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(planBlock.planProfile) • \(planBlock.totalWeeks) weeks")
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.mint)
                                Text(planBlock.courseProfile)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                                Text(planBlock.elevationNote)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }

                        ForEach(phaseGroups) { group in
                            DarkCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(group.label) W\(group.startWeek)-W\(group.endWeek)")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Target: \(group.startTargetKm, specifier: "%.1f") -> \(group.endTargetKm, specifier: "%.1f") km/week")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.72))

                                    ForEach(group.weeks) { week in
                                        VStack(alignment: .leading, spacing: 6) {
                                            let isRaceWeek = isLastWeek(week)
                                            // Race week shows the actual race distance (42.2 km), mirroring 5K/10K/Half plans.
                                            let displayTargetKm = isRaceWeek ? 42.2 : week.targetKm
                                            
                                            HStack {
                                                Text("Week \(week.week)")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(.white)
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("\(displayTargetKm, specifier: "%.1f") km")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(AppTheme.mint)
                                                    if isRaceWeek {
                                                        Text("(Race week)")
                                                            .font(.caption2)
                                                            .foregroundStyle(AppTheme.orange)
                                                    }
                                                }
                                            }
                                            if !isRaceWeek {
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
            .navigationTitle("Marathon Plan Details")
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

    private func buildDisplayWorkouts(for week: MarathonPlanWeek) -> [PlannedWorkout] {
        guard isLastWeek(week) else { return week.workouts }
        // On race week, only override Sunday to show the marathon race entry.
        // Saturday (and any other planner-generated day) is left untouched so the
        // taper logic in the backend planner stays in control.
        return week.workouts.map { workout in
            guard workout.day.lowercased().contains("sun") else { return workout }
            return PlannedWorkout(
                day: workout.day,
                title: "Marathon Race",
                category: workout.category,
                intensity: "race",
                details: "Race day - 42.2 km marathon",
                purpose: workout.purpose,
                distanceKm: 42.2,
                durationMinutes: workout.durationMinutes,
                coachingFocus: workout.coachingFocus
            )
        }
    }

    private func isLastWeek(_ week: MarathonPlanWeek) -> Bool {
        let allWeeks = planBlock.weeks.sorted { $0.week < $1.week }
        return week.week == allWeeks.last?.week
    }
}
