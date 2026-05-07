import SwiftUI

// ── Entry point — presented as a sheet from AnalysisResultView ───────────────

struct CompareView: View {
    let poseMetrics: PoseMetrics

    @Environment(\.dismiss) private var dismiss
    @State private var athletes: [AthleteListItem] = []
    @State private var isLoadingAthletes = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if isLoadingAthletes {
                        ProgressView()
                            .tint(AppTheme.mint)
                            .scaleEffect(1.4)
                    } else if let error = loadError {
                        VStack(spacing: 14) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.orange)
                            Text("Couldn't Load Athletes")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.62))
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                    } else {
                        athleteList
                    }
                }
            }
            .navigationTitle("Compare with Elite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.mint)
                }
            }
        }
        .task { await loadAthletes() }
        .preferredColorScheme(.dark)
    }

    private var athleteList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pick an athlete to compare your form against their elite biomechanical benchmarks.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.70))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 18)

                VStack(spacing: 0) {
                    ForEach(athletes) { athlete in
                        NavigationLink {
                            CompareResultView(poseMetrics: poseMetrics, athlete: athlete)
                        } label: {
                            AthleteRowView(athlete: athlete)
                        }
                        .buttonStyle(.plain)

                        if athlete.id != athletes.last?.id {
                            Divider()
                                .background(.white.opacity(0.10))
                                .padding(.horizontal, 18)
                        }
                    }
                }
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
    }

    private func loadAthletes() async {
        isLoadingAthletes = true
        loadError = nil
        do {
            athletes = try await APIClient.shared.fetchAthletes()
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingAthletes = false
    }
}

// ── Athlete row ───────────────────────────────────────────────────────────────

struct AthleteRowView: View {
    let athlete: AthleteListItem

    private var initials: String {
        athlete.name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.actionGradient)
                    .frame(width: 50, height: 50)
                Text(initials)
                    .font(.headline.bold())
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(athlete.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(athlete.event)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.mint)
                Text(athlete.achievement)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.30))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

// ── Comparison result ─────────────────────────────────────────────────────────

struct CompareResultView: View {
    let poseMetrics: PoseMetrics
    let athlete: AthleteListItem

    @State private var result: CompareResponse?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(AppTheme.mint)
                            .scaleEffect(1.4)
                        Text("Comparing your form...")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                } else if let error {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.orange)
                        Text("Comparison Failed")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else if let result {
                    resultScroll(result: result)
                }
            }
        }
        .navigationTitle(athlete.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await runComparison() }
    }

    private func resultScroll(result: CompareResponse) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                similarityCard(result: result)
                if !result.coachingNarrative.isEmpty {
                    narrativeCard(text: result.coachingNarrative)
                }
                if !result.topGaps.isEmpty {
                    topGapsCard(gaps: result.topGaps)
                }
                metricsSection(comparisons: result.comparisons)
                athleteBioCard(profile: result.athlete)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
    }

    // ── Similarity ring card ─────────────────────────────────────────────────

    private func similarityCard(result: CompareResponse) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.actionGradient)
                        .frame(width: 54, height: 54)
                    Text(result.athlete.name
                        .split(separator: " ")
                        .compactMap { $0.first }
                        .prefix(2)
                        .map(String.init)
                        .joined())
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.athlete.name)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(result.athlete.event)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mint)
                    Text(result.athlete.achievement)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
                Spacer()
                // Similarity ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 8)
                        .frame(width: 76, height: 76)
                    Circle()
                        .trim(from: 0, to: result.overallSimilarityScore)
                        .stroke(AppTheme.warmGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(Int(result.overallSimilarityScore * 100))%")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text("match")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
    }

    // ── GPT coaching narrative ────────────────────────────────────────────────

    private func narrativeCard(text: String) -> some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Coach's Take", systemImage: "quote.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.mint)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ── Top gaps ──────────────────────────────────────────────────────────────

    private func topGapsCard(gaps: [String]) -> some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Biggest Gaps", systemImage: "arrow.up.forward.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(gaps, id: \.self) { gap in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppTheme.orange)
                                .frame(width: 7, height: 7)
                            Text(gap)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                }
            }
        }
    }

    // ── Per-metric comparison bars ────────────────────────────────────────────

    private func metricsSection(comparisons: [MetricComparison]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metric Breakdown")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(comparisons) { comp in
                MetricComparisonRow(comparison: comp)
            }
        }
    }

    // ── Athlete bio ───────────────────────────────────────────────────────────

    private func athleteBioCard(profile: AthleteProfile) -> some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("About \(profile.name)", systemImage: "person.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(profile.bio)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(profile.nationality) · \(profile.event)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.mint)
            }
        }
    }

    private func runComparison() async {
        isLoading = true
        error = nil
        do {
            result = try await APIClient.shared.compareWithAthlete(
                athleteId: athlete.id,
                metrics: poseMetrics
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// ── Metric comparison row ─────────────────────────────────────────────────────

struct MetricComparisonRow: View {
    let comparison: MetricComparison

    private var statusColor: Color {
        switch comparison.status {
        case "ahead": return AppTheme.mint
        case "on_par": return AppTheme.cyan
        default: return AppTheme.orange
        }
    }

    private var statusIcon: String {
        switch comparison.status {
        case "ahead": return "arrow.up.circle.fill"
        case "on_par": return "checkmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: icon + metric name + labels
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.caption.weight(.bold))
                Text(comparison.metric)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Text(comparison.userLabel)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.cyan)
                    Text("vs")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.40))
                    Text(comparison.athleteLabel)
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.orange)
                }
            }

            // Dual bar: user fills from left, athlete marker is a vertical tick
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .frame(height: 8)
                    // User score bar
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.actionGradient)
                        .frame(
                            width: geo.size.width * max(0, min(1, comparison.userScore)),
                            height: 8
                        )
                    // Athlete benchmark tick
                    Rectangle()
                        .fill(AppTheme.orange)
                        .frame(width: 2, height: 16)
                        .offset(
                            x: geo.size.width * max(0, min(1, comparison.athleteScore)) - 1,
                            y: -4
                        )
                }
            }
            .frame(height: 8)

            // Legend
            HStack {
                Circle().fill(AppTheme.cyan).frame(width: 6, height: 6)
                Text("You")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
                Spacer()
                Rectangle().fill(AppTheme.orange).frame(width: 10, height: 2)
                Text("Elite benchmark")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .padding(15)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
