import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject private var appStore: AppStore
    let historyItemID: UUID

    @State private var rating: FeedbackRating = .partlyAccurate
    @State private var comment = ""
    @State private var saved = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Tester Feedback", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if saved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.mint)
                    }
                }

                Text("Rate whether this result feels correct so Phase 2 pose analysis can improve.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Picker("Rating", selection: $rating) {
                    ForEach(FeedbackRating.allCases) { rating in
                        Text(rating.rawValue).tag(rating)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.mint)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                TextField("Optional comment: what was wrong or useful?", text: $comment, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(.white.opacity(0.09))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    let feedback = AnalysisFeedback(id: UUID(), rating: rating, comment: comment, createdAt: Date())
                    appStore.updateFeedback(for: historyItemID, feedback: feedback)
                    saved = true
                } label: {
                    Label(saved ? "Feedback Saved" : "Save Feedback", systemImage: saved ? "checkmark.circle.fill" : "square.and.pencil")
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
    }
}
