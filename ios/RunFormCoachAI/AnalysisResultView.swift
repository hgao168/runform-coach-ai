import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResponse
    var poseMetrics: PoseMetrics? = nil

    @State private var showCompare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreCard
            if poseMetrics != nil { compareButton }
            if let score = result.videoQualityScore { qualityCard(score: score) }
            metricsSection
            issuesSection

            AdBannerView(adUnitID: AdBannerView.testAdUnitID)
                .frame(height: 50)
        }
        .sheet(isPresented: $showCompare) {
            if let metrics = poseMetrics {
                CompareView(poseMetrics: metrics)
            }
        }
    }

    private var compareButton: some View {
        Button {
            showCompare = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.headline)
                Text("Compare with Elite")
                    .font(.headline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.60)
            }
            .foregroundStyle(.black)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(AppTheme.actionGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppTheme.cyan.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var scoreCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Form Report")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(result.summary)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(.white.opacity(0.12), lineWidth: 8).frame(width: 76, height: 76)
                        Circle()
                            .trim(from: 0, to: result.confidence)
                            .stroke(AppTheme.actionGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 76, height: 76)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(result.confidence * 100))%")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func qualityCard(score: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Video Quality", systemImage: "camera.metering.center.weighted")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(score * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.actionGradient)
                    .clipShape(Capsule())
            }
            ProgressView(value: score).tint(AppTheme.mint)
            if let notes = result.qualityNotes, !notes.isEmpty {
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
            } else {
                Text("Clip quality is good enough for reliable on-device pose analysis.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }
        }
        .padding(15)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Movement Metrics")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(result.metrics) { metric in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(metric.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                        Text(metric.status)
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(AppTheme.actionGradient)
                            .clipShape(Capsule())
                    }
                    ProgressView(value: metric.score).tint(AppTheme.mint)
                    Text(metric.explanation).font(.caption).foregroundStyle(.white.opacity(0.64))
                }
                .padding(15)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strength Focus")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(result.issues) { issue in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(issue.title, systemImage: "target")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(issue.severity)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.12))
                            .foregroundStyle(.white.opacity(0.82))
                            .clipShape(Capsule())
                    }
                    Text(issue.explanation)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                    ForEach(issue.recommendedExercises) { exercise in ExerciseCard(exercise: exercise) }
                }
                .padding(16)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise
    @Environment(\.openURL) private var openURL

    private var videoSearchURL: URL? {
        let query = "\(exercise.name) running exercise form"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let isChinaRegion = Locale.current.region?.identifier == "CN"
        let urlString = isChinaRegion
            ? "https://search.bilibili.com/all?keyword=\(encoded)"
            : "https://www.youtube.com/results?search_query=\(encoded)"
        return URL(string: urlString)
    }

    var body: some View {
        Button {
            if let url = videoSearchURL { openURL(url) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.actionGradient)
                        .frame(width: 42, height: 42)
                    Image(systemName: "dumbbell.fill").foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Image(systemName: "play.circle")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mint)
                    }
                    Text("\(exercise.category) • \(exercise.sets) sets • \(exercise.reps) • \(exercise.frequencyPerWeek)x/week")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                    Text(exercise.reason).font(.caption).foregroundStyle(.white.opacity(0.62))
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
