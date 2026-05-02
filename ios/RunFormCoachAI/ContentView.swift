import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var selectedVideoURL: URL?
    @State private var showVideoPicker = false
    @State private var isAnalyzing = false
    @State private var analysis: AnalysisResponse?
    @State private var latestHistoryItemID: UUID?
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        TabView {
            analyzeTab
                .tabItem { Label("Coach", systemImage: "figure.run.circle.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(AppTheme.mint)
    }

    private var analyzeTab: some View {
        NavigationStack {
            ZStack {
                AppTheme.heroGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard
                        videoCard
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
                    .padding(.vertical, 14)
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
                    statusMessage = "Video selected. Ready for form analysis."
                }
            }
        }
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Run Better")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Upload a running clip. Get form insights and strength work for your next week.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(AppTheme.actionGradient).frame(width: 58, height: 58)
                        Image(systemName: "figure.run")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }

                HStack(spacing: 8) {
                    MetricPill(text: appStore.profile.level.rawValue, systemImage: "bolt.heart")
                    MetricPill(text: "\(Int(appStore.profile.weeklyMileageKm)) km/week", systemImage: "speedometer")
                }
            }
        }
    }

    private var videoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Running clip")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("10–20 sec")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if let selectedVideoURL {
                VideoPlayer(player: AVPlayer(url: selectedVideoURL))
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppTheme.actionGradient)
                            .clipShape(Capsule())
                            .padding(12)
                    }
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.09))
                    .frame(height: 230)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(AppTheme.mint)
                            Text("Choose a side-view running video")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Keep the phone stable and show full body if possible.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .padding()
                    }
            }
        }
        .padding(18)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { showVideoPicker = true } label: {
                Label("Pick Video", systemImage: "plus")
            }
            .buttonStyle(GradientButtonStyle())

            Button { Task { await analyzeSelectedVideo() } } label: {
                if isAnalyzing {
                    ProgressView().tint(.white)
                } else {
                    Label("Analyze", systemImage: "sparkles")
                }
            }
            .buttonStyle(GradientButtonStyle(disabled: selectedVideoURL == nil || isAnalyzing))
            .disabled(selectedVideoURL == nil || isAnalyzing)
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let statusMessage {
            Label(statusMessage, systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(AppTheme.mint)
                .padding(.horizontal, 4)
        }
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(.horizontal, 4)
        }
    }

    private var readyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("What you’ll get", systemImage: "sparkle.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Form confidence, movement metrics, key issues, and targeted strength exercises saved into History for TestFlight feedback.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    private func analyzeSelectedVideo() async {
        guard let selectedVideoURL else { return }
        isAnalyzing = true
        errorMessage = nil
        statusMessage = "Analyzing pose on device..."

        do {
            let poseMetrics = try await PoseExtractor().extract(from: selectedVideoURL)
            statusMessage = "Generating coaching advice..."
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
