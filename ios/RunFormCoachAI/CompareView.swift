import SwiftUI

// ── Entry point — presented as a sheet from AnalysisResultView ───────────────

struct CompareView: View {
    let poseMetrics: PoseMetrics

    @Environment(\.dismiss) private var dismiss
    @State private var athletes: [AthleteListItem] = []
    @State private var isLoadingAthletes = true
    @State private var loadError: String?
    @State private var selectedTab: CompareTab = .elite
    @State private var showVideoPicker = false
    @State private var isAnalyzingCustomAthlete = false
    @State private var customAthleteMetrics: PoseMetrics?
    @State private var customAthleteAnalysis: AnalysisResponse?
    @State private var customAthleteError: String?

    enum CompareTab {
        case elite
        case custom
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if selectedTab == .elite {
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
                    } else {
                        customAthleteView
                    }
                }
            }
            .navigationTitle("Compare with Elite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        Button(action: { selectedTab = .elite }) {
                            Text("Elite Athletes")
                                .font(.headline)
                                .foregroundStyle(selectedTab == .elite ? AppTheme.mint : .white.opacity(0.50))
                                .frame(maxWidth: .infinity)
                        }
                        Divider()
                            .frame(width: 2, height: 20)
                            .overlay(.white.opacity(0.42))
                        Button(action: { selectedTab = .custom }) {
                            Text("Add Any Athlete")
                                .font(.headline)
                                .foregroundStyle(selectedTab == .custom ? AppTheme.mint : .white.opacity(0.50))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.mint)
                }
            }
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker { url in
                Task {
                    await analyzeCustomAthleteVideo(url)
                }
            }
        }
        .task { await loadAthletes() }
        .preferredColorScheme(.dark)
    }

    private var customAthleteView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Upload an athlete's video and compare your biomechanics against theirs.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.70))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                if isAnalyzingCustomAthlete {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(AppTheme.mint)
                            .scaleEffect(1.4)
                        Text("Analyzing athlete video...")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 18)
                } else if let error = customAthleteError {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.orange)
                        Text("Analysis Failed")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                } else if customAthleteMetrics != nil {
                    NavigationLink {
                        CustomCompareResultView(
                            poseMetrics: poseMetrics,
                            athleteAnalysis: customAthleteAnalysis!
                        )
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.headline)
                            Text("View Comparison Results")
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
                    .padding(.horizontal, 18)
                }

                Button(action: { showVideoPicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.mint)
                        Text("Upload Athlete Video")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("MP4 or MOV format")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
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

    private func analyzeCustomAthleteVideo(_ videoURL: URL) async {
        isAnalyzingCustomAthlete = true
        customAthleteError = nil
        customAthleteMetrics = nil
        customAthleteAnalysis = nil
        do {
            customAthleteAnalysis = try await APIClient.shared.analyzeVideo(fileURL: videoURL)
            customAthleteMetrics = PoseMetrics(
                cadenceEstimateSPM: 170,
                cadenceScore: 0.8,
                cadenceStatus: "good",
                overstrideRiskScore: 0.6,
                overstrideStatus: "warning",
                trunkLeanDegrees: 5,
                trunkLeanScore: 0.75,
                trunkLeanStatus: "good",
                kneeValgusRiskScore: 0.4,
                kneeValgusStatus: "good",
                verticalOscillationScore: 0.7,
                verticalOscillationStatus: "good",
                shoulderElevationScore: 0.8,
                shoulderElevationStatus: "good",
                armSwingScore: 0.75,
                armSwingStatus: "good",
                armCrossingScore: 0.65,
                armCrossingStatus: "warning",
                armCrossingDirection: "center",
                backwardElbowDriveScore: 0.78,
                backwardElbowDriveStatus: "good",
                backwardElbowDriveAngleDegrees: 85,
                elbowAngleScore: 0.72,
                elbowAngleStatus: "good",
                elbowAngleDegrees: 92,
                shoulderArmIndependenceScore: 0.76,
                shoulderArmIndependenceStatus: "good",
                pelvicDropScore: 0.68,
                pelvicDropStatus: "warning",
                stepSymmetryScore: 0.82,
                stepSymmetryStatus: "excellent",
                headForwardScore: 0.74,
                headForwardStatus: "good",
                postureScore: 0.79,
                efficiencyScore: 0.77,
                stabilityScore: 0.73,
                propulsionScore: 0.75,
                armMechanicsScore: 0.74,
                symmetryScore: 0.80,
                injuryRiskScore: 0.35,
                frameCount: 300,
                videoDurationSeconds: 10.0,
                notes: [],
                videoQualityScore: 0.85,
                poseDetectionRate: 0.95,
                qualityNotes: []
            )
        } catch {
            customAthleteError = error.localizedDescription
            customAthleteMetrics = nil
            customAthleteAnalysis = nil
        }
        isAnalyzingCustomAthlete = false
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

// ── Custom Athlete Comparison ──────────────────────────────────────────────────

struct CustomCompareResultView: View {
    let poseMetrics: PoseMetrics
    let athleteAnalysis: AnalysisResponse

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    similarityCard
                    summaryCard
                    metricsComparisonSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Athlete Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var similarityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Form")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Confidence Score")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 6)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: poseMetrics.efficiencyScore)
                            .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(poseMetrics.efficiencyScore * 100))")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }

                Divider()
                    .background(.white.opacity(0.10))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Athlete's Form")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Confidence Score")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 6)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: athleteAnalysis.confidence)
                            .stroke(AppTheme.warmGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(athleteAnalysis.confidence * 100))")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Athlete Analysis", systemImage: "doc.text")
                    .font(.headline)
                    .foregroundStyle(AppTheme.mint)
                Text(athleteAnalysis.summary)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metricsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metrics Detected")
                .font(.headline)
                .foregroundStyle(.white)

            if athleteAnalysis.metrics.isEmpty {
                Text("No metrics detected in athlete's video")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            } else {
                ForEach(athleteAnalysis.metrics.prefix(8)) { metric in
                    athleteMetricRow(metric: metric)
                }
            }
        }
    }

    private func athleteMetricRow(metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: statusIcon(for: metric.status))
                    .foregroundStyle(statusColor(for: metric.status))
                    .font(.caption.weight(.bold))
                Text(metric.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(metric.score * 100))")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.orange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.actionGradient)
                        .frame(
                            width: geo.size.width * max(0, min(1, metric.score)),
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            if !metric.explanation.isEmpty {
                Text(metric.explanation)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(15)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statusIcon(for status: String) -> String {
        switch status.lowercased() {
        case "excellent", "great": return "checkmark.circle.fill"
        case "good", "fair": return "checkmark.circle.fill"
        case "warning", "poor": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "excellent", "great": return AppTheme.mint
        case "good", "fair": return AppTheme.cyan
        case "warning", "poor": return AppTheme.orange
        default: return .white.opacity(0.62)
        }
    }
}
