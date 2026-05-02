import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreCard
            if let quality = result.quality {
                qualityCard(quality)
            }
            metricsSection
            issuesSection
        }
    }

    private var scoreCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Form Report")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(result.summary)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 8)
                            .frame(width: 76, height: 76)
                        Circle()
                            .trim(from: 0, to: max(0, min(1, result.confidence)))
                            .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 76, height: 76)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(result.confidence * 100))%")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func qualityCard(_ quality: VideoQuality) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Video Quality", systemImage: quality.score >= 0.70 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(quality.status)
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.actionGradient)
                    .clipShape(Capsule())
            }

            ProgressView(value: quality.score)
                .tint(AppTheme.mint)

            if !quality.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(quality.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            }

            if quality.score < 0.70 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Re-record tips")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    ForEach(quality.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mint)
                                .padding(.top, 2)
                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Movement Metrics")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(result.metrics) { metric in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(metric.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(metric.status)
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(metric.status == "Not measurable" ? Color.orange.opacity(0.9) : AppTheme.actionGradient)
                            .clipShape(Capsule())
                    }
                    ProgressView(value: metric.score)
                        .tint(metric.status == "Not measurable" ? .orange : AppTheme.mint)
                    Text(metric.explanation)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }
                .padding(15)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Corrective Plan")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(result.issues) { issue in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(issue.title, systemImage: "target")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(issue.severity)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.12))
                            .foregroundStyle(.white.opacity(0.82))
                            .clipShape(Capsule())
                    }
                    Text(issue.explanation)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                    ForEach(issue.recommendedExercises) { exercise in
                        ExerciseCard(exercise: exercise)
                    }
                }
                .padding(16)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.actionGradient)
                    .frame(width: 42, height: 42)
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.black)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(exercise.category) • \(exercise.sets) sets • \(exercise.reps) • \(exercise.frequencyPerWeek)x/week")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Why this exercise")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.mint)
                    Text(exercise.reason)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .padding(.top, 2)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
