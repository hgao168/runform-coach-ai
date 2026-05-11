import SwiftUI

// MARK: - Plan result summary

struct TrainingPlanResultView: View {
    let plan: TrainingPlanResponse
    var planID: UUID? = nil
    var showMarathonBlock: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryCard
            if showMarathonBlock, let marathonPlan = plan.marathonPlan {
                marathonPlanCard(marathonPlan)
            }
            workoutList
            notesCard
        }
    }

    private func marathonPlanCard(_ marathonPlan: MarathonPlanBlock) -> some View {
        let boundaries = marathonPhaseBoundaries(marathonPlan.weeks)
        return DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Marathon Block")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(marathonPlan.race.normalizedPlanText) • \(marathonPlan.totalWeeks) weeks")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.mint)
                Text(marathonPlan.courseProfile.normalizedPlanText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                Label(marathonPlan.elevationNote.normalizedPlanText, systemImage: "mountain.2")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))

                if !boundaries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phase boundaries")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.mint)
                        ForEach(boundaries, id: \.id) { boundary in
                            HStack(spacing: 8) {
                                Text(boundary.label.normalizedPlanText)
                                    .font(.caption.bold())
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.actionGradient)
                                    .clipShape(Capsule())
                                Text("W\(boundary.startWeek)-W\(boundary.endWeek)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }

                ForEach(boundaries, id: \.id) { boundary in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(boundary.label.normalizedPlanText) summary")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.mint)
                            Spacer()
                            Text("W\(boundary.startWeek)-W\(boundary.endWeek)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))
                        }
                        Text("Volume: \(boundary.startTargetKm, specifier: "%.1f") -> \(boundary.endTargetKm, specifier: "%.1f") km/week")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.72))
                        Text("Long run: \(boundary.startLongRunKm, specifier: "%.1f") -> \(boundary.endLongRunKm, specifier: "%.1f") km")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                        Text(boundary.sampleKeyWorkout.normalizedPlanText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(8)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func marathonPhaseBoundaries(_ weeks: [MarathonPlanWeek]) -> [MarathonPhaseBoundary] {
        let sorted = weeks.sorted { $0.week < $1.week }
        guard let first = sorted.first else { return [] }

        var grouped: [[MarathonPlanWeek]] = [[first]]
        for week in sorted.dropFirst() {
            if grouped[grouped.count - 1][0].phase == week.phase {
                grouped[grouped.count - 1].append(week)
            } else {
                grouped.append([week])
            }
        }

        return grouped.compactMap { group in
            guard let start = group.first, let end = group.last else { return nil }
            return MarathonPhaseBoundary(
                id: "\(start.phase)-\(start.week)-\(end.week)",
                label: start.phase,
                startWeek: start.week,
                endWeek: end.week,
                startTargetKm: start.targetKm,
                endTargetKm: end.targetKm,
                startLongRunKm: start.longRunKm,
                endLongRunKm: end.longRunKm,
                sampleKeyWorkout: start.keyWorkout
            )
        }
    }

    private struct MarathonPhaseBoundary {
        let id: String
        let label: String
        let startWeek: Int
        let endWeek: Int
        let startTargetKm: Double
        let endTargetKm: Double
        let startLongRunKm: Double
        let endLongRunKm: Double
        let sampleKeyWorkout: String
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan Summary")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(plan.summary.normalizedPlanText)
                    .foregroundStyle(.white.opacity(0.75))
                HStack {
                    Label("\(plan.plannedWeeklyKm, specifier: "%.1f") km", systemImage: "figure.run")
                    Spacer()
                    Label("\(plan.runningDays) days", systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                if plan.connectedAnalysisUsed {
                    Label("Adapted from your latest RunForm analysis", systemImage: "link.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                }
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
                WorkoutCard(workout: workout, planID: planID)
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
                    Label(note.normalizedPlanText, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
