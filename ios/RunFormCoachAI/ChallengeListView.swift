import SwiftUI

struct ChallengeListView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                content
            }
            .navigationTitle(String(localized: "Challenges"))
        }
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            await appStore.fetchChallenges()
        }
    }

    @ViewBuilder
    private var content: some View {
        if appStore.isFetchingChallenges {
            ProgressView()
                .tint(.white)
        } else if let error = appStore.challengeError, appStore.challenges.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(error)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button(String(localized: "Retry")) {
                    Task { await appStore.fetchChallenges() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 60)
            }
        } else if appStore.challenges.isEmpty {
            Text(String(localized: "No challenges available yet."))
                .foregroundStyle(.white.opacity(0.5))
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let error = appStore.challengeError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal)
                    }
                    ForEach(appStore.challenges) { challenge in
                        NavigationLink {
                            ChallengeDetailView(challenge: challenge)
                        } label: {
                            ChallengeRow(challenge: challenge)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Challenge Row

private struct ChallengeRow: View {
    let challenge: ChallengeInfo

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(challenge.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                    }
                    Spacer()
                    StatusBadge(
                        text: challenge.isActive
                            ? String(localized: "Active")
                            : String(localized: "Ended"),
                        color: challenge.isActive ? AppTheme.mint : .gray
                    )
                }

                HStack(spacing: 20) {
                    metricItem(icon: "calendar", label: String(localized: "Duration"), value: "\(challenge.days)d")
                    metricItem(icon: "person.2.fill", label: String(localized: "Joined"), value: "\(challenge.participantCount)")
                    if let joined = challenge.joined, joined {
                        metricItem(icon: "checkmark.circle.fill", label: String(localized: "Progress"), value: "\(challenge.completedDays ?? 0)/\(challenge.days)")
                    }
                }

                if let joined = challenge.joined {
                    HStack {
                        Image(systemName: joined ? "checkmark.seal.fill" : "plus.circle")
                            .foregroundStyle(joined ? AppTheme.mint : .white.opacity(0.6))
                        Text(joined
                            ? String(localized: "You\'ve joined")
                            : String(localized: "Join challenge"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(joined ? AppTheme.mint : .white.opacity(0.8))
                    }
                }
            }
        }
    }

    private func metricItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}
