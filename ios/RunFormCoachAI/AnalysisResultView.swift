import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryCard
            metricsSection
            issuesSection
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis Summary")
                .font(.headline)
            Text(result.summary)
                .foregroundStyle(.secondary)
            Text("Confidence: \(Int(result.confidence * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Movement Metrics")
                .font(.headline)

            ForEach(result.metrics) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(metric.name)
                            .fontWeight(.medium)
                        Spacer()
                        Text(metric.status)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                    ProgressView(value: metric.score)
                    Text(metric.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 1)
            }
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recommended Strength Plan")
                .font(.headline)

            ForEach(result.issues) { issue in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(issue.title)
                            .font(.headline)
                        Spacer()
                        Text(issue.severity)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }

                    Text(issue.explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    ForEach(issue.recommendedExercises) { exercise in
                        ExerciseCard(exercise: exercise)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .fontWeight(.semibold)
            Text("\(exercise.category) • \(exercise.sets) sets • \(exercise.reps) • \(exercise.frequencyPerWeek)x/week")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(exercise.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
