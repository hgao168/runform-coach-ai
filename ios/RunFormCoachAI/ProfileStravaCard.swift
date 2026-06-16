import SwiftUI

struct ProfileStravaCard: View {
    @EnvironmentObject private var appStore: AppStore

    @Binding var stravaMessage: String?
    @Binding var lastSyncedAt: Date?
    let isLoadingStravaStatus: Bool
    let isSyncingStravaRuns: Bool
    let isConnectingStrava: Bool

    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onSync: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    LocalizedStringKey("strava.card.title"),
                    subtitle: LocalizedStringKey("strava.card.subtitle"),
                    systemImage: "link.circle.fill"
                )

                if let status = appStore.stravaStatus, status.connected {
                    connectedSection(status: status)
                } else {
                    disconnectedSection
                }

                Text(String(localized: "strava.card.privacy"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.54))

                if isLoadingStravaStatus {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(AppTheme.mint)
                        Text(String(localized: "strava.card.checking"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                if let stravaMessage {
                    Text(stravaMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mint)
                }
            }
        }
    }

    @ViewBuilder
    private func connectedSection(status: StravaStatusResponse) -> some View {
        HStack(spacing: 12) {
            StatusBadge(text: String(localized: "strava.badge.connected"))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "strava.connected.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let athleteID = status.providerAthleteId {
                    Text(String(format: String(localized: "strava.athlete.id %@"), athleteID))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            Spacer()
        }

        if let scope = status.scope, !scope.isEmpty {
            Text(String(format: String(localized: "strava.scopes %@"), scope))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        }

        if let localSync = lastSyncedAt {
            Text(String(format: String(localized: "strava.last_sync %@"), localSync.formatted(.dateTime.month().day().hour().minute())))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        } else if let lastRefreshAt = status.lastRefreshAt, !lastRefreshAt.isEmpty {
            Text(String(format: String(localized: "strava.last_refresh %@"), lastRefreshAt))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        } else {
            Text(String(localized: "strava.last_refresh.unavailable"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        }

        Button {
            onSync()
        } label: {
            Label(
                isSyncingStravaRuns
                    ? String(localized: "strava.button.syncing")
                    : String(localized: "strava.button.sync"),
                systemImage: "arrow.triangle.2.circlepath"
            )
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isSyncingStravaRuns || isConnectingStrava)

        Button(role: .destructive) {
            onDisconnect()
        } label: {
            Label(String(localized: "strava.button.disconnect"), systemImage: "link.slash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
    }

    @ViewBuilder
    private var disconnectedSection: some View {
        Text(String(localized: "strava.disconnected.body"))
            .font(.callout)
            .foregroundStyle(.white.opacity(0.66))

        Button {
            onConnect()
        } label: {
            Label(
                isConnectingStrava
                    ? String(localized: "strava.button.connecting")
                    : String(localized: "strava.button.connect"),
                systemImage: "link"
            )
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isConnectingStrava)
    }
}
