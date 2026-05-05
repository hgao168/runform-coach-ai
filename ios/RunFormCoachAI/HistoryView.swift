import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var showClearConfirmation = false

    // Chronological order for trend lines (oldest → newest)
    private var sorted: [AnalysisHistoryItem] {
        appStore.history.sorted { $0.createdAt < $1.createdAt }
    }

    // Form score trend — confidence is 0–1 higher = better
    private var formScores: [Double] {
        sorted.map(\.result.confidence)
    }

    // Cadence — actual cadence metric score from backend
    private var cadenceScores: [Double] {
        sorted.compactMap { item in
            item.result.metrics.first { $0.name.lowercased().contains("cadence") }?.score
        }
    }

    // Hip stability — "Hip stability" metric score
    private var hipScores: [Double] {
        sorted.compactMap { item in
            item.result.metrics.first { $0.name.lowercased().contains("hip") }?.score
        }
    }

    // Distinct calendar days with at least one session in the last 30 days
    private var recentSessionCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentDates = appStore.history
            .filter { $0.createdAt >= cutoff }
            .map { Calendar.current.startOfDay(for: $0.createdAt) }
        return Set(recentDates).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if appStore.history.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            if appStore.history.count >= 2 {
                                trendsSection
                            }
                            reportsSection
                        }
                        .padding(18)
                    }
                }
            }
            .navigationTitle("History")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !appStore.history.isEmpty {
                    Button("Clear") { showClearConfirmation = true }
                        .foregroundStyle(AppTheme.mint)
                }
            }
            .confirmationDialog("Clear all local history?", isPresented: $showClearConfirmation) {
                Button("Clear History", role: .destructive) { appStore.clearHistory() }
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                "Progress",
                subtitle: "\(appStore.history.count) sessions",
                systemImage: "chart.line.uptrend.xyaxis"
            )
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TrendCard(title: "Form score", values: formScores, color: AppTheme.mint)
                TrendCard(title: "Cadence", values: cadenceScores, color: AppTheme.cyan)
                TrendCard(title: "Hip stability", values: hipScores, color: AppTheme.violet)
                ConsistencyCard(sessionCount: recentSessionCount)
            }
        }
    }

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Reports", subtitle: nil, systemImage: "doc.text")
            ForEach(appStore.history) { item in
                NavigationLink {
                    HistoryDetailView(item: item)
                } label: {
                    HistoryRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            IconBubble(systemImage: "clock.arrow.circlepath", gradient: AppTheme.purpleGradient, size: 76)
            VStack(spacing: 6) {
                Text("No analysis yet")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Analyze your first running video. Results and tester feedback will appear here.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 34)
            }
        }
    }
}

struct HistoryRow: View {
    let item: AnalysisHistoryItem

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center) {
                    IconBubble(systemImage: "figure.run", gradient: AppTheme.actionGradient, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(item.videoFilename)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    ConfidenceRingSmall(value: item.result.confidence)
                }

                Text(item.result.summary)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    MetricPill(text: "\(item.result.metrics.count) metrics", systemImage: "waveform.path.ecg")
                    if let feedback = item.feedback {
                        MetricPill(text: feedback.rating.rawValue, systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }
            }
        }
    }
}

struct ConfidenceRingSmall: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 5)
                .frame(width: 52, height: 52)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Trend components

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if values.count >= 2 {
                let minVal = values.min()!
                let maxVal = values.max()!
                let range = max(maxVal - minVal, 0.001)
                let step = w / CGFloat(values.count - 1)

                let pts: [CGPoint] = values.enumerated().map { i, v in
                    CGPoint(
                        x: CGFloat(i) * step,
                        y: h - CGFloat((v - minVal) / range) * (h - 6) - 3
                    )
                }

                ZStack {
                    // Area fill
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        p.addLine(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(color.opacity(0.18))

                    // Line
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Latest value dot
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(pts.last!)
                }
            } else {
                // Not enough data — dashed placeholder
                Rectangle()
                    .fill(color.opacity(0.25))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

struct TrendCard: View {
    let title: String
    let values: [Double]
    let color: Color

    private var latest: Double { values.last ?? 0 }
    // delta vs previous session
    private var delta: Double { values.count >= 2 ? latest - values[values.count - 2] : 0 }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)

                if values.isEmpty {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(Int(latest * 100))%")
                            .font(.title2.bold())
                            .foregroundStyle(color)
                        Spacer()
                        if abs(delta) > 0.005 {
                            Label(
                                "\(delta > 0 ? "+" : "")\(Int(delta * 100))%",
                                systemImage: delta > 0 ? "arrow.up.right" : "arrow.down.right"
                            )
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(delta > 0 ? AppTheme.mint : .red.opacity(0.80))
                        }
                    }
                    Sparkline(values: values, color: color)
                        .frame(height: 36)
                }
            }
        }
    }
}

struct ConsistencyCard: View {
    let sessionCount: Int

    private var label: String {
        switch sessionCount {
        case 0: return "No sessions yet"
        case 1: return "Good start!"
        case 2...3: return "Building habit"
        case 4...6: return "Staying consistent"
        default: return "Great consistency!"
        }
    }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Consistency")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))

                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(sessionCount)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.orange)
                    Text("days / 30d")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(.bottom, 2)
                }

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .frame(height: 36, alignment: .topLeading)
            }
        }
    }
}

struct HistoryDetailView: View {
    @EnvironmentObject private var appStore: AppStore
    let item: AnalysisHistoryItem

    private var currentItem: AnalysisHistoryItem { appStore.history.first(where: { $0.id == item.id }) ?? item }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        HStack(spacing: 14) {
                            IconBubble(systemImage: "doc.text.magnifyingglass", gradient: AppTheme.purpleGradient, size: 48)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(currentItem.createdAt, format: .dateTime.year().month().day().hour().minute())
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(currentItem.videoFilename)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                    }
                    AnalysisResultView(result: currentItem.result)
                    FeedbackView(historyItemID: currentItem.id)
                    if let feedback = currentItem.feedback {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 9) {
                                SectionTitle("Saved Feedback", subtitle: "Tester signal", systemImage: "bubble.left.and.bubble.right.fill")
                                Text(feedback.rating.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.mint)
                                if !feedback.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(feedback.comment)
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.66))
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
