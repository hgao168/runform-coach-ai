import AVFoundation
import Vision

/// Extracts biomechanical running metrics from a local video using Apple Vision body pose detection.
/// Phase 1 reliability update: adds detection-rate scoring, quality notes and more stable cadence.
final class PoseExtractor {
    enum ExtractionError: LocalizedError {
        case noVideoTrack
        case insufficientFrames(Int)
        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "No video track found in the selected file."
            case .insufficientFrames(let n): return "Only \(n) pose frames detected — video may be too short, dark, or the runner is out of frame."
            }
        }
    }

    func extract(from videoURL: URL, expectedVideoMode: String = "side") async throws -> PoseMetrics {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0.5 else { throw ExtractionError.insufficientFrames(0) }
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else { throw ExtractionError.noVideoTrack }
        let frameRate = Double(try await videoTrack.load(.nominalFrameRate))

        let idealSamples = min(120, max(30, Int(durationSeconds * min(frameRate, 24))))
        let stepSeconds = durationSeconds / Double(idealSamples)
        let sampleTimes = stride(from: 0.0, to: max(0.1, durationSeconds - 0.05), by: stepSeconds)
            .map { CMTimeMakeWithSeconds($0, preferredTimescale: 600) }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTimeMakeWithSeconds(0.10, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTimeMakeWithSeconds(0.10, preferredTimescale: 600)

        var framePoses: [FramePose] = []
        var failCount = 0
        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

        for time in sampleTimes {
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { failCount += 1; continue }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([bodyPoseRequest])
            guard let obs = bodyPoseRequest.results?.first else { failCount += 1; continue }

            func point(_ joint: VNHumanBodyPoseObservation.JointName) -> JointPoint? {
                guard let r = try? obs.recognizedPoint(joint), r.confidence > 0.25 else { return nil }
                return JointPoint(x: Double(r.location.x), y: Double(r.location.y), confidence: Double(r.confidence))
            }

            framePoses.append(FramePose(
                time: CMTimeGetSeconds(time),
                leftAnkle: point(.leftAnkle), rightAnkle: point(.rightAnkle),
                leftKnee: point(.leftKnee), rightKnee: point(.rightKnee),
                leftHip: point(.leftHip), rightHip: point(.rightHip),
                leftShoulder: point(.leftShoulder), rightShoulder: point(.rightShoulder),
                neck: point(.neck), nose: point(.nose)
            ))
        }

        let detectionRate = Double(framePoses.count) / Double(max(sampleTimes.count, 1))
        let usablePoses = framePoses.filter { $0.completeness >= 0.55 && $0.averageConfidence >= 0.35 }
        let badFrameRate = framePoses.isEmpty ? 1.0 : 1.0 - (Double(usablePoses.count) / Double(framePoses.count))
        guard usablePoses.count >= 8 else { throw ExtractionError.insufficientFrames(usablePoses.count) }

        var notes: [String] = []
        var qualityNotes: [String] = []
        if durationSeconds < 8 { qualityNotes.append("Clip is short. Use 10-20 seconds for better cadence and gait-cycle stability.") }
        if durationSeconds > 30 { qualityNotes.append("Clip is long. Trim to 10-20 seconds for faster, cleaner analysis.") }
        if detectionRate < 0.70 { qualityNotes.append("Pose detection rate is \(Int(detectionRate * 100))%. Use clearer lighting, tighter clothing, and keep full body in frame.") }
        if failCount > sampleTimes.count / 3 { qualityNotes.append("Many frames did not contain a usable full-body pose.") }
        if badFrameRate > 0.35 { qualityNotes.append("Bad-frame rejection removed \(Int(badFrameRate * 100))% of detected frames due to low confidence/partial body visibility.") }

        let avgCompleteness = usablePoses.map { $0.completeness }.reduce(0,+) / Double(usablePoses.count)
        if avgCompleteness < 0.65 { qualityNotes.append("Some joints are missing. Make sure head, hips, knees and feet stay visible.") }

        let avgConfidence = usablePoses.map { $0.averageConfidence }.reduce(0,+) / Double(usablePoses.count)
        if avgConfidence < 0.55 { qualityNotes.append("Pose confidence is low. Improve lighting and avoid loose/dark clothing blending into the background.") }

        let feetVisibleRate = usablePoses.filter { $0.leftAnkle != nil && $0.rightAnkle != nil }.count
        let feetRate = Double(feetVisibleRate) / Double(usablePoses.count)
        if feetRate < 0.75 { qualityNotes.append("Feet are not fully visible in enough frames. Keep both feet in frame for reliable cadence and overstride detection.") }

        let fullBodyRate = Double(usablePoses.filter { $0.nose != nil && ($0.leftAnkle != nil || $0.rightAnkle != nil) }.count) / Double(usablePoses.count)
        if fullBodyRate < 0.75 { qualityNotes.append("Full-body detection is inconsistent. Keep head to feet visible throughout the clip.") }

        let centeredRate = Double(usablePoses.filter { pose in
            guard let midX = avgX(pose.leftHip, pose.rightHip) else { return false }
            return midX >= 0.35 && midX <= 0.65
        }.count) / Double(usablePoses.count)
        if centeredRate < 0.70 { qualityNotes.append("Runner not centered. Keep your body near the middle of the frame.") }

        let tooCloseRate = Double(usablePoses.filter { pose in
            guard let top = pose.topVisibleY, let bottom = pose.bottomVisibleY else { return false }
            return (top - bottom) > 0.82
        }.count) / Double(usablePoses.count)
        if tooCloseRate > 0.35 { qualityNotes.append("Move back from the camera to keep full body visible.") }

        let cameraLowRate = Double(usablePoses.filter { pose in
            guard let shoulderY = avgY(pose.leftShoulder, pose.rightShoulder), let hipY = avgY(pose.leftHip, pose.rightHip) else { return false }
            return shoulderY > 0.86 || (shoulderY - hipY) < 0.10
        }.count) / Double(usablePoses.count)
        if cameraLowRate > 0.35 { qualityNotes.append("Camera too low. Raise the phone to around hip height.") }

        let sideViewRate = Double(usablePoses.filter { pose in
            guard let shoulderSpread = spreadX(pose.leftShoulder, pose.rightShoulder),
                  let hipSpread = spreadX(pose.leftHip, pose.rightHip) else { return false }
            return shoulderSpread < 0.16 && hipSpread < 0.16
        }.count) / Double(usablePoses.count)
        if expectedVideoMode == "side" && sideViewRate < 0.55 {
            qualityNotes.append("Side-view validation failed. Rotate camera to true side profile.")
        }

        let confidenceHeatmap = [
            "ankles: \(confidenceBand(meanConfidence(usablePoses.compactMap { $0.leftAnkle?.confidence } + usablePoses.compactMap { $0.rightAnkle?.confidence })))",
            "knees: \(confidenceBand(meanConfidence(usablePoses.compactMap { $0.leftKnee?.confidence } + usablePoses.compactMap { $0.rightKnee?.confidence })))",
            "hips: \(confidenceBand(meanConfidence(usablePoses.compactMap { $0.leftHip?.confidence } + usablePoses.compactMap { $0.rightHip?.confidence })))",
            "shoulders: \(confidenceBand(meanConfidence(usablePoses.compactMap { $0.leftShoulder?.confidence } + usablePoses.compactMap { $0.rightShoulder?.confidence })))"
        ]
        qualityNotes.append("Confidence heatmap - \(confidenceHeatmap.joined(separator: ", ")).")

        let videoQualityScore = clamp(0.45 * detectionRate + 0.35 * avgCompleteness + 0.20 * avgConfidence, 0.05, 0.98)
        if videoQualityScore < 0.65 { notes.append("Video quality score \(Int(videoQualityScore * 100))%; biomechanical metrics should be treated as approximate.") }

        let leftAnkleY = smooth(usablePoses.compactMap { $0.leftAnkle?.y })
        let rightAnkleY = smooth(usablePoses.compactMap { $0.rightAnkle?.y })
        var totalSteps = countPeaks(in: leftAnkleY) + countPeaks(in: rightAnkleY)
        if totalSteps < 2 {
            let ankleMidY = smooth(usablePoses.compactMap { pose in
                average(pose.leftAnkle?.y, pose.rightAnkle?.y)
            })
            totalSteps = max(totalSteps, countPeaks(in: ankleMidY, minProminence: 0.018))
        }
        let cadenceSPM = durationSeconds > 0 ? Double(totalSteps) / durationSeconds * 60.0 : 0
        let (cadenceScore, cadenceStatus): (Double, String)
        switch cadenceSPM {
        case ..<140: (cadenceScore, cadenceStatus) = (max(0.25, cadenceSPM / 180.0), "Needs work")
        case 140..<160: (cadenceScore, cadenceStatus) = (0.55, "Moderate")
        case 160...185: (cadenceScore, cadenceStatus) = (0.90, "Good")
        default: (cadenceScore, cadenceStatus) = (0.70, "Moderate")
        }

        let stanceThreshold = percentile(usablePoses.flatMap { [$0.leftAnkle?.y, $0.rightAnkle?.y].compactMap { $0 } }, p: 0.35) ?? 0.28
        var overstrideValues: [Double] = []
        for pose in usablePoses {
            guard let hipMidX = avgX(pose.leftHip, pose.rightHip) else { continue }
            if let la = pose.leftAnkle, la.y < stanceThreshold { overstrideValues.append(abs(la.x - hipMidX)) }
            if let ra = pose.rightAnkle, ra.y < stanceThreshold { overstrideValues.append(abs(ra.x - hipMidX)) }
        }
        let avgOverstride = overstrideValues.isEmpty ? 0.12 : overstrideValues.reduce(0, +) / Double(overstrideValues.count)
        let overstrideScore = 1.0 - clamp((avgOverstride - 0.05) / 0.17, 0, 1)
        let overstrideStatus = overstrideScore > 0.70 ? "Good" : overstrideScore > 0.45 ? "Moderate" : "Needs work"

        var trunkAngles: [Double] = []
        for pose in usablePoses {
            guard let shX = avgX(pose.leftShoulder, pose.rightShoulder),
                  let shY = avgY(pose.leftShoulder, pose.rightShoulder),
                  let hpX = avgX(pose.leftHip, pose.rightHip),
                  let hpY = avgY(pose.leftHip, pose.rightHip), shY > hpY else { continue }
            trunkAngles.append(atan2(shX - hpX, shY - hpY) * 180.0 / .pi)
        }
        let meanTrunkLean = trunkAngles.isEmpty ? 0.0 : trunkAngles.reduce(0,+) / Double(trunkAngles.count)
        let absLean = abs(meanTrunkLean)
        let (trunkScore, trunkStatus): (Double, String)
        switch absLean {
        case ..<5: (trunkScore, trunkStatus) = (0.88, "Good")
        case 5..<12: (trunkScore, trunkStatus) = (0.65, "Moderate")
        default: (trunkScore, trunkStatus) = (0.42, "Needs work")
        }

        var valgusDeviations: [Double] = []
        for pose in usablePoses {
            if let la = pose.leftAnkle, la.y < stanceThreshold, let lk = pose.leftKnee, let lh = pose.leftHip {
                valgusDeviations.append(max(0, lk.x - ((lh.x + la.x) / 2.0)))
            }
            if let ra = pose.rightAnkle, ra.y < stanceThreshold, let rk = pose.rightKnee, let rh = pose.rightHip {
                valgusDeviations.append(max(0, ((rh.x + ra.x) / 2.0) - rk.x))
            }
        }
        let avgValgus = valgusDeviations.isEmpty ? 0.04 : valgusDeviations.reduce(0,+) / Double(valgusDeviations.count)
        let valgusScore = 1.0 - clamp((avgValgus - 0.02) / 0.08, 0, 1)
        let valgusStatus = valgusScore > 0.70 ? "Good" : valgusScore > 0.45 ? "Moderate" : "Needs work"

        return PoseMetrics(
            cadenceEstimateSPM: cadenceSPM,
            cadenceScore: cadenceScore,
            cadenceStatus: cadenceStatus,
            overstrideRiskScore: overstrideScore,
            overstrideStatus: overstrideStatus,
            trunkLeanDegrees: meanTrunkLean,
            trunkLeanScore: trunkScore,
            trunkLeanStatus: trunkStatus,
            kneeValgusRiskScore: valgusScore,
            kneeValgusStatus: valgusStatus,
            frameCount: usablePoses.count,
            videoDurationSeconds: durationSeconds,
            notes: notes,
            videoQualityScore: videoQualityScore,
            poseDetectionRate: detectionRate,
            qualityNotes: qualityNotes
        )
    }

    private struct JointPoint { let x: Double; let y: Double; let confidence: Double }
    private struct FramePose {
        let time: Double
        let leftAnkle: JointPoint?; let rightAnkle: JointPoint?
        let leftKnee: JointPoint?; let rightKnee: JointPoint?
        let leftHip: JointPoint?; let rightHip: JointPoint?
        let leftShoulder: JointPoint?; let rightShoulder: JointPoint?
        let neck: JointPoint?; let nose: JointPoint?
        var points: [JointPoint] { [leftAnkle,rightAnkle,leftKnee,rightKnee,leftHip,rightHip,leftShoulder,rightShoulder,neck,nose].compactMap { $0 } }
        var completeness: Double { Double(points.count) / 10.0 }
        var averageConfidence: Double { points.isEmpty ? 0 : points.map(\.confidence).reduce(0,+) / Double(points.count) }
        var topVisibleY: Double? { points.map(\.y).max() }
        var bottomVisibleY: Double? { points.map(\.y).min() }
    }

    private func smooth(_ values: [Double]) -> [Double] {
        guard values.count >= 3 else { return values }
        return values.indices.map { i in
            let lo = max(0, i - 1), hi = min(values.count - 1, i + 1)
            let slice = values[lo...hi]
            return slice.reduce(0,+) / Double(slice.count)
        }
    }

    private func countPeaks(in values: [Double], minProminence: Double = 0.025) -> Int {
        guard values.count > 2 else { return 0 }
        var count = 0
        for i in 1..<(values.count - 1) where values[i] > values[i-1] && values[i] > values[i+1] {
            if values[i] - max(values[i-1], values[i+1]) >= minProminence { count += 1 }
        }
        return count
    }

    private func percentile(_ values: [Double], p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let idx = Int(clamp(p, 0, 1) * Double(sorted.count - 1))
        return sorted[idx]
    }
    private func meanConfidence(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    private func confidenceBand(_ value: Double) -> String {
        switch value {
        case ..<0.45: return "low"
        case ..<0.70: return "medium"
        default: return "high"
        }
    }
    private func spreadX(_ a: JointPoint?, _ b: JointPoint?) -> Double? {
        guard let ax = a?.x, let bx = b?.x else { return nil }
        return abs(ax - bx)
    }
    private func avgX(_ a: JointPoint?, _ b: JointPoint?) -> Double? { average(a?.x, b?.x) }
    private func avgY(_ a: JointPoint?, _ b: JointPoint?) -> Double? { average(a?.y, b?.y) }
    private func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a,b) { case let (.some(x), .some(y)): return (x+y)/2; case let (.some(x), nil): return x; case let (nil, .some(y)): return y; default: return nil }
    }
    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, value)) }
}
