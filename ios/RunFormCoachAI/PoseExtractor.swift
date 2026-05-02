import AVFoundation
import CoreGraphics
import Vision

/// Extracts biomechanical running metrics from a local video using Apple Vision body pose detection.
/// Raw video stays on the device; only numeric metrics are sent to the backend.
final class PoseExtractor {
    enum ExtractionError: LocalizedError {
        case noVideoTrack
        case insufficientFrames(Int)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return "No video track found in the selected file."
            case .insufficientFrames(let n):
                return "Only \(n) usable pose frames detected. Re-record with side view and full body visible."
            }
        }
    }

    func extract(from videoURL: URL) async throws -> PoseMetrics {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0.5 else { throw ExtractionError.insufficientFrames(0) }

        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else { throw ExtractionError.noVideoTrack }

        let frameRate = max(24.0, Double(try await videoTrack.load(.nominalFrameRate)))
        let idealSamples = min(120, max(30, Int(durationSeconds * min(frameRate, 30.0))))
        let stepSeconds = durationSeconds / Double(idealSamples)
        var sampleTimes: [CMTime] = []
        var t = 0.0
        while t < durationSeconds - 0.05 {
            sampleTimes.append(CMTimeMakeWithSeconds(t, preferredTimescale: 600))
            t += stepSeconds
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTimeMakeWithSeconds(0.08, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTimeMakeWithSeconds(0.08, preferredTimescale: 600)

        var framePoses: [FramePose] = []
        let request = VNDetectHumanBodyPoseRequest()

        for time in sampleTimes {
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            guard let obs = request.results?.first else { continue }

            func point(_ joint: VNHumanBodyPoseObservation.JointName, minConfidence: Float = 0.25) -> CGPoint? {
                guard let p = try? obs.recognizedPoint(joint), p.confidence >= minConfidence else { return nil }
                return p.location
            }

            framePoses.append(
                FramePose(
                    time: CMTimeGetSeconds(time),
                    leftAnkle: point(.leftAnkle),
                    rightAnkle: point(.rightAnkle),
                    leftKnee: point(.leftKnee),
                    rightKnee: point(.rightKnee),
                    leftHip: point(.leftHip),
                    rightHip: point(.rightHip),
                    leftShoulder: point(.leftShoulder),
                    rightShoulder: point(.rightShoulder)
                )
            )
        }

        guard framePoses.count >= 8 else { throw ExtractionError.insufficientFrames(framePoses.count) }

        let poseDetectionRate = Double(framePoses.count) / Double(max(1, sampleTimes.count))
        let ankleVisibleFrames = framePoses.filter { $0.leftAnkle != nil || $0.rightAnkle != nil }.count
        let ankleVisibilityRate = Double(ankleVisibleFrames) / Double(max(1, framePoses.count))

        var qualityReasons: [String] = []
        var notes: [String] = []

        if durationSeconds < 8 {
            qualityReasons.append("Video is shorter than 8 seconds. Cadence needs several steps to estimate reliably.")
        } else if durationSeconds > 30 {
            qualityReasons.append("Video is longer than 30 seconds. Use a clean 10–20 second clip for faster, steadier analysis.")
        }
        if poseDetectionRate < 0.55 {
            qualityReasons.append("Runner body pose was detected in only \(Int(poseDetectionRate * 100))% of sampled frames.")
        }
        if ankleVisibilityRate < 0.60 {
            qualityReasons.append("Feet/ankles were not visible in enough frames, so cadence may be unreliable.")
        }

        // Cadence: use ankle vertical motion local extrema. If the signal is too weak, mark it unmeasurable instead of showing a false 0.
        let leftSignal = framePoses.compactMap { pose -> TimedValue? in
            guard let y = pose.leftAnkle?.y else { return nil }
            return TimedValue(time: pose.time, value: Double(y))
        }
        let rightSignal = framePoses.compactMap { pose -> TimedValue? in
            guard let y = pose.rightAnkle?.y else { return nil }
            return TimedValue(time: pose.time, value: Double(y))
        }

        let leftSteps = countCadenceEvents(in: leftSignal)
        let rightSteps = countCadenceEvents(in: rightSignal)
        let totalSteps = leftSteps + rightSteps
        let rawCadence = durationSeconds > 0 ? Double(totalSteps) / durationSeconds * 60.0 : 0

        let cadenceQuality: String
        let cadenceSPM: Double
        let cadenceScore: Double
        let cadenceStatus: String

        if totalSteps < 4 || rawCadence < 120 || rawCadence > 230 || ankleVisibilityRate < 0.45 {
            cadenceQuality = "Low"
            cadenceSPM = 0
            cadenceScore = 0.50
            cadenceStatus = "Not measurable"
            qualityReasons.append("Cadence could not be measured from this clip. Re-record side view with both feet visible for the full stride cycle.")
            notes.append("Cadence was not measured instead of returning a misleading 0 spm result.")
        } else {
            cadenceQuality = rawCadence >= 140 && rawCadence <= 210 ? "High" : "Medium"
            cadenceSPM = rawCadence
            switch cadenceSPM {
            case ..<155:
                cadenceScore = max(0.35, cadenceSPM / 180.0)
                cadenceStatus = "Needs work"
            case 155..<165:
                cadenceScore = 0.65
                cadenceStatus = "Moderate"
            case 165...185:
                cadenceScore = 0.92
                cadenceStatus = "Good"
            default:
                cadenceScore = 0.72
                cadenceStatus = "Moderate"
            }
        }

        let stanceThreshold = ankleGroundThreshold(framePoses)
        var overstrideValues: [Double] = []
        for pose in framePoses {
            guard let hipMidX = avgX(pose.leftHip, pose.rightHip) else { continue }
            if let la = pose.leftAnkle, la.y <= stanceThreshold { overstrideValues.append(abs(Double(la.x) - hipMidX)) }
            if let ra = pose.rightAnkle, ra.y <= stanceThreshold { overstrideValues.append(abs(Double(ra.x) - hipMidX)) }
        }
        let avgOverstride = overstrideValues.isEmpty ? 0.12 : overstrideValues.reduce(0, +) / Double(overstrideValues.count)
        let overstrideScore = 1.0 - clamp((avgOverstride - 0.05) / 0.17, 0, 1)
        let overstrideStatus = status(for: overstrideScore)

        var trunkAngles: [Double] = []
        for pose in framePoses {
            guard let shX = avgX(pose.leftShoulder, pose.rightShoulder),
                  let shY = avgY(pose.leftShoulder, pose.rightShoulder),
                  let hpX = avgX(pose.leftHip, pose.rightHip),
                  let hpY = avgY(pose.leftHip, pose.rightHip),
                  shY > hpY + 0.05 else { continue }
            let dx = shX - hpX
            let dy = shY - hpY
            trunkAngles.append(atan2(dx, dy) * 180.0 / .pi)
        }
        let meanTrunkLean = trunkAngles.isEmpty ? 0 : trunkAngles.reduce(0, +) / Double(trunkAngles.count)
        let absLean = abs(meanTrunkLean)
        let trunkScore: Double
        let trunkStatus: String
        switch absLean {
        case ..<5:
            trunkScore = 0.88; trunkStatus = "Good"
        case 5..<12:
            trunkScore = 0.65; trunkStatus = "Moderate"
        default:
            trunkScore = 0.42; trunkStatus = "Needs work"
        }

        var valgusDeviations: [Double] = []
        for pose in framePoses {
            if let la = pose.leftAnkle, la.y <= stanceThreshold, let lk = pose.leftKnee, let lh = pose.leftHip {
                let expectedX = (Double(lh.x) + Double(la.x)) / 2.0
                valgusDeviations.append(abs(Double(lk.x) - expectedX))
            }
            if let ra = pose.rightAnkle, ra.y <= stanceThreshold, let rk = pose.rightKnee, let rh = pose.rightHip {
                let expectedX = (Double(rh.x) + Double(ra.x)) / 2.0
                valgusDeviations.append(abs(Double(rk.x) - expectedX))
            }
        }
        let avgValgus = valgusDeviations.isEmpty ? 0.04 : valgusDeviations.reduce(0, +) / Double(valgusDeviations.count)
        let valgusScore = 1.0 - clamp((avgValgus - 0.03) / 0.10, 0, 1)
        let valgusStatus = status(for: valgusScore)

        var qualityScore = 1.0
        qualityScore -= durationSeconds < 8 ? 0.20 : 0
        qualityScore -= durationSeconds > 30 ? 0.10 : 0
        qualityScore -= poseDetectionRate < 0.55 ? 0.25 : 0
        qualityScore -= ankleVisibilityRate < 0.60 ? 0.25 : 0
        qualityScore -= cadenceQuality == "Low" ? 0.20 : 0
        qualityScore = clamp(qualityScore, 0.25, 1.0)

        return PoseMetrics(
            cadenceEstimateSPM: cadenceSPM,
            cadenceScore: cadenceScore,
            cadenceStatus: cadenceStatus,
            cadenceQuality: cadenceQuality,
            cadenceStepCount: totalSteps,
            overstrideRiskScore: overstrideScore,
            overstrideStatus: overstrideStatus,
            trunkLeanDegrees: meanTrunkLean,
            trunkLeanScore: trunkScore,
            trunkLeanStatus: trunkStatus,
            kneeValgusRiskScore: valgusScore,
            kneeValgusStatus: valgusStatus,
            frameCount: framePoses.count,
            sampledFrameCount: sampleTimes.count,
            videoDurationSeconds: durationSeconds,
            poseDetectionRate: poseDetectionRate,
            ankleVisibilityRate: ankleVisibilityRate,
            videoQualityScore: qualityScore,
            qualityReasons: qualityReasons,
            notes: notes
        )
    }

    private struct FramePose {
        let time: Double
        let leftAnkle: CGPoint?
        let rightAnkle: CGPoint?
        let leftKnee: CGPoint?
        let rightKnee: CGPoint?
        let leftHip: CGPoint?
        let rightHip: CGPoint?
        let leftShoulder: CGPoint?
        let rightShoulder: CGPoint?
    }

    private struct TimedValue {
        let time: Double
        let value: Double
    }

    private func countCadenceEvents(in signal: [TimedValue]) -> Int {
        guard signal.count >= 6 else { return 0 }
        let smoothed = movingAverage(signal.map(\.value), radius: 2)
        guard let minY = smoothed.min(), let maxY = smoothed.max(), maxY - minY >= 0.035 else { return 0 }
        let prominence = max(0.025, (maxY - minY) * 0.28)
        var events: [Double] = []
        for i in 1..<(smoothed.count - 1) {
            let isPeak = smoothed[i] > smoothed[i - 1] && smoothed[i] > smoothed[i + 1]
            let isValley = smoothed[i] < smoothed[i - 1] && smoothed[i] < smoothed[i + 1]
            if isPeak || isValley {
                let localProminence = abs(smoothed[i] - ((smoothed[i - 1] + smoothed[i + 1]) / 2.0))
                if localProminence >= prominence {
                    let eventTime = signal[i].time
                    if let last = events.last, eventTime - last < 0.22 { continue }
                    events.append(eventTime)
                }
            }
        }
        // One ankle often yields one prominent swing/stance event per gait cycle.
        return events.count
    }

    private func movingAverage(_ values: [Double], radius: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        return values.indices.map { i in
            let lo = max(0, i - radius)
            let hi = min(values.count - 1, i + radius)
            let window = values[lo...hi]
            return window.reduce(0, +) / Double(window.count)
        }
    }

    private func ankleGroundThreshold(_ poses: [FramePose]) -> CGFloat {
        let yValues = poses.flatMap { [$0.leftAnkle?.y, $0.rightAnkle?.y].compactMap { $0 } }.sorted()
        guard !yValues.isEmpty else { return 0.28 }
        let idx = max(0, min(yValues.count - 1, Int(Double(yValues.count) * 0.35)))
        return yValues[idx]
    }

    private func avgX(_ a: CGPoint?, _ b: CGPoint?) -> Double? {
        switch (a, b) {
        case let (.some(p), .some(q)): return Double((p.x + q.x) / 2)
        case let (.some(p), nil): return Double(p.x)
        case let (nil, .some(q)): return Double(q.x)
        default: return nil
        }
    }

    private func avgY(_ a: CGPoint?, _ b: CGPoint?) -> Double? {
        switch (a, b) {
        case let (.some(p), .some(q)): return Double((p.y + q.y) / 2)
        case let (.some(p), nil): return Double(p.y)
        case let (nil, .some(q)): return Double(q.y)
        default: return nil
        }
    }

    private func status(for score: Double) -> String {
        score > 0.70 ? "Good" : score > 0.45 ? "Moderate" : "Needs work"
    }

    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, value))
    }
}
