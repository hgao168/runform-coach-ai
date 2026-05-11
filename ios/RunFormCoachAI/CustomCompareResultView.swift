import SwiftUI

struct CustomCompareResultView: View {
    let poseMetrics: PoseMetrics
    let athleteAnalysis: AnalysisResponse

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    similarityCard
                    summaryCard
                    metricsComparisonSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Athlete Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var similarityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Form")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Confidence Score")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 6)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: poseMetrics.efficiencyScore)
                            .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(poseMetrics.efficiencyScore * 100))")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }

                Divider()
                    .background(.white.opacity(0.10))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Athlete's Form")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Confidence Score")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 6)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: athleteAnalysis.confidence)
                            .stroke(AppTheme.warmGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(athleteAnalysis.confidence * 100))")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Athlete Analysis", systemImage: "doc.text")
                    .font(.headline)
                    .foregroundStyle(AppTheme.mint)
                Text(athleteAnalysis.summary)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metricsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metrics Detected")
                .font(.headline)
                .foregroundStyle(.white)

            if athleteAnalysis.metrics.isEmpty {
                Text("No metrics detected in athlete's video")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else {
                ForEach(athleteAnalysis.metrics.prefix(8)) { metric in
                    athleteMetricRow(metric: metric)
                }
            }
        }
    }

    private func athleteMetricRow(metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: statusIcon(for: metric.status))
                    .foregroundStyle(statusColor(for: metric.status))
                    .font(.caption.weight(.bold))
                Text(metric.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(metric.score * 100))")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.actionGradient)
                        .frame(
                            width: geo.size.width * max(0, min(1, metric.score)),
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            if !metric.explanation.isEmpty {
                Text(metric.explanation)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(15)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "excellent", "great": return "checkmark.circle.fill"
        case "good", "fair": return "checkmark.circle.fill"
        case "warning", "poor": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "excellent", "great": return AppTheme.mint
        case "good", "fair": return AppTheme.cyan
        case "warning", "poor": return AppTheme.orange
        default: return .white.opacity(0.62)
        }
    }
}
