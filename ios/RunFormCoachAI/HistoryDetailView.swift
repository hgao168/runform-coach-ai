import SwiftUI

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
                    NavigationLink {
                        CompareHistoryView(item: currentItem)
                    } label: {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.headline)
                            Text("Compare with Elite Athletes")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(AppTheme.actionGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
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
