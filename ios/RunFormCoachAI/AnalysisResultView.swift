import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResponse
    var poseMetrics: PoseMetrics? = nil

    @State private var showCompare = false
    @State private var showShareSheet = false

    private static let normalGreen = Color(red: 0.00, green: 0.96, blue: 0.63)  // #00f5a0
    private static let abnormalRed = Color(red: 1.00, green: 0.27, blue: 0.27) // #ff4444

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreCard
            if poseMetrics != nil { compareButton }
            shareButton
            if let score = result.videoQualityScore { qualityCard(score: score) }
            metricsSection
            issuesSection

#if canImport(GoogleMobileAds)
#if DEBUG
            AdBannerView(adUnitID: AdBannerView.testAdUnitID)
                .frame(height: 50)
#else
            AdBannerView(adUnitID: AdBannerView.productionAdUnitID)
                .frame(height: 50)
#endif
#endif
        }
        .sheet(isPresented: $showCompare) {
            if let metrics = poseMetrics {
                CompareView(poseMetrics: metrics)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareItems = buildShareItems() {
                ShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - Adjustment 1: Metric status coloring based on biomechanical thresholds
    private func metricColor(for metric: Metric) -> Color {
        switch metric.status.lowercased() {
        case "good": return Self.normalGreen
        case "needs work": return Self.abnormalRed
        default: return AppTheme.mint // Moderate → default mint
        }
    }

    // MARK: - Adjustment 2: Share card "旧片考古" template (full report)
    private func buildShareItems() -> [Any]? {
        let issueCount = result.issues.count
        let raceName: String? = nil
        let title: String
        let subtitle: String
        if let race = raceName, !race.isEmpty {
            title = String(format: NSLocalizedString("share.archaeology.title_race %@", comment: ""), race)
            subtitle = String(format: NSLocalizedString("share.archaeology.subtitle_race %lld", comment: ""), issueCount)
        } else {
            title = String(format: NSLocalizedString("share.archaeology.title_default", comment: ""), issueCount)
            subtitle = NSLocalizedString("share.archaeology.subtitle_default", comment: "")
        }

        var shareText = "\(title)\n\(subtitle)\n"

        // ── Form Score ──
        let scorePercent = Int(result.confidence * 100)
        shareText += "\n📊 \(NSLocalizedString("share.report.score", comment: "")) \(scorePercent)%\n"
        shareText += "\"\(result.summary)\"\n"

        // ── Movement Metrics ──
        if !result.metrics.isEmpty {
            shareText += "\n📐 \(NSLocalizedString("share.report.metrics", comment: ""))\n"
            for metric in result.metrics {
                let metricPct = Int(metric.score * 100)
                let statusIcon = metric.score >= 0.70 ? "✅" : (metric.score >= 0.45 ? "⚠️" : "❌")
                shareText += "\(statusIcon) \(metric.name) — \(metric.status) (\(metricPct)%)\n"
                shareText += "   \(metric.explanation)\n"
            }
        }

        // ── Strength Focus (issues) ──
        if !result.issues.isEmpty {
            shareText += "\n⚠️ \(NSLocalizedString("share.report.issues", comment: "")) (\(issueCount)):\n"
            for (index, issue) in result.issues.enumerated() {
                shareText += "\n\(index + 1). \(issue.title) [\(issue.severity)]\n"
                shareText += "\(issue.explanation)\n"
                if !issue.recommendedExercises.isEmpty {
                    shareText += "→ "
                    shareText += issue.recommendedExercises.prefix(3).map { ex in
                        "\(ex.name): \(ex.sets)×\(ex.reps)"
                    }.joined(separator: " | ")
                    shareText += "\n"
                }
            }
        }

        // ── App Store link ──
        shareText += "\n📲 \(NSLocalizedString("share.report.download", comment: ""))\n"
        shareText += "https://apps.apple.com/au/app/runformai/id6765745720\n"

        shareText += "\n— RunForm AI"
        return [shareText]
    }

    // MARK: - Adjustment 3: Injury-prevention narrative helper
    private func injuryNarrative(for metric: Metric) -> String {
        let name = metric.name.lowercased()
        // Keep original explanation but prepend/prepend injury context
        switch true {
        case name.contains("cadence") || name.contains("步频"):
            if metric.score < 0.55 {
                return String(localized: "injury.cadence_low \\(metric.explanation)")
            }
        case name.contains("ground contact") || name.contains("触地"):
            if metric.score < 0.55 {
                return String(localized: "injury.gct_high \\(metric.explanation)")
            }
        case name.contains("knee") || name.contains("膝") || name.contains("valgus"):
            if metric.score < 0.55 {
                return String(localized: "injury.knee_risk \\(metric.explanation)")
            }
        case name.contains("trunk") || name.contains("躯干") || name.contains("lean"):
            if metric.score < 0.55 {
                return String(localized: "injury.trunk_lean \\(metric.explanation)")
            }
        case name.contains("overstride") || name.contains("跨步") || name.contains("步幅"):
            if metric.score < 0.55 {
                return String(localized: "injury.overstride \\(metric.explanation)")
            }
        case name.contains("hip") || name.contains("髋"):
            if metric.score < 0.55 {
                return String(localized: "injury.hip_drop \\(metric.explanation)")
            }
        default:
            break
        }
        return metric.explanation
    }

    private var shareButton: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
                Text(String(localized: "share.archaeology.button"))
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.60)
            }
            .foregroundStyle(.black)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(AppTheme.warmGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppTheme.orange.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var compareButton: some View {
        Button {
            showCompare = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.headline)
                Text("Compare with Elite")
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.60)
            }
            .foregroundStyle(.black)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(AppTheme.actionGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppTheme.cyan.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
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
                        Circle().stroke(.white.opacity(0.12), lineWidth: 8).frame(width: 76, height: 76)
                        Circle()
                            .trim(from: 0, to: result.confidence)
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

    private func qualityCard(score: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Video Quality", systemImage: "camera.metering.center.weighted")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(score * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.actionGradient)
                    .clipShape(Capsule())
            }
            ProgressView(value: score).tint(AppTheme.mint)
            if let notes = result.qualityNotes, !notes.isEmpty {
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
            } else {
                Text("Clip quality is good enough for reliable on-device pose analysis.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .padding(15)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Movement Metrics")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(result.metrics) { metric in
                let color = metricColor(for: metric)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(metric.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color.opacity(0.9))
                        Spacer()
                        Text(metric.status)
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(color)
                            .clipShape(Capsule())
                    }
                    ProgressView(value: metric.score).tint(color)
                    Text(injuryNarrative(for: metric))
                        .font(.caption)
                        .foregroundStyle(color.opacity(0.75))
                }
                .padding(15)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strength Focus")
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
                    ForEach(issue.recommendedExercises) { exercise in ExerciseCard(exercise: exercise) }
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
    @Environment(\.openURL) private var openURL

    private var videoSearchURL: URL? {
        let query = "\(exercise.name) running exercise form"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let isChinaRegion = Locale.current.region?.identifier == "CN"
        let urlString = isChinaRegion
            ? "https://search.bilibili.com/all?keyword=\(encoded)"
            : "https://www.youtube.com/results?search_query=\(encoded)"
        return URL(string: urlString)
    }

    var body: some View {
        Button {
            if let url = videoSearchURL { openURL(url) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.actionGradient)
                        .frame(width: 42, height: 42)
                    Image(systemName: "dumbbell.fill").foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Image(systemName: "play.circle")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mint)
                    }
                    Text("\(exercise.category) • \(exercise.sets) sets • \(exercise.reps) • \(exercise.frequencyPerWeek)x/week")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                    Text(exercise.reason).font(.caption).foregroundStyle(.white.opacity(0.62))
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ShareSheet UIKit bridge (Adjustment 2)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
