import SwiftUI

struct ChallengeLeaderboardView: View {
    @EnvironmentObject private var appStore: AppStore
    let challengeID: String
    let challengeName: String

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            AppBackground()
            if appStore.leaderboard.isEmpty && appStore.challengeError == nil {
                DarkCard {
                    HStack(spacing: 14) {
                        ProgressView().tint(.white)
                        Text(String(localized: "Loading leaderboard..."))
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                }
                .padding(18)
            } else if let error = appStore.challengeError, appStore.leaderboard.isEmpty {
                DarkCard {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(AppTheme.orange)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button(String(localized: "Retry")) {
                            Task { await appStore.fetchLeaderboard(for: challengeID) }
                        }
                        .buttonStyle(GradientButtonStyle())
                    }
                    .padding(.vertical, 8)
                }
                .padding(18)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        headerCard

                        ForEach(Array(appStore.leaderboard.enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRow(entry: entry, rank: index + 1)
                        }

                        if appStore.leaderboard.isEmpty && appStore.challengeError == nil {
                            DarkCard {
                                VStack(spacing: 10) {
                                    Image(systemName: "person.3.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white.opacity(0.30))
                                    Text("No participants yet. Be the first!")
                                        .font(.callout)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.white.opacity(0.52))
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            Task { await appStore.fetchLeaderboard(for: challengeID) }
        }
    }

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(challengeName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(appStore.leaderboard.count) participants")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

struct LeaderboardRow: View {
    let entry: ChallengeLeaderboardEntry
    let rank: Int

    private var displayName: String {
        if let displayName = entry.displayName, !displayName.isEmpty {
            return displayName
        }
        if let name = entry.name, !name.isEmpty {
            return name
        }
        if let nickname = entry.nickname, !nickname.isEmpty {
            return nickname
        }
        return String(localized: "Runner \(rank)")
    }

    private var rankColor: Color {
        switch rank {
        case 1: return AppTheme.orange
        case 2: return AppTheme.cyan
        case 3: return AppTheme.mint
        default: return .white.opacity(0.30)
        }
    }

    private var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    var body: some View {
        DarkCard {
            HStack(spacing: 12) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(entry.isMe ? AppTheme.actionGradient : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Text(rankEmoji)
                        .font(rank <= 3 ? .title3 : .caption.bold())
                        .foregroundStyle(entry.isMe ? .black : .white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if entry.isMe {
                            StatusBadge(text: String(localized: "You"), color: AppTheme.mint)
                        }
                    }
                    HStack(spacing: 12) {
                        if let cadence = entry.cadenceImprovementPct {
                            Label(String(format: "%.1f%%", cadence), systemImage: "metronome")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        if let osc = entry.oscillationImprovementPct {
                            Label(String(format: "%.1f%%", osc), systemImage: "waveform.path")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Label("\(entry.completedDays)/\(entry.days)", systemImage: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.orange.opacity(0.8))
                    }
                }

                Spacer()

                if let score = entry.overallScoreChange {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%+.1f", score))
                            .font(.headline.bold())
                            .foregroundStyle(score >= 0 ? AppTheme.mint : AppTheme.orange)
                        Text(String(localized: "pts"))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
            }
        }
    }
}
