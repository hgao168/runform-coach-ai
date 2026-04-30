import SwiftUI
import AVKit

struct ContentView: View {
    @State private var selectedVideoURL: URL?
    @State private var showVideoPicker = false
    @State private var isAnalyzing = false
    @State private var analysis: AnalysisResponse?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let selectedVideoURL {
                        VideoPlayer(player: AVPlayer(url: selectedVideoURL))
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        emptyVideoState
                    }

                    HStack(spacing: 12) {
                        Button {
                            showVideoPicker = true
                        } label: {
                            Label("Pick Video", systemImage: "video.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            Task { await analyzeSelectedVideo() }
                        } label: {
                            if isAnalyzing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Analyze", systemImage: "figure.run")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedVideoURL == nil || isAnalyzing)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }

                    if let analysis {
                        AnalysisResultView(result: analysis)
                    }
                }
                .padding()
            }
            .navigationTitle("RunForm Coach AI")
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker { url in
                    selectedVideoURL = url
                    analysis = nil
                    errorMessage = nil
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Running video → strength plan")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Upload a short side-view running video. V1 returns a starter analysis and strength recommendations.")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyVideoState: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.quaternary)
            .frame(height: 220)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "video")
                        .font(.largeTitle)
                    Text("No video selected")
                        .font(.headline)
                    Text("Use a 10–20 second side-view clip for best results later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private func analyzeSelectedVideo() async {
        guard let selectedVideoURL else { return }
        isAnalyzing = true
        errorMessage = nil

        do {
            analysis = try await APIClient.shared.analyzeVideo(fileURL: selectedVideoURL)
        } catch {
            errorMessage = "Analysis failed. Make sure the backend is running on port 8000."
        }

        isAnalyzing = false
    }
}
