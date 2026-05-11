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
