import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var selectedVideoURL: URL?
    @State private var showVideoPicker = false
    @State private var showLiveRecorder = false
    @State private var isAnalyzing = false
    @State private var analysis: AnalysisResponse?
    @State private var latestHistoryItemID: UUID?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var videoMode: VideoMode = .side

    var body: some View {
        TabView {
            analyzeTab
                .tabItem { Label("Analyze", systemImage: "figure.run") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            PlanBuilderView()
                .tabItem { Label("Plan", systemImage: "calendar.badge.plus") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(AppTheme.mint)
        .preferredColorScheme(.dark)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }

    private var analyzeTab: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard
                        quickStatsRow
                        videoCard
                        recordingTipsCard
                        actionButtons
                        messageSection

                        if let analysis {
                            AnalysisResultView(result: analysis)
                            if let latestHistoryItemID {
                                FeedbackView(historyItemID: latestHistoryItemID)
                            }
                        } else {
                            readyCard
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("RunForm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker { url in
                    selectedVideoURL = url
                    analysis = nil
                    latestHistoryItemID = nil
                    errorMessage = nil
                    statusMessage = "Video selected. RunForm will check pose quality before coaching."
                }
            }
            .sheet(isPresented: $showLiveRecorder) {
                LiveGuidanceRecorderView(videoMode: videoMode) { url in
                    selectedVideoURL = url
                    analysis = nil
                    latestHistoryItemID = nil
                    errorMessage = nil
                    statusMessage = "Recording captured with live guidance. Ready to analyze."
                }
            }
        }
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("AI Running Form Coach")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.mint)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Text("Run Better")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Upload a short clip. Get movement metrics, form issues, and strength work built for runners.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    IconBubble(systemImage: "figure.run", gradient: AppTheme.actionGradient, size: 62)
                }

                HStack(spacing: 8) {
                    MetricPill(text: appStore.profile.level.rawValue, systemImage: "bolt.heart.fill")
                    MetricPill(text: "\(Int(appStore.profile.weeklyMileageKm)) km/wk", systemImage: "speedometer")
                }
            }
        }
    }

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            MiniStatCard(title: "Quality", value: selectedVideoURL == nil ? "Ready" : "Clip", icon: "checkmark.seal.fill")
            MiniStatCard(title: "Output", value: "Metrics", icon: "waveform.path.ecg")
            MiniStatCard(title: "Plan", value: "Strength", icon: "dumbbell.fill")
        }
    }

    private var videoCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Running clip", subtitle: "Select camera angle", systemImage: "video.fill")

                HStack(spacing: 10) {
                    ForEach(VideoMode.allCases) { mode in
                        Button {
                            if videoMode != mode {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    videoMode = mode
                                }
                                analysis = nil
                                selectedVideoURL = nil
                                statusMessage = nil
                                errorMessage = nil
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    Image(systemName: mode.icon)
                                        .font(.caption.weight(.bold))
                                    Text(mode.label)
                                        .font(.subheadline.weight(.semibold))
                                }
                                Text(mode.metrics)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundStyle(videoMode == mode ? .black.opacity(0.65) : .white.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(videoMode == mode ? AppTheme.mint : .white.opacity(0.07))
                            .foregroundStyle(videoMode == mode ? .black : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(videoMode == mode ? Color.clear : .white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let selectedVideoURL {
                    VideoPlayer(player: AVPlayer(url: selectedVideoURL))
                        .frame(height: 238)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            StatusBadge(text: "Selected")
                                .padding(12)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.10), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.black.opacity(0.22))
                        .frame(height: 238)
                        .overlay {
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(AppTheme.cyan.opacity(0.14)).frame(width: 90, height: 90)
                                    Image(systemName: "video.badge.plus")
                                        .font(.system(size: 42, weight: .semibold))
                                        .foregroundStyle(AppTheme.mint)
                                }
                                VStack(spacing: 5) {
                                    Text("Choose a running video")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("10–20 seconds, full body visible, both feet in frame")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                            }
                            .padding()
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [7, 7]))
                                .foregroundStyle(.white.opacity(0.16))
                        )
                        .onTapGesture { showVideoPicker = true }
                }
            }
        }
    }

    private var recordingTipsCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 13) {
                SectionTitle("Capture guide", subtitle: videoMode == .side ? "Side view tips" : "Rear view tips", systemImage: "checklist.checked")
                VStack(alignment: .leading, spacing: 10) {
                    GuidelineRow(text: "Record 10–20 seconds at normal running pace", icon: "timer")
                    if videoMode == .side {
                        GuidelineRow(text: "Side view: phone at hip height, parallel to your direction of travel", icon: "iphone.gen3")
                        GuidelineRow(text: "Full body visible — both feet must stay in frame", icon: "figure.walk.motion")
                    } else {
                        GuidelineRow(text: "Rear view: phone centered behind you at waist height", icon: "iphone.gen3")
                        GuidelineRow(text: "Full body visible from head to heels, keep hips/knees in frame", icon: "figure.walk.motion")
                    }
                    GuidelineRow(text: "Use bright lighting and avoid motion blur", icon: "sun.max.fill")
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { showLiveRecorder = true } label: {
                    Label("Record Live", systemImage: "record.circle")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button { showVideoPicker = true } label: {
                    Label("Pick Video", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button { Task { await analyzeSelectedVideo() } } label: {
                if isAnalyzing {
                    HStack(spacing: 10) {
                        ProgressView().tint(.black)
                        Text("Analyzing")
                    }
                } else {
                    Label("Analyze", systemImage: "sparkles")
                }
            }
            .buttonStyle(GradientButtonStyle(disabled: selectedVideoURL == nil || isAnalyzing))
            .disabled(selectedVideoURL == nil || isAnalyzing)
        }
    }

    @ViewBuilder private var messageSection: some View {
        if let statusMessage {
            MessageBanner(text: statusMessage, systemImage: "checkmark.circle.fill", color: AppTheme.mint)
        }
        if let errorMessage {
            MessageBanner(text: errorMessage, systemImage: "exclamationmark.triangle.fill", color: AppTheme.orange)
        }
    }

    private var readyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("What you’ll get", subtitle: "Clear, runner-friendly coaching", systemImage: "sparkle.magnifyingglass")
                FeatureRow(title: "Movement metrics", subtitle: "Cadence, overstride, trunk lean, arm movement, arm swing", icon: "chart.xyaxis.line")
                FeatureRow(title: "Strength focus", subtitle: "Issue-based exercises with why each one helps", icon: "figure.strengthtraining.traditional")
                FeatureRow(title: "Quality check", subtitle: "If metrics are unreliable, RunForm asks for a better clip", icon: "shield.checkered")
            }
        }
    }

    private func analyzeSelectedVideo() async {
        guard let selectedVideoURL else { return }
        isAnalyzing = true
        errorMessage = nil
        statusMessage = "Extracting pose metrics on device..."

        do {
            var poseMetrics = try await PoseExtractor().extract(from: selectedVideoURL, expectedVideoMode: videoMode.rawValue)
            poseMetrics.videoMode = videoMode.rawValue
            if poseMetrics.videoQualityScore < 0.40 {
                let topIssue = poseMetrics.qualityNotes.first ?? "Video quality is too low for reliable form analysis."
                errorMessage = "Please re-record: \(topIssue)"
                statusMessage = nil
                isAnalyzing = false
                return
            }

            if poseMetrics.videoQualityScore < 0.55 {
                let topGuidance = poseMetrics.qualityNotes.prefix(2).joined(separator: " ")
                statusMessage = "Video quality is low. \(topGuidance)"
            } else {
                statusMessage = "Pose quality looks usable. Generating coaching advice..."
            }

            let result = try await APIClient.shared.analyzeMetrics(poseMetrics)
            analysis = result
            appStore.addHistory(result: result, videoURL: selectedVideoURL)
            latestHistoryItemID = appStore.history.first?.id
            statusMessage = "Analysis saved. Please add feedback after review."
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
            statusMessage = nil
        }

        isAnalyzing = false
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.085))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

struct GuidelineRow: View {
    let text: String
    var icon: String = "checkmark.circle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mint)
                .frame(width: 18)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

struct MessageBanner: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .padding(.top, 1)
            Text(text)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.82))
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

struct FeatureRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.mint)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }
}
