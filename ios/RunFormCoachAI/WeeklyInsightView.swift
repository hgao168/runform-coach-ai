import SwiftUI

// MARK: - Weekly Insight View (RUNFORM-706)

struct WeeklyInsightView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var state: WeeklyInsightState = .loading

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection

                    switch state {
                    case .loading:
                        loadingView
                    case .error(let message):
                        errorView(message: message)
                    case .success(let data):
                        successContent(data: data)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Weekly Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { loadTrends() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Weekly Insights")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Your training trends at a glance")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Button { loadTrends() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(10)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(AppTheme.mint)
                .scaleEffect(1.2)
                .padding(.top, 80)
            Text("Loading weekly insights…")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private func errorView(message: String) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(AppTheme.orange)
                Text("Unable to load insights")
                    .font(.headline)
                    .foregroundStyle(AppTheme.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                Button { loadTrends() } label: {
                    Text("Retry")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AppTheme.mint)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Success Content

    @ViewBuilder
    private func successContent(data: WeeklyTrendsResponse) -> some View {
        // ── 1. Week-over-week comparisons ───────────────────────
        SectionTitle(
            "Week over Week",
            subtitle: nil,
            systemImage: "arrow.left.arrow.right"
        )

        DeltaMetricCard(
            label: "Cadence",
            currentValue: data.currentWeek.avgCadenceSPM,
            previousValue: data.previousWeek.avgCadenceSPM,
            unit: "SPM",
            invertGood: false,
            color: AppTheme.cyan,
            description: "Higher cadence reduces overstride risk"
        )

        DeltaMetricCard(
            label: "Vertical Oscillation",
            currentValue: data.currentWeek.avgAmplitudeCm,
            previousValue: data.previousWeek.avgAmplitudeCm,
            unit: "cm",
            invertGood: true,
            color: AppTheme.mint,
            description: "Lower oscillation = more efficient stride"
        )

        DeltaMetricCard(
            label: "Ground Contact Time",
            currentValue: data.currentWeek.avgGCTMs,
            previousValue: data.previousWeek.avgGCTMs,
            unit: "ms",
            invertGood: true,
            color: AppTheme.violet,
            description: "Shorter GCT = faster turnover"
        )

        // ── 2. Weekly stats ────────────────────────────────────
        SectionTitle(
            "Weekly Stats",
            subtitle: nil,
            systemImage: "chart.bar.fill"
        )
        GlassCard {
            HStack(spacing: 0) {
                StatBadge(
                    label: "Distance",
                    value: String(format: "%.1f km", data.currentWeek.totalDistanceKm),
                    color: AppTheme.mint
                )
                Spacer()
                StatBadge(
                    label: "Sessions",
                    value: "\(data.currentWeek.totalSessions)",
                    color: AppTheme.cyan
                )
                Spacer()
                StatBadge(
                    label: "Duration",
                    value: String(format: "%.0f min", data.currentWeek.totalDurationMin),
                    color: AppTheme.violet
                )
            }
        }

        // ── 3. Achievement Badges ──────────────────────────────
        if !data.badges.isEmpty {
            SectionTitle(
                "Achievements",
                subtitle: nil,
                systemImage: "trophy.fill"
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(data.badges) { badge in
                        BadgeCard(badge: badge)
                            .frame(width: 160)
                    }
                }
            }
        }

        // ── 4. AI Coaching Suggestion ─────────────────────────
        if let suggestion = data.aiSuggestion, !suggestion.isEmpty {
            SectionTitle(
                "AI Coach",
                subtitle: nil,
                systemImage: "brain.head.profile"
            )
            GlassCard {
                HStack(alignment: .top, spacing: 12) {
                    Text("💡")
                        .font(.title3)
                    Text(suggestion)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .lineSpacing(4)
                }
            }
        }

        // ── 5. Weekly Trend Mini-Bars ─────────────────────────
        if data.weeklyTrends.count >= 2 {
            SectionTitle(
                "4-Week Trends",
                subtitle: nil,
                systemImage: "chart.line.uptrend.xyaxis"
            )
            GlassCard {
                WeeklyTrendMiniBars(trends: data.weeklyTrends)
            }
        }

        // Bottom spacer
        Spacer().frame(height: 24)
    }

    // MARK: - Data Loading

    private func loadTrends() {
        state = .loading
        Task {
            do {
                let response = try await APIClient.shared.fetchWeeklyTrends()
                await MainActor.run {
                    state = .success(response)
                }
            } catch {
                await MainActor.run {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Delta Metric Card

private struct DeltaMetricCard: View {
    let label: String
    let currentValue: Double
    let previousValue: Double
    let unit: String
    let invertGood: Bool
    let color: Color
    let description: String

    private var delta: MetricDelta {
        computeDelta(current: currentValue, previous: previousValue, unit: unit, invertGood: invertGood)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                // Header row: label + trend direction
                HStack {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                    Spacer()
                    HStack(spacing: 4) {
                        Text(directionLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(directionColor)
                        Image(systemName: arrowImage)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(directionColor)
                    }
                }

                // Main value row
                HStack(alignment: .bottom, spacing: 6) {
                    Text(String(format: "%.1f", currentValue))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 4)
                    Spacer()
                    // Delta badge
                    Text(deltaLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(directionColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(directionColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Previous value reference + percentage
                HStack(spacing: 6) {
                    Text("Last week: \(String(format: "%.1f", previousValue)) \(unit)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                    Text("(\(String(format: "%+.1f", delta.deltaPct))%)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(directionColor)
                }

                // Description
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.38))
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
    }

    private var directionColor: Color {
        switch delta.direction {
        case .up: return AppTheme.mint
        case .down: return .red.opacity(0.82)
        case .flat: return .white.opacity(0.50)
        }
    }

    private var directionLabel: String {
        switch delta.direction {
        case .up: return "Improving"
        case .down: return "Declining"
        case .flat: return "Stable"
        }
    }

    private var arrowImage: String {
        switch delta.direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    private var deltaLabel: String {
        let prefix = delta.direction == .up ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", delta.delta)) \(unit)"
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
        }
    }
}

// MARK: - Badge Card

private struct BadgeCard: View {
    let badge: UserBadge

    var body: some View {
        DarkCard {
            VStack(spacing: 8) {
                // Badge icon
                ZStack {
                    Circle()
                        .fill(AppTheme.mint.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.mint.opacity(0.3), lineWidth: 1)
                        )
                    Text(badge.badgeIcon.isEmpty ? "🏅" : badge.badgeIcon)
                        .font(.title2)
                }

                Text(badge.badgeName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(badge.badgeDescription)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Weekly Trend Mini-Bars

private struct WeeklyTrendMiniBars: View {
    let trends: [WeekSummary]

    var body: some View {
        VStack(spacing: 14) {
            TrendBarRow(
                title: "Cadence (SPM)",
                values: trends.map(\.avgCadenceSPM),
                color: AppTheme.cyan,
                unit: "SPM",
                formatter: { String(format: "%.0f", $0) }
            )
            TrendBarRow(
                title: "Vert. Osc. (cm)",
                values: trends.map(\.avgAmplitudeCm),
                color: AppTheme.mint,
                unit: "cm",
                formatter: { String(format: "%.1f", $0) },
                invertGood: true
            )
            TrendBarRow(
                title: "GCT (ms)",
                values: trends.map(\.avgGCTMs),
                color: AppTheme.violet,
                unit: "ms",
                formatter: { String(format: "%.0f", $0) },
                invertGood: true
            )
            TrendBarRow(
                title: "Distance (km)",
                values: trends.map(\.totalDistanceKm),
                color: AppTheme.orange,
                unit: "km",
                formatter: { String(format: "%.1f", $0) }
            )
        }
    }
}

private struct TrendBarRow: View {
    let title: String
    let values: [Double]
    let color: Color
    let unit: String
    let formatter: (Double) -> String
    var invertGood: Bool = false

    private var maxVal: Double { values.max() ?? 1.0 }
    private var minVal: Double { values.min() ?? 0.0 }
    private var range: Double {
        let r = maxVal - minVal
        return r < 0.001 ? 1.0 : r
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
                Text("\(formatter(values.last ?? 0)) \(unit)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    let isLast = i == values.count - 1
                    let fraction = CGFloat(((v - minVal) / range).clamped(to: 0.02...1.0))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color.opacity(isLast ? 1.0 : 0.4))
                        .frame(height: 24 * fraction)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 24)
        }
    }
}

// MARK: - Helper

extension CGFloat {
    func clamped(to limits: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
