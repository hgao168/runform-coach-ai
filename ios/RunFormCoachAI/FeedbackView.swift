import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject private var appStore: AppStore
    let historyItemID: UUID

    @State private var rating: FeedbackRating = .partlyAccurate
    @State private var comment = ""
    @State private var saved = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle("Tester Feedback", subtitle: "Help improve coaching quality", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill")
                    Spacer()
                    if saved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.mint)
                    }
                }

                Picker("Rating", selection: $rating) {
                    ForEach(FeedbackRating.allCases) { rating in
                        Text(rating.rawValue).tag(rating)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.mint)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.09), lineWidth: 1))

                TextField("Optional comment: what was wrong or useful?", text: $comment, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(13)
                    .background(.black.opacity(0.20))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.09), lineWidth: 1))

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
