import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var showClearConfirmation = false

    // Chronological order for trend lines (oldest → newest)
    private var sorted: [AnalysisHistoryItem] {
        appStore.history.sorted { $0.createdAt < $1.createdAt }
    }

    // Form score trend — confidence is 0–1 higher = better
    private var formScores: [Double] {
        sorted.map(\.result.confidence)
    }

    // Cadence — actual cadence metric score from backend
    private var cadenceScores: [Double] {
        sorted.compactMap { item in
            item.result.metrics.first { $0.name.lowercased().contains("cadence") }?.score
        }
    }

    // Hip stability — "Hip stability" metric score
    private var hipScores: [Double] {
        sorted.compactMap { item in
            item.result.metrics.first { $0.name.lowercased().contains("hip") }?.score
        }
    }

    // Distinct calendar days with at least one session in the last 30 days
    private var recentSessionCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentDates = appStore.history
            .filter { $0.createdAt >= cutoff }
            .map { Calendar.current.startOfDay(for: $0.createdAt) }
        return Set(recentDates).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if appStore.history.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            if appStore.history.count >= 2 {
                                trendsSection
                            }
                            reportsSection
                        }
                        .padding(18)
                    }
                }
            }
            .navigationTitle("History")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !appStore.history.isEmpty {
                    Button("Clear") { showClearConfirmation = true }
                        .foregroundStyle(AppTheme.mint)
                }
            }
            .confirmationDialog("Clear all local history?", isPresented: $showClearConfirmation) {
                Button("Clear History", role: .destructive) { appStore.clearHistory() }
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                "Progress",
                subtitle: "\(appStore.history.count) sessions",
                systemImage: "chart.line.uptrend.xyaxis"
            )
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TrendCard(title: "Form score", values: formScores, color: AppTheme.mint)
                TrendCard(title: "Cadence", values: cadenceScores, color: AppTheme.cyan)
                TrendCard(title: "Hip stability", values: hipScores, color: AppTheme.violet)
                ConsistencyCard(sessionCount: recentSessionCount)
            }
        }
    }

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Reports", subtitle: nil, systemImage: "doc.text")
            ForEach(appStore.history) { item in
                NavigationLink {
                    HistoryDetailView(item: item)
                } label: {
                    HistoryRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            IconBubble(systemImage: "clock.arrow.circlepath", gradient: AppTheme.purpleGradient, size: 76)
            VStack(spacing: 6) {
                Text("No analysis yet")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Analyze your first running video. Results and tester feedback will appear here.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 34)
            }
        }
    }
}

struct HistoryRow: View {
    let item: AnalysisHistoryItem

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center) {
                    IconBubble(systemImage: "figure.run", gradient: AppTheme.actionGradient, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(item.videoFilename)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    ConfidenceRingSmall(value: item.result.confidence)
                }

                Text(item.result.summary)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    MetricPill(text: "\(item.result.metrics.count) metrics", systemImage: "waveform.path.ecg")
                    if let feedback = item.feedback {
                        MetricPill(text: feedback.rating.rawValue, systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }
            }
        }
    }
}

struct ConfidenceRingSmall: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 5)
                .frame(width: 52, height: 52)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Trend components

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if values.count >= 2 {
                let minVal = values.min()!
                let maxVal = values.max()!
                let range = max(maxVal - minVal, 0.001)
                let step = w / CGFloat(values.count - 1)

                let pts: [CGPoint] = values.enumerated().map { i, v in
                    CGPoint(
                        x: CGFloat(i) * step,
                        y: h - CGFloat((v - minVal) / range) * (h - 6) - 3
                    )
                }

                ZStack {
                    // Area fill
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        p.addLine(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(color.opacity(0.18))

                    // Line
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Latest value dot
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .position(pts.last!)
                }
            } else {
                // Not enough data — dashed placeholder
                Rectangle()
                    .fill(color.opacity(0.25))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

struct TrendCard: View {
    let title: String
    let values: [Double]
    let color: Color

    private var latest: Double { values.last ?? 0 }
    // delta vs previous session
    private var delta: Double { values.count >= 2 ? latest - values[values.count - 2] : 0 }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)

                if values.isEmpty {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.38))
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(Int(latest * 100))%")
                            .font(.title2.bold())
                            .foregroundStyle(color)
                        Spacer()
                        if abs(delta) > 0.005 {
                            Label(
                                "\(delta > 0 ? "+" : "")\(Int(delta * 100))%",
                                systemImage: delta > 0 ? "arrow.up.right" : "arrow.down.right"
                            )
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(delta > 0 ? AppTheme.mint : .red.opacity(0.80))
                        }
                    }
                    Sparkline(values: values, color: color)
                        .frame(height: 36)
                }
            }
        }
    }
}

struct ConsistencyCard: View {
    let sessionCount: Int

    private var label: String {
        switch sessionCount {
        case 0: return String(localized: "No sessions yet")
        case 1: return String(localized: "Good start!")
        case 2...3: return String(localized: "Building habit")
        case 4...6: return String(localized: "Staying consistent")
        default: return String(localized: "Great consistency!")
        }
    }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Consistency")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))

                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(sessionCount)")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.orange)
                    Text("days / 30d")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                        .padding(.bottom, 2)
                }

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .frame(height: 36, alignment: .topLeading)
            }
        }
    }
}

struct HistoryDetailView: View {
    @EnvironmentObject private var appStore: AppStore
    let item: AnalysisHistoryItem

    private var currentItem: AnalysisHistoryItem { appStore.history.first(where: { $0.id == item.id }) ?? item }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        HStack(spacing: 14) {
                            IconBubble(systemImage: "doc.text.magnifyingglass", gradient: AppTheme.purpleGradient, size: 48)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(currentItem.createdAt, format: .dateTime.year().month().day().hour().minute())
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(currentItem.videoFilename)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                    }
                    AnalysisResultView(result: currentItem.result)
                    NavigationLink {
                        CompareHistoryView(item: currentItem)
                    } label: {
                        HStack {
                            Image(systemName: "figure.run")
                                .font(.headline)
                            Text("Compare with Elite Athletes")
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
                    FeedbackView(historyItemID: currentItem.id)
                    if let feedback = currentItem.feedback {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 9) {
                                SectionTitle("Saved Feedback", subtitle: "Tester signal", systemImage: "bubble.left.and.bubble.right.fill")
                                Text(feedback.rating.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.mint)
                                if !feedback.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(feedback.comment)
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.66))
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

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
            // Create a temporary PoseMetrics from the analysis data
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
        // Create PoseMetrics from AnalysisResponse
        // This uses the confidence as a proxy for overall scores
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
