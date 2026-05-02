import AVFoundation
import Vision

/// Extracts biomechanical running metrics from a local video using Apple Vision body pose detection.
/// All processing is on-device; no raw video is sent to the server.
final class PoseExtractor {

    enum ExtractionError: LocalizedError {
        case noVideoTrack
        case insufficientFrames(Int)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return "No video track found in the selected file."
            case .insufficientFrames(let n):
                return "Only \(n) pose frames detected — video may be too short or the runner is out of frame."
            }
        }
    }

    // MARK: - Public

    func extract(from videoURL: URL) async throws -> PoseMetrics {
        let asset = AVURLAsset(url: videoURL)

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0.5 else { throw ExtractionError.insufficientFrames(0) }

        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else { throw ExtractionError.noVideoTrack }
        let frameRate = Double(try await videoTrack.load(.nominalFrameRate))

        // Sample up to 90 frames evenly throughout the video
        let idealSamples = min(90, max(20, Int(durationSeconds * frameRate)))
        let stepSeconds = durationSeconds / Double(idealSamples)
        var sampleTimes: [CMTime] = []
        var t = 0.0
        while t < durationSeconds - 0.05 {
            sampleTimes.append(CMTimeMakeWithSeconds(t, preferredTimescale: 600))
            t += stepSeconds
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTimeMakeWithSeconds(0.12, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTimeMakeWithSeconds(0.12, preferredTimescale: 600)

        // ── Collect per-frame pose observations ──────────────────────────────
        var framePoses: [FramePose] = []
        var notes: [String] = []
        var failCount = 0

        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

        for time in sampleTimes {
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                failCount += 1
                continue
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([bodyPoseRequest])

            guard let obs = bodyPoseRequest.results?.first else {
                failCount += 1
                continue
            }

            func pt(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let r = try? obs.recognizedPoint(joint), r.confidence > 0.3 else { return nil }
                return r.location  // Vision coords: (0,0)=bottom-left, Y up
            }

            framePoses.append(FramePose(
                time: CMTimeGetSeconds(time),
                leftAnkle:     pt(.leftAnkle),
                rightAnkle:    pt(.rightAnkle),
                leftKnee:      pt(.leftKnee),
                rightKnee:     pt(.rightKnee),
                leftHip:       pt(.leftHip),
                rightHip:      pt(.rightHip),
                leftShoulder:  pt(.leftShoulder),
                rightShoulder: pt(.rightShoulder)
            ))
        }

        let detectionRate = Double(framePoses.count) / Double(sampleTimes.count)
        if detectionRate < 0.40 {
            notes.append("Pose detection rate \(Int(detectionRate * 100))% — results may be approximate. Try a clearer side-view video.")
        }
        guard framePoses.count >= 8 else { throw ExtractionError.insufficientFrames(framePoses.count) }

        // ── Metric 1: Cadence ─────────────────────────────────────────────────
        // Count local peaks in ankle Y trajectory (each peak = one foot swing-through = one step)
        let leftAnkleY  = framePoses.compactMap { $0.leftAnkle?.y  }
        let rightAnkleY = framePoses.compactMap { $0.rightAnkle?.y }
        let leftSteps   = countPeaks(in: leftAnkleY)
        let rightSteps  = countPeaks(in: rightAnkleY)
        let totalSteps  = leftSteps + rightSteps
        let cadenceSPM  = durationSeconds > 0 ? Double(totalSteps) / durationSeconds * 60.0 : 0

        let (cadenceScore, cadenceStatus): (Double, String)
        switch cadenceSPM {
        case ..<140:
            (cadenceScore, cadenceStatus) = (max(0.25, cadenceSPM / 180.0), "Needs work")
        case 140..<160:
            (cadenceScore, cadenceStatus) = (0.55, "Moderate")
        case 160...185:
            (cadenceScore, cadenceStatus) = (0.90, "Good")
        default:
            (cadenceScore, cadenceStatus) = (0.70, "Moderate")  // above 185 = very high
        }

        // ── Metric 2: Overstride risk ─────────────────────────────────────────
        // At stance frames (ankle Y near ground = low Y in Vision space),
        // measure horizontal distance from ankle to hip midpoint.
        var overstrideValues: [Double] = []
        let stanceThreshold = 0.28  // normalized Y; below = foot near ground

        for pose in framePoses {
            guard let hipMidX = avgX(pose.leftHip, pose.rightHip) else { continue }
            if let la = pose.leftAnkle, la.y < stanceThreshold {
                overstrideValues.append(abs(Double(la.x) - hipMidX))
            }
            if let ra = pose.rightAnkle, ra.y < stanceThreshold {
                overstrideValues.append(abs(Double(ra.x) - hipMidX))
            }
        }
        // Normalize: 0.05 = underfoot (good), 0.22+ = well ahead (bad)
        let avgOverstride    = overstrideValues.isEmpty ? 0.12 : overstrideValues.reduce(0, +) / Double(overstrideValues.count)
        let overstrideScore  = 1.0 - clamp((avgOverstride - 0.05) / 0.17, 0, 1)
        let overstrideStatus: String = overstrideScore > 0.70 ? "Good" : overstrideScore > 0.45 ? "Moderate" : "Needs work"

        // ── Metric 3: Trunk lean ──────────────────────────────────────────────
        // Angle of shoulder midpoint relative to hip midpoint from vertical.
        // Vision Y increases upward, so shoulder should be above hip (higher Y).
        var trunkAngles: [Double] = []
        for pose in framePoses {
            guard let shX = avgX(pose.leftShoulder, pose.rightShoulder),
                  let shY = avgY(pose.leftShoulder, pose.rightShoulder),
                  let hpX = avgX(pose.leftHip,      pose.rightHip),
                  let hpY = avgY(pose.leftHip,      pose.rightHip),
                  hpY - shY < -0.05 else { continue }   // shoulder should be above hip

            let dx = shX - hpX
            let dy = shY - hpY  // positive: shoulder above hip
            let angleDeg = atan2(dx, dy) * 180.0 / .pi
            trunkAngles.append(angleDeg)
        }
        let meanTrunkLean = trunkAngles.isEmpty ? 0.0 : trunkAngles.reduce(0, +) / Double(trunkAngles.count)
        let absLean = abs(meanTrunkLean)
        let (trunkScore, trunkStatus): (Double, String)
        switch absLean {
        case ..<5:  (trunkScore, trunkStatus) = (0.88, "Good")
        case 5..<12: (trunkScore, trunkStatus) = (0.65, "Moderate")
        default:    (trunkScore, trunkStatus) = (0.42, "Needs work")
        }

        // ── Metric 4: Knee valgus / hip stability ─────────────────────────────
        // During stance, the knee should track roughly over the foot.
        // Valgus = knee collapses medially from the hip-ankle line.
        var valgusDeviations: [Double] = []
        for pose in framePoses {
            // Left leg: valgus when knee.x > midpoint(hip.x, ankle.x) for right-facing runner
            if let la = pose.leftAnkle, la.y < stanceThreshold,
               let lk = pose.leftKnee, let lh = pose.leftHip {
                let expectedX = (Double(lh.x) + Double(la.x)) / 2.0
                let medialDev = max(0, Double(lk.x) - expectedX)  // inward collapse for left leg
                valgusDeviations.append(medialDev)
            }
            // Right leg
            if let ra = pose.rightAnkle, ra.y < stanceThreshold,
               let rk = pose.rightKnee, let rh = pose.rightHip {
                let expectedX = (Double(rh.x) + Double(ra.x)) / 2.0
                let medialDev = max(0, expectedX - Double(rk.x))  // inward collapse for right leg
                valgusDeviations.append(medialDev)
            }
        }
        let avgValgus    = valgusDeviations.isEmpty ? 0.04 : valgusDeviations.reduce(0, +) / Double(valgusDeviations.count)
        let valgusScore  = 1.0 - clamp((avgValgus - 0.02) / 0.08, 0, 1)
        let valgusStatus: String = valgusScore > 0.70 ? "Good" : valgusScore > 0.45 ? "Moderate" : "Needs work"

        return PoseMetrics(
            cadenceEstimateSPM:  cadenceSPM,
            cadenceScore:        cadenceScore,
            cadenceStatus:       cadenceStatus,
            overstrideRiskScore: overstrideScore,
            overstrideStatus:    overstrideStatus,
            trunkLeanDegrees:    meanTrunkLean,
            trunkLeanScore:      trunkScore,
            trunkLeanStatus:     trunkStatus,
            kneeValgusRiskScore: valgusScore,
            kneeValgusStatus:    valgusStatus,
            frameCount:          framePoses.count,
            videoDurationSeconds: durationSeconds,
            notes:               notes
        )
    }

    // MARK: - Helpers

    private struct FramePose {
        let time: Double
        let leftAnkle:     CGPoint?
        let rightAnkle:    CGPoint?
        let leftKnee:      CGPoint?
        let rightKnee:     CGPoint?
        let leftHip:       CGPoint?
        let rightHip:      CGPoint?
        let leftShoulder:  CGPoint?
        let rightShoulder: CGPoint?
    }

    /// Count local maxima in a 1-D signal with a minimum prominence to filter noise.
    private func countPeaks(in values: [Double], minProminence: Double = 0.04) -> Int {
        guard values.count > 2 else { return 0 }
        var count = 0
        for i in 1..<values.count - 1 where values[i] > values[i-1] && values[i] > values[i+1] {
            let prominence = values[i] - max(values[i-1], values[i+1])
            if prominence >= minProminence { count += 1 }
        }
        return count
    }

    private func avgX(_ a: CGPoint?, _ b: CGPoint?) -> Double? {
        switch (a, b) {
        case let (.some(p), .some(q)): return Double((p.x + q.x) / 2)
        case let (.some(p), nil):      return Double(p.x)
        case let (nil, .some(q)):      return Double(q.x)
        default:                       return nil
        }
    }

    private func avgY(_ a: CGPoint?, _ b: CGPoint?) -> Double? {
        switch (a, b) {
        case let (.some(p), .some(q)): return Double((p.y + q.y) / 2)
        case let (.some(p), nil):      return Double(p.y)
        case let (nil, .some(q)):      return Double(q.y)
        default:                       return nil
        }
    }

    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, value))
    }
}
