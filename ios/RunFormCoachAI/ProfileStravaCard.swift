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
                SectionTitle("Connect Strava", subtitle: "Bring weekly load into future plans", systemImage: "link.circle.fill")

                if let status = appStore.stravaStatus, status.connected {
                    connectedSection(status: status)
                } else {
                    disconnectedSection
                }

                Text("Strava data is used only for your coaching and plan generation. It is not used to train AI models.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.54))

                if isLoadingStravaStatus {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(AppTheme.mint)
                        Text("Checking Strava connection…")
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
            StatusBadge(text: "Connected")
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected with Strava")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let athleteID = status.providerAthleteId {
                    Text("Athlete ID: \(athleteID)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            Spacer()
        }

        if let scope = status.scope, !scope.isEmpty {
            Text("Scopes: \(scope)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        }

        if let localSync = lastSyncedAt {
            Text("Last sync: \(localSync.formatted(.dateTime.month().day().hour().minute()))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        } else if let lastRefreshAt = status.lastRefreshAt, !lastRefreshAt.isEmpty {
            Text("Last refresh: \(lastRefreshAt)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        } else {
            Text("Last refresh: not available yet")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
        }

        Button {
            onSync()
        } label: {
            Label(isSyncingStravaRuns ? "Syncing runs…" : "Sync runs from Strava", systemImage: "arrow.triangle.2.circlepath")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isSyncingStravaRuns || isConnectingStrava)

        Button(role: .destructive) {
            onDisconnect()
        } label: {
            Label("Disconnect Strava", systemImage: "link.slash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
    }

    @ViewBuilder
    private var disconnectedSection: some View {
        Text("Connect Strava to bring your weekly load into future plan suggestions.")
            .font(.callout)
            .foregroundStyle(.white.opacity(0.66))

        Button {
            onConnect()
        } label: {
            Label(isConnectingStrava ? "Connecting…" : "Connect Strava", systemImage: "link")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isConnectingStrava)
    }
}
