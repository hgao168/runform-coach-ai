import SwiftUI

struct ChallengeDetailView: View {
    @EnvironmentObject private var appStore: AppStore
    let challenge: ChallengeInfo

    @State private var currentChallenge: ChallengeInfo
    @State private var showedCheckInSuccess = false
    @State private var lastCheckInMessage: String?

    init(challenge: ChallengeInfo) {
        self.challenge = challenge
        _currentChallenge = State(initialValue: challenge)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    progressCard
                    actionCard
                    if currentChallenge.isActive && currentChallenge.joined == true {
                        leaderboardPreview
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle(currentChallenge.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: appStore.selectedChallenge) { _, new in
            if let new, new.id == currentChallenge.id {
                currentChallenge = new
            }
        }
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        StatusBadge(
                            text: currentChallenge.isActive ? String(localized: "Active") : String(localized: "Ended"),
                            color: currentChallenge.isActive ? AppTheme.mint : Color.white.opacity(0.25)
                        )
                        Text(currentChallenge.description)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if let joined = currentChallenge.joined, joined {
                        IconBubble(systemImage: "checkmark.seal.fill", gradient: AppTheme.actionGradient, size: 50)
                    } else {
                        IconBubble(systemImage: "flag.fill", gradient: AppTheme.warmGradient, size: 50)
                    }
                }

                HStack(spacing: 20) {
                    statItem(value: "\(currentChallenge.days)", label: String(localized: "Days"))
                    statItem(value: "\(currentChallenge.participantCount)", label: String(localized: "Runners"))
                    if let joined = currentChallenge.joined, joined, let completed = currentChallenge.completedDays {
                        statItem(value: "\(completed)", label: String(localized: "Your days"))
                    }
                }
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    private var progressCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    "Your Progress",
                    subtitle: currentChallenge.joined == true ? String(localized: "Keep stacking days") : String(localized: "Join to start tracking"),
                    systemImage: "chart.bar.fill"
                )

                if let joined = currentChallenge.joined, joined {
                    let completed = currentChallenge.completedDays ?? 0
                    let total = currentChallenge.days
                    let progress = total > 0 ? Double(completed) / Double(total) : 0

                    VStack(spacing: 8) {
                        HStack {
                            Text("\(completed) / \(total) days")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.mint)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.white.opacity(0.10))
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(AppTheme.actionGradient)
                                    .frame(width: max(12, geo.size.width * progress), height: 12)
                            }
                        }
                        .frame(height: 12)

                        if let today = currentChallenge.todayCompleted, today {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.mint)
                                Text("Today's check-in complete!")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mint)
                            }
                            .padding(.top, 4)
                        }
                    }
                } else {
                    Text("Join the challenge to start tracking your daily progress and compete on the leaderboard.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
    }

    private var actionCard: some View {
        VStack(spacing: 10) {
            if let error = appStore.challengeError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let message = lastCheckInMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.mint)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mint)
                }
                .padding(12)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if currentChallenge.isActive {
                if currentChallenge.joined == true {
                    Button {
                        Task {
                            await appStore.checkIn(for: currentChallenge.id)
                            if appStore.challengeError == nil {
                                lastCheckInMessage = String(localized: "Check-in recorded! Streak continues.")
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if appStore.isJoiningChallenge {
                                ProgressView().tint(.black)
                            }
                            Label(
                                currentChallenge.todayCompleted == true
                                    ? String(localized: "Already checked in today")
                                    : String(localized: "Check In Today"),
                                systemImage: "checkmark.seal.fill"
                            )
                        }
                    }
                    .buttonStyle(GradientButtonStyle(disabled: appStore.isJoiningChallenge || currentChallenge.todayCompleted == true))
                    .disabled(appStore.isJoiningChallenge || currentChallenge.todayCompleted == true)
                } else {
                    Button {
                        Task { await appStore.joinChallenge(challengeID: currentChallenge.id) }
                    } label: {
                        HStack(spacing: 10) {
                            if appStore.isJoiningChallenge {
                                ProgressView().tint(.black)
                            }
                            Label(String(localized: "Join Challenge"), systemImage: "person.badge.plus")
                        }
                    }
                    .buttonStyle(GradientButtonStyle(disabled: appStore.isJoiningChallenge))
                    .disabled(appStore.isJoiningChallenge)
                }
            } else {
                SecondaryButton {
                    // Already ended — no action
                } label: {
                    Label(String(localized: "Challenge Ended"), systemImage: "flag.checkered")
                }
            }
        }
    }

    private var leaderboardPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                "Leaderboard",
                subtitle: String(localized: "Top performers"),
                systemImage: "list.number"
            )
            NavigationLink {
                ChallengeLeaderboardView(challengeID: currentChallenge.id, challengeName: currentChallenge.name)
            } label: {
                DarkCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("View full leaderboard")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("See how you stack up against other runners")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.52))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.30))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct SecondaryButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(SecondaryButtonStyle())
    }
}
