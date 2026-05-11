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
