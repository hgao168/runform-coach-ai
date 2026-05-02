import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if appStore.history.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(appStore.history) { item in
                                NavigationLink {
                                    HistoryDetailView(item: item)
                                } label: {
                                    HistoryRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
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
