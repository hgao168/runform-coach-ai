import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreCard
            if let quality = result.quality { qualityCard(quality) }
            metricsSection
            issuesSection
        }
    }

    private var scoreCard: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Form Report")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(result.summary)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        MetricPill(text: "Confidence", systemImage: "shield.lefthalf.filled")
                        MetricPill(text: "\(result.metrics.count) metrics", systemImage: "waveform.path.ecg")
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 6)
                ConfidenceRing(value: result.confidence)
            }
        }
    }

    private func qualityCard(_ quality: VideoQuality) -> some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    SectionTitle("Video Quality", subtitle: "Input reliability", systemImage: quality.score >= 0.70 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    Spacer()
                    StatusBadge(text: quality.status, color: quality.score >= 0.70 ? AppTheme.mint : AppTheme.orange)
                }

                ProgressView(value: quality.score)
                    .tint(quality.score >= 0.70 ? AppTheme.mint : AppTheme.orange)
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)

                if !quality.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(quality.reasons, id: \.self) { reason in
                            Label(reason, systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))
                        }
                    }
                }

                if quality.score < 0.70 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Re-record tips")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        ForEach(quality.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mint)
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.66))
                            }
                        }
                    }
                    .padding(13)
                    .background(.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Movement Metrics", subtitle: "What the video suggests", systemImage: "chart.xyaxis.line")
            ForEach(result.metrics, id: \.id) { metric in
                MetricResultCard(metric: metric)
            }
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Strength Focus", subtitle: "Exercises mapped to form issues", systemImage: "figure.strengthtraining.traditional")
            ForEach(result.issues, id: \.id) { issue in
                IssueCard(issue: issue)
            }
        }
    }
}

struct ConfidenceRing: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 9)
                .frame(width: 86, height: 86)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 86, height: 86)
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(value * 100))%")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("score")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
    }
}

struct MetricResultCard: View {
    let metric: Metric

    private var badgeColor: Color {
        metric.status == "Not measurable" ? AppTheme.orange : AppTheme.mint
    }

    private var confidenceColor: Color {
        switch metric.confidence {
        case "High":   return AppTheme.mint
        case "Low":    return AppTheme.orange
        default:       return AppTheme.cyan
        }
    }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        IconBubble(systemImage: iconName, gradient: AppTheme.purpleGradient, size: 36)
                        Text(metric.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    StatusBadge(text: metric.status, color: badgeColor)
                }

                ProgressView(value: metric.score)
                    .tint(badgeColor)
                    .scaleEffect(x: 1, y: 1.08, anchor: .center)

                HStack(spacing: 5) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)
                    Text("Confidence: \(metric.confidence)")
                        .font(.caption2.bold())
                        .foregroundStyle(confidenceColor)
                }

                Text(metric.explanation)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var iconName: String {
        let lower = metric.name.lowercased()
        if lower.contains("cadence") { return "metronome.fill" }
        if lower.contains("stride") { return "figure.run" }
        if lower.contains("trunk") { return "figure.core.training" }
        if lower.contains("hip") { return "figure.strengthtraining.functional" }
        if lower.contains("arm") { return "arrow.left.and.right" }
        return "waveform.path.ecg"
    }
}

struct IssueCard: View {
    let issue: Issue

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Label(issue.title, systemImage: issueIcon)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(issue.severity)
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(severityColor.opacity(0.92))
                        .foregroundStyle(.black.opacity(0.86))
                        .clipShape(Capsule())
                }

                Text(issue.explanation)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(issue.recommendedExercises, id: \.id) { exercise in
                        ExerciseCard(exercise: exercise)
                    }
                }
            }
        }
    }

    private var issueIcon: String {
        let lower = issue.title.lowercased()
        if lower.contains("over") || lower.contains("stride") { return "figure.run.square.stack" }
        if lower.contains("knee") { return "figure.walk.motion" }
        if lower.contains("trunk") || lower.contains("lean") { return "figure.core.training" }
        if lower.contains("hip") { return "figure.strengthtraining.functional" }
        if lower.contains("arm") { return "arrow.left.and.right" }
        return "target"
    }

    private var severityColor: Color {
        switch issue.severity.lowercased() {
        case "high": return AppTheme.orange
        case "medium": return AppTheme.mint
        default: return Color.white.opacity(0.80)
        }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            IconBubble(systemImage: exerciseIcon, gradient: AppTheme.actionGradient, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(exercise.category) • \(exercise.sets) sets • \(exercise.reps) • \(exercise.frequencyPerWeek)x/week")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.mint)
                        .padding(.top, 2)
                    Text(exercise.reason)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var exerciseIcon: String {
        let lower = exercise.name.lowercased()
        if lower.contains("skip") { return "figure.run" }
        if lower.contains("wall") { return "figure.cooldown" }
        if lower.contains("plank") { return "figure.core.training" }
        if lower.contains("bridge") { return "figure.strengthtraining.functional" }
        if lower.contains("squat") { return "figure.strengthtraining.traditional" }
        if lower.contains("monster") { return "shoeprints.fill" }
        return "dumbbell.fill"
    }
}
