import SwiftUI

// MARK: - RunSession API Response Models

/// A single RunSession returned by GET /sessions.
struct RunSessionResponse: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let durationSeconds: Double
    let distanceMeters: Double?
    let avgCadenceSPM: Double
    let avgVerticalOscillationCm: Double
    let avgGroundContactTimeMs: Double
    let timeSeries: [RunSessionTimePoint]
    let coachEvents: [RunSessionCoachEvent]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case avgCadenceSPM = "avg_cadence_spm"
        case avgVerticalOscillationCm = "avg_vertical_oscillation_cm"
        case avgGroundContactTimeMs = "avg_ground_contact_time_ms"
        case timeSeries = "time_series"
        case coachEvents = "coach_events"
    }
}

/// A single time-series data point within a RunSession.
struct RunSessionTimePoint: Codable, Identifiable {
    var id: Double { timestampSeconds }

    let timestampSeconds: Double
    let cadenceSPM: Double?
    let verticalOscillationCm: Double?
    let groundContactTimeMs: Double?

    enum CodingKeys: String, CodingKey {
        case timestampSeconds = "timestamp_seconds"
        case cadenceSPM = "cadence_spm"
        case verticalOscillationCm = "vertical_oscillation_cm"
        case groundContactTimeMs = "ground_contact_time_ms"
    }
}

/// A coaching event (voice prompt) that occurred during a RunSession.
struct RunSessionCoachEvent: Codable, Identifiable {
    let id: String
    let timestampSeconds: Double
    let category: String
    let message: String
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case id
        case timestampSeconds = "timestamp_seconds"
        case category
        case message
        case priority
    }
}

// MARK: - RunSessionReplayViewModel

@MainActor
final class RunSessionReplayViewModel: ObservableObject {
    @Published var sessions: [RunSessionResponse] = []
    @Published var selectedSession: RunSessionResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Playback: 0.0 ... durationSeconds (or clamped)
    @Published var playbackTime: Double = 0
    @Published var isPlaying = false
    @Published var selectedCoachEvent: RunSessionCoachEvent?

    private var timer: Timer?
    private let playbackSpeed: Double = 1.0

    var duration: Double { selectedSession?.durationSeconds ?? 0 }

    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        do {
            sessions = try await APIClient.shared.fetchSessions()
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func selectSession(_ session: RunSessionResponse) {
        selectedSession = session
        playbackTime = 0
        isPlaying = false
        selectedCoachEvent = nil
        stopTimer()
    }

    func togglePlayback() {
        guard selectedSession != nil else { return }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard !isPlaying else { return }
        if playbackTime >= duration { playbackTime = 0 }
        isPlaying = true
        startTimer()
    }

    func pause() {
        isPlaying = false
        stopTimer()
    }

    func seek(to time: Double) {
        playbackTime = max(0, min(duration, time))
        isPlaying = false
        stopTimer()
    }

    func eventAtCurrentTime() -> RunSessionCoachEvent? {
        guard let session = selectedSession else { return nil }
        let threshold: Double = 0.5 // seconds tolerance
        return session.coachEvents.first { abs($0.timestampSeconds - playbackTime) < threshold }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                let step = 0.05 * self.playbackSpeed
                self.playbackTime = min(self.playbackTime + step, self.duration)
                if self.playbackTime >= self.duration {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopTimer()
    }
}

// MARK: - RunSessionReplayView

struct RunSessionReplayView: View {
    @StateObject private var viewModel = RunSessionReplayViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if viewModel.sessions.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else if let session = viewModel.selectedSession {
                        replayDetailView(session: session)
                    } else {
                        sessionListView
                    }
                }
            }
            .navigationTitle("Run Replay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if viewModel.selectedSession != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.selectedSession = nil
                                viewModel.pause()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Sessions")
                            }
                            .foregroundStyle(AppTheme.mint)
                        }
                    }
                }
            }
        }
        .task { await viewModel.loadSessions() }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            IconBubble(systemImage: "figure.run.circle", gradient: AppTheme.purpleGradient, size: 76)
            VStack(spacing: 6) {
                Text("No Sessions Yet")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Your live run sessions will appear here once you complete a tracked run.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 34)
            }
        }
    }

    // MARK: - Session list

    private var sessionListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView().tint(AppTheme.mint)
                        Spacer()
                    }
                    .padding(.top, 40)
                }

                if let error = viewModel.errorMessage {
                    MessageBanner(text: error, systemImage: "exclamationmark.triangle.fill", color: AppTheme.orange)
                        .padding(.horizontal, 18)
                }

                ForEach(viewModel.sessions) { session in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.selectSession(session)
                        }
                    } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }

    private func sessionRow(_ session: RunSessionResponse) -> some View {
        DarkCard {
            HStack(alignment: .center, spacing: 14) {
                IconBubble(systemImage: "figure.run", gradient: AppTheme.actionGradient, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(formattedDuration(session.durationSeconds))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(session.avgCadenceSPM)) spm")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.mint)
                    if let distance = session.distanceMeters {
                        Text(formattedDistance(distance))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Replay detail

    private func replayDetailView(session: RunSessionResponse) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                overviewPanel(session: session)
                chartCard(session: session)
                playbackControls
                if let event = viewModel.selectedCoachEvent {
                    coachEventDetailCard(event: event)
                } else {
                    coachEventsList(session: session)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Overview panel

    private func overviewPanel(session: RunSessionResponse) -> some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Session Overview", subtitle: nil, systemImage: "chart.bar.fill")

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    overviewStat(
                        label: "Avg Cadence",
                        value: "\(Int(session.avgCadenceSPM))",
                        unit: "spm",
                        icon: "metronome",
                        color: AppTheme.mint
                    )
                    overviewStat(
                        label: "Avg Oscillation",
                        value: String(format: "%.1f", session.avgVerticalOscillationCm),
                        unit: "cm",
                        icon: "arrow.up.and.down",
                        color: AppTheme.violet
                    )
                    overviewStat(
                        label: "Avg GCT",
                        value: "\(Int(session.avgGroundContactTimeMs))",
                        unit: "ms",
                        icon: "timer",
                        color: AppTheme.cyan
                    )
                }

                HStack(spacing: 10) {
                    overviewStatRow(
                        label: "Duration",
                        value: formattedDuration(session.durationSeconds),
                        icon: "clock",
                        color: AppTheme.mint
                    )
                    if let distance = session.distanceMeters {
                        overviewStatRow(
                            label: "Distance",
                            value: formattedDistance(distance),
                            icon: "point.topleft.down.to.point.bottomright.curvepath",
                            color: AppTheme.cyan
                        )
                    }
                    overviewStatRow(
                        label: "Coach Prompts",
                        value: "\(session.coachEvents.count)",
                        icon: "message.fill",
                        color: AppTheme.orange
                    )
                }

                if let event = viewModel.eventAtCurrentTime() {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text(String(format: NSLocalizedString("Coach prompt at %@", comment: "Coach prompt timestamp indicator"), formattedTime(viewModel.playbackTime)))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.orange)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func overviewStat(label: LocalizedStringKey, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func overviewStatRow(label: LocalizedStringKey, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Chart card

    private func chartCard(session: RunSessionResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Time Series", subtitle: "Tap & drag to seek", systemImage: "chart.xyaxis.line")

            // Legend
            HStack(spacing: 16) {
                legendItem(color: AppTheme.mint, label: "Cadence")
                legendItem(color: AppTheme.violet, label: "Oscillation")
                legendItem(color: AppTheme.cyan, label: "GCT")
                legendItem(color: .red, label: "Coach")
            }
            .font(.caption)

            // Chart canvas
            GeometryReader { geometry in
                let width = geometry.size.width
                let height: CGFloat = 220
                let chartHeight = height - 16

                ZStack(alignment: .topLeading) {
                    // Canvas-based chart
                    Canvas { ctx, size in
                        guard session.timeSeries.count >= 2 else { return }

                        let points = session.timeSeries
                        let maxTime = points.last?.timestampSeconds ?? session.durationSeconds
                        let margin: CGFloat = 4

                        // Gather value ranges
                        let cadenceValues = points.compactMap(\.cadenceSPM)
                        let oscValues = points.compactMap(\.verticalOscillationCm)
                        let gctValues = points.compactMap(\.groundContactTimeMs)

                        let cadenceMin = cadenceValues.min() ?? 0
                        let cadenceMax = cadenceValues.max() ?? 200
                        let oscMin = oscValues.min() ?? 0
                        let oscMax = oscValues.max() ?? 15
                        let gctMin = gctValues.min() ?? 150
                        let gctMax = gctValues.max() ?? 400

                        func xPos(_ t: Double) -> CGFloat {
                            margin + CGFloat(t / maxTime) * (size.width - margin * 2)
                        }
                        func yPos(_ value: Double, _ vmin: Double, _ vmax: Double) -> CGFloat {
                            let range = max(vmax - vmin, 0.001)
                            return margin + CGFloat(1.0 - (value - vmin) / range) * (chartHeight - margin * 2)
                        }

                        // Draw grid lines
                        for i in 0...4 {
                            let y = margin + CGFloat(i) * (chartHeight - margin * 2) / 4
                            var gridPath = Path()
                            gridPath.move(to: CGPoint(x: margin, y: y))
                            gridPath.addLine(to: CGPoint(x: size.width - margin, y: y))
                            ctx.stroke(gridPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                        }

                        // Draw cadence line
                        if cadenceValues.count >= 2 {
                            var path = Path()
                            var first = true
                            for pt in points {
                                guard let cad = pt.cadenceSPM else { continue }
                                let px = xPos(pt.timestampSeconds)
                                let py = yPos(cad, cadenceMin, cadenceMax)
                                if first { path.move(to: CGPoint(x: px, y: py)); first = false }
                                else { path.addLine(to: CGPoint(x: px, y: py)) }
                            }
                            ctx.stroke(path, with: .color(AppTheme.mint), lineWidth: 2)
                        }

                        // Draw oscillation line
                        if oscValues.count >= 2 {
                            var path = Path()
                            var first = true
                            for pt in points {
                                guard let val = pt.verticalOscillationCm else { continue }
                                let px = xPos(pt.timestampSeconds)
                                let py = yPos(val, oscMin, oscMax)
                                if first { path.move(to: CGPoint(x: px, y: py)); first = false }
                                else { path.addLine(to: CGPoint(x: px, y: py)) }
                            }
                            ctx.stroke(path, with: .color(AppTheme.violet), lineWidth: 1.5)
                        }

                        // Draw GCT line
                        if gctValues.count >= 2 {
                            var path = Path()
                            var first = true
                            for pt in points {
                                guard let val = pt.groundContactTimeMs else { continue }
                                let px = xPos(pt.timestampSeconds)
                                let py = yPos(val, gctMin, gctMax)
                                if first { path.move(to: CGPoint(x: px, y: py)); first = false }
                                else { path.addLine(to: CGPoint(x: px, y: py)) }
                            }
                            ctx.stroke(path, with: .color(AppTheme.cyan), lineWidth: 1.5)
                        }

                        // Draw coach event markers (red vertical lines)
                        for event in session.coachEvents {
                            let x = xPos(event.timestampSeconds)
                            var line = Path()
                            line.move(to: CGPoint(x: x, y: margin))
                            line.addLine(to: CGPoint(x: x, y: chartHeight - margin))
                            ctx.stroke(line, with: .color(.red.opacity(0.5)), lineWidth: 1)

                            // Small triangle marker on top
                            var marker = Path()
                            marker.move(to: CGPoint(x: x, y: margin - 4))
                            marker.addLine(to: CGPoint(x: x - 4, y: margin + 3))
                            marker.addLine(to: CGPoint(x: x + 4, y: margin + 3))
                            marker.closeSubpath()
                            ctx.fill(marker, with: .color(.red))
                        }

                        // Draw playback cursor
                        let cursorX = xPos(viewModel.playbackTime)
                        var cursorLine = Path()
                        cursorLine.move(to: CGPoint(x: cursorX, y: margin))
                        cursorLine.addLine(to: CGPoint(x: cursorX, y: chartHeight - margin))
                        ctx.stroke(cursorLine, with: .color(.white.opacity(0.7)), lineWidth: 2)

                        // Cursor dot
                        var dot = Path(ellipseIn: CGRect(
                            x: cursorX - 5,
                            y: chartHeight / 2 - 5,
                            width: 10,
                            height: 10
                        ))
                        ctx.fill(dot, with: .color(.white))
                    }
                    .frame(height: chartHeight)

                    // Drag gesture overlay for seeking
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let maxTime = session.timeSeries.last?.timestampSeconds ?? session.durationSeconds
                                    let ratio = max(0, min(1, value.location.x / width))
                                    viewModel.seek(to: ratio * maxTime)
                                }
                        )
                }
                .frame(height: chartHeight + 8)
            }
            .frame(height: 230)
        }
        .padding(18)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        )
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Playback controls

    private var playbackControls: some View {
        DarkCard {
            VStack(spacing: 12) {
                // Time display
                HStack {
                    Text(formattedTime(viewModel.playbackTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.mint)
                    Spacer()
                    Text(formattedTime(viewModel.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Progress slider
                Slider(value: Binding(
                    get: { viewModel.playbackTime },
                    set: { viewModel.seek(to: $0) }
                ), in: 0...max(viewModel.duration, 1))
                .tint(AppTheme.mint)

                // Control buttons
                HStack(spacing: 24) {
                    // Skip back 5s
                    Button {
                        viewModel.seek(to: max(0, viewModel.playbackTime - 5))
                    } label: {
                        Image(systemName: "gobackward.5")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Play / Pause
                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(AppTheme.actionGradient)
                                .frame(width: 52, height: 52)
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.black)
                        }
                    }

                    // Skip forward 5s
                    Button {
                        viewModel.seek(to: min(viewModel.duration, viewModel.playbackTime + 5))
                    } label: {
                        Image(systemName: "goforward.5")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
    }

    // MARK: - Coach event detail

    private func coachEventDetailCard(event: RunSessionCoachEvent) -> some View {
        DarkCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.orange.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "message.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(event.category.capitalized)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.orange)
                        Spacer()
                        Button {
                            viewModel.selectedCoachEvent = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Text(event.message)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 8) {
                        Label(formattedTime(event.timestampSeconds), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Label(String(format: NSLocalizedString("Priority %lld", comment: "Coach prompt priority level"), event.priority), systemImage: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(event.priority >= 2 ? AppTheme.orange : .white.opacity(0.5))
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Coach events list

    private func coachEventsList(session: RunSessionResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Coach Prompts", subtitle: "Tap for details", systemImage: "message.fill")
            if session.coachEvents.isEmpty {
                Text("No coach prompts during this session.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.leading, 10)
            } else {
                ForEach(session.coachEvents) { event in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedCoachEvent = event
                            // Optionally seek to event time
                            viewModel.seek(to: event.timestampSeconds)
                        }
                    } label: {
                        coachEventRow(event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func coachEventRow(_ event: RunSessionCoachEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Red marker
            Rectangle()
                .fill(Color.red)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.category.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.orange)
                    Spacer()
                    Text(formattedTime(event.timestampSeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text(event.message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Formatters

    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formattedDistance(_ meters: Double) -> String {
        let km = meters / 1000.0
        return String(format: "%.2f km", km)
    }

    private func formattedTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total >= 3600 {
            let h = total / 3600
            let m = (total % 3600) / 60
            let s = total % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

#if DEBUG
struct RunSessionReplayView_Previews: PreviewProvider {
    static var previews: some View {
        RunSessionReplayView()
            .preferredColorScheme(.dark)
    }
}
#endif
