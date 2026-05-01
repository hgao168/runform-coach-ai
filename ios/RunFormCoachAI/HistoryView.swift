import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if appStore.history.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView {
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
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !appStore.history.isEmpty {
                    Button("Clear") { showClearConfirmation = true }
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
        VStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 54))
                .foregroundStyle(AppTheme.cyan)
            Text("No analysis yet")
                .font(.title2.bold())
            Text("Analyze your first running video. Results and tester feedback will appear here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
        }
    }
}

struct HistoryRow: View {
    let item: AnalysisHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.headline)
                    Text(item.videoFilename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(item.result.confidence * 100))%")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.deepBlue)
            }
            Text(item.result.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let feedback = item.feedback {
                Label(feedback.rating.rawValue, systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

struct HistoryDetailView: View {
    @EnvironmentObject private var appStore: AppStore
    let item: AnalysisHistoryItem

    private var currentItem: AnalysisHistoryItem { appStore.history.first(where: { $0.id == item.id }) ?? item }

    var body: some View {
        ZStack {
            AppTheme.heroGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(currentItem.createdAt, format: .dateTime.year().month().day().hour().minute())
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(currentItem.videoFilename)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    AnalysisResultView(result: currentItem.result)
                    FeedbackView(historyItemID: currentItem.id)
                    if let feedback = currentItem.feedback {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Saved Feedback")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(feedback.rating.rawValue)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.mint)
                                if !feedback.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(feedback.comment)
                                        .foregroundStyle(.white.opacity(0.66))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
