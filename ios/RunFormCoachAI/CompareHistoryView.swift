import SwiftUI

// ── Compare History with Elite Athletes ────────────────────────────────────────

struct CompareHistoryView: View {
    let item: AnalysisHistoryItem

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
        }
        .task { await loadAthletes() }
        .preferredColorScheme(.dark)
    }

    private var athleteList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Compare your recorded analysis against elite athlete biomechanical benchmarks.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.70))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 18)

                VStack(spacing: 0) {
                    ForEach(athletes) { athlete in
                        NavigationLink {
                            CompareHistoryResultView(analysis: item.result, athlete: athlete)
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

// ── History Comparison Result ──────────────────────────────────────────────────

struct CompareHistoryResultView: View {
    let analysis: AnalysisResponse
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
                        Text("Comparing form...")
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
                analysisComparisonCard
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

    private var analysisComparisonCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Recording")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Confidence")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 5)
                            .frame(width: 52, height: 52)
                        Circle()
                            .trim(from: 0, to: analysis.confidence)
                            .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(analysis.confidence * 100))")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func similarityCard(result: CompareResponse) -> some View {
        GlassCard {
            HStack(spacing: 14) {
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
            let tempMetrics = createPoseMetricsFromAnalysis(analysis)
            result = try await APIClient.shared.compareWithAthlete(
                athleteId: athlete.id,
                metrics: tempMetrics
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func createPoseMetricsFromAnalysis(_ analysis: AnalysisResponse) -> PoseMetrics {
        let confidence = analysis.confidence

        return PoseMetrics(
            cadenceEstimateSPM: 170,
            cadenceScore: confidence,
            cadenceStatus: "good",
            overstrideRiskScore: max(0, 1 - confidence),
            overstrideStatus: "warning",
            trunkLeanDegrees: 5,
            trunkLeanScore: confidence,
            trunkLeanStatus: "good",
            kneeValgusRiskScore: max(0, 1 - confidence),
            kneeValgusStatus: "good",
            verticalOscillationScore: confidence,
            verticalOscillationStatus: "good",
            shoulderElevationScore: confidence,
            shoulderElevationStatus: "good",
            armSwingScore: confidence,
            armSwingStatus: "good",
            armCrossingScore: confidence * 0.8,
            armCrossingStatus: "warning",
            armCrossingDirection: "center",
            backwardElbowDriveScore: confidence,
            backwardElbowDriveStatus: "good",
            backwardElbowDriveAngleDegrees: 85,
            elbowAngleScore: confidence * 0.9,
            elbowAngleStatus: "good",
            elbowAngleDegrees: 92,
            shoulderArmIndependenceScore: confidence,
            shoulderArmIndependenceStatus: "good",
            pelvicDropScore: confidence * 0.85,
            pelvicDropStatus: "warning",
            stepSymmetryScore: confidence * 1.0,
            stepSymmetryStatus: "excellent",
            headForwardScore: confidence * 0.92,
            headForwardStatus: "good",
            postureScore: confidence * 0.98,
            efficiencyScore: confidence,
            stabilityScore: confidence * 0.9,
            propulsionScore: confidence * 0.93,
            armMechanicsScore: confidence * 0.92,
            symmetryScore: confidence * 1.0,
            injuryRiskScore: max(0, 1 - confidence),
            frameCount: 300,
            videoDurationSeconds: 10.0,
            notes: [],
            videoQualityScore: 0.85,
            poseDetectionRate: 0.95,
            qualityNotes: []
        )
    }
}
