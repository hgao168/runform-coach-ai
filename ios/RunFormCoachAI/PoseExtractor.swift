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
                leftElbow: point(.leftElbow), rightElbow: point(.rightElbow),
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

        // --- Cadence: multi-signal fusion with adaptive peak detection ---
        // Signal 1: per-ankle Y peaks (foot swings up = Y rises in Vision coords)
        let leftAnkleYs  = smoothWide(usablePoses.compactMap { $0.leftAnkle?.y })
        let rightAnkleYs = smoothWide(usablePoses.compactMap { $0.rightAnkle?.y })
        var candidateSteps = countPeaksRobust(in: leftAnkleYs) + countPeaksRobust(in: rightAnkleYs)

        if candidateSteps < 4 {
            // Signal 2: hip midpoint Y vertical bounce (one peak per step)
            let hipMidY  = smoothWide(usablePoses.compactMap { avgY($0.leftHip, $0.rightHip) })
            let hipPeaks = countPeaksRobust(in: hipMidY)
            if hipPeaks > candidateSteps { candidateSteps = hipPeaks }
        }

        if candidateSteps < 4 {
            // Signal 3: zero-crossings on detrended combined ankle signal
            let rawAnkle = usablePoses.compactMap { average($0.leftAnkle?.y, $0.rightAnkle?.y) }
            let zcSteps  = zeroCrossingSteps(in: smoothWide(rawAnkle))
            if zcSteps > candidateSteps { candidateSteps = zcSteps }
        }

        if candidateSteps < 4 {
            // Signal 4: knee midpoint Y (last resort)
            let kneeY    = smoothWide(usablePoses.compactMap { avgY($0.leftKnee, $0.rightKnee) })
            let kneePeaks = countPeaksRobust(in: kneeY)
            if kneePeaks > candidateSteps { candidateSteps = kneePeaks }
        }

        let cadenceSPM = durationSeconds > 0 ? Double(candidateSteps) / durationSeconds * 60.0 : 0
        if cadenceSPM < 50 {
            qualityNotes.append("Cadence could not be measured. Make sure feet are visible and the clip is 8+ seconds of steady running.")
        }
        let (cadenceScore, cadenceStatus): (Double, String)
        if cadenceSPM < 50 {
            (cadenceScore, cadenceStatus) = (0.0, "Not measurable")
        } else {
            switch cadenceSPM {
            case ..<140: (cadenceScore, cadenceStatus) = (max(0.20, cadenceSPM / 180.0), "Needs work")
            case 140..<160: (cadenceScore, cadenceStatus) = (0.55, "Moderate")
            case 160...185: (cadenceScore, cadenceStatus) = (0.90, "Good")
            default: (cadenceScore, cadenceStatus) = (0.70, "Moderate")
            }
        }

        let stanceThreshold = percentile(usablePoses.flatMap { [$0.leftAnkle?.y, $0.rightAnkle?.y].compactMap { $0 } }, p: 0.35) ?? 0.28
        // Overstride: confidence-weighted ankle-to-hip distance during stance
        var overstrideWeightedSum = 0.0
        var overstrideWeightTotal = 0.0
        for pose in usablePoses {
            guard let hipMidX = avgX(pose.leftHip, pose.rightHip) else { continue }
            if let la = pose.leftAnkle, la.y < stanceThreshold {
                let w = la.confidence
                overstrideWeightedSum  += abs(la.x - hipMidX) * w
                overstrideWeightTotal  += w
            }
            if let ra = pose.rightAnkle, ra.y < stanceThreshold {
                let w = ra.confidence
                overstrideWeightedSum  += abs(ra.x - hipMidX) * w
                overstrideWeightTotal  += w
            }
        }
        let avgOverstride = overstrideWeightTotal > 0 ? overstrideWeightedSum / overstrideWeightTotal : 0.12
        // Continuous score: 0.05 landing = 1.0, 0.22 landing = 0.0
        let overstrideScore = clamp(1.0 - ((avgOverstride - 0.05) / 0.17), 0.05, 1.0)
        let overstrideStatus = overstrideScore >= 0.75 ? "Good" : overstrideScore >= 0.50 ? "Moderate" : "Needs work"

        // Trunk lean: confidence-weighted angles, then trimmed mean (drop outer 10% outliers)
        var trunkAngleWeights: [(angle: Double, weight: Double)] = []
        for pose in usablePoses {
            guard let shX = avgX(pose.leftShoulder, pose.rightShoulder),
                  let shY = avgY(pose.leftShoulder, pose.rightShoulder),
                  let hpX = avgX(pose.leftHip, pose.rightHip),
                  let hpY = avgY(pose.leftHip, pose.rightHip), shY > hpY else { continue }
            let angle = atan2(shX - hpX, shY - hpY) * 180.0 / .pi
            let lsConf: Double = pose.leftShoulder?.confidence ?? 0
            let rsConf: Double = pose.rightShoulder?.confidence ?? 0
            let lhConf: Double = pose.leftHip?.confidence ?? 0
            let rhConf: Double = pose.rightHip?.confidence ?? 0
            let w = (lsConf + rsConf + lhConf + rhConf) / 4.0
            trunkAngleWeights.append((angle: angle, weight: max(w, 0.01)))
        }
        let meanTrunkLean: Double
        if trunkAngleWeights.isEmpty {
            meanTrunkLean = 0.0
        } else {
            // Trimmed mean: drop bottom and top 10% by angle magnitude
            let sorted = trunkAngleWeights.sorted { abs($0.angle) < abs($1.angle) }
            let trimCount = max(1, sorted.count - 2 * max(1, sorted.count / 10))
            let trimmed = Array(sorted.prefix(trimCount))
            let totalW = trimmed.map(\.weight).reduce(0, +)
            meanTrunkLean = trimmed.map { $0.angle * $0.weight }.reduce(0, +) / totalW
        }
        let absLean = abs(meanTrunkLean)
        // Continuous score: 0° = 0.95, 8° = 0.65, 20° = 0.20 — smooth sigmoid-like curve
        let trunkScore = clamp(0.95 - 0.0375 * absLean, 0.15, 0.95)
        let trunkStatus = trunkScore >= 0.75 ? "Good" : trunkScore >= 0.50 ? "Moderate" : "Needs work"

        // Valgus: confidence-weighted deviation (both inward and outward collapse)
        var valgusWeightedSum = 0.0
        var valgusWeightTotal = 0.0
        for pose in usablePoses {
            if let la = pose.leftAnkle, la.y < stanceThreshold, let lk = pose.leftKnee, let lh = pose.leftHip {
                let deviation = abs(lk.x - ((lh.x + la.x) / 2.0))  // both inward and outward
                let w = (lk.confidence + lh.confidence + la.confidence) / 3.0
                valgusWeightedSum  += deviation * w
                valgusWeightTotal  += w
            }
            if let ra = pose.rightAnkle, ra.y < stanceThreshold, let rk = pose.rightKnee, let rh = pose.rightHip {
                let deviation = abs(rk.x - ((rh.x + ra.x) / 2.0))
                let w = (rk.confidence + rh.confidence + ra.confidence) / 3.0
                valgusWeightedSum  += deviation * w
                valgusWeightTotal  += w
            }
        }
        let avgValgus = valgusWeightTotal > 0 ? valgusWeightedSum / valgusWeightTotal : 0.04
        // Continuous score: 0 deviation = 1.0, 0.10 deviation = ~0.20
        let valgusScore = clamp(1.0 - (avgValgus / 0.10), 0.10, 1.0)
        let valgusStatus = valgusScore >= 0.75 ? "Good" : valgusScore >= 0.50 ? "Moderate" : "Needs work"

        // --- Shared body height estimate (used by vertical oscillation and arm swing) ---
        let bodyHeights = usablePoses.compactMap { pose -> Double? in
            guard let top = pose.topVisibleY, let bot = pose.bottomVisibleY, (top - bot) > 0.2 else { return nil }
            return top - bot
        }
        let avgBodyH = bodyHeights.isEmpty ? 0.70 : bodyHeights.reduce(0, +) / Double(bodyHeights.count)

        // --- Vertical Oscillation: hip Y std dev normalized by body height ---
        // Low = efficient runner (less bounce), high = energy wasted bouncing
        let hipMidYs = usablePoses.compactMap { avgY($0.leftHip, $0.rightHip) }
        let meanHipY = hipMidYs.isEmpty ? 0.5 : hipMidYs.reduce(0, +) / Double(hipMidYs.count)
        let hipYStdDev = hipMidYs.count >= 3
            ? sqrt(hipMidYs.map { ($0 - meanHipY) * ($0 - meanHipY) }.reduce(0, +) / Double(hipMidYs.count))
            : 0.03
        let normalizedOscill = hipYStdDev / avgBodyH
        // < 0.025 normalized = smooth; > 0.09 = very bouncy
        let vertOscScore = clamp(1.0 - (normalizedOscill - 0.025) / 0.065, 0.10, 1.0)
        let vertOscStatus = vertOscScore >= 0.75 ? "Good" : vertOscScore >= 0.50 ? "Moderate" : "Needs work"

        // --- Shoulder Elevation: shoulder-hip height ratio normalized by body height ---
        // Detects hunched (low ratio) or raised/tense shoulders (high ratio)
        var shoulderElevSamples: [Double] = []
        for pose in usablePoses {
            guard let shY = avgY(pose.leftShoulder, pose.rightShoulder),
                  let hpY = avgY(pose.leftHip, pose.rightHip),
                  let top = pose.topVisibleY, let bot = pose.bottomVisibleY else { continue }
            let bodyH = top - bot
            guard bodyH > 0.15 else { continue }
            shoulderElevSamples.append((shY - hpY) / bodyH)
        }
        let meanShoulderRatio = shoulderElevSamples.isEmpty ? 0.40
            : shoulderElevSamples.reduce(0, +) / Double(shoulderElevSamples.count)
        // Ideal ~0.38–0.45 of body height. Hunched < 0.28. Raised/tense > 0.52.
        let shoulderDeviation = abs(meanShoulderRatio - 0.40)
        let shoulderElevScore = clamp(1.0 - shoulderDeviation / 0.18, 0.10, 1.0)
        let shoulderElevStatus = shoulderElevScore >= 0.75 ? "Good" : shoulderElevScore >= 0.50 ? "Moderate" : "Needs work"

        // --- Arm Swing: elbow Y oscillation relative to shoulder (confidence-weighted) ---
        // Active arm drive → elbow swings rhythmically (moderate std dev)
        // Stiff arms → very low std dev; exaggerated pump → very high
        var elbowDropValues: [Double] = []
        for pose in usablePoses {
            if let ls = pose.leftShoulder, let le = pose.leftElbow {
                let w = (ls.confidence + le.confidence) / 2.0
                if w > 0.30 { elbowDropValues.append(ls.y - le.y) }
            }
            if let rs = pose.rightShoulder, let re = pose.rightElbow {
                let w = (rs.confidence + re.confidence) / 2.0
                if w > 0.30 { elbowDropValues.append(rs.y - re.y) }
            }
        }
        let armSwingScore: Double
        let armSwingStatus: String
        if elbowDropValues.count < 10 {
            armSwingScore = 0.0
            armSwingStatus = "Not measurable"
        } else {
            let meanDrop = elbowDropValues.reduce(0, +) / Double(elbowDropValues.count)
            let dropStdDev = sqrt(elbowDropValues.map { ($0 - meanDrop) * ($0 - meanDrop) }.reduce(0, +) / Double(elbowDropValues.count))
            let normDropStdDev = dropStdDev / avgBodyH
            // Optimal oscillation: ~0.055–0.075 of body height std dev
            // Stiff: < 0.02; exaggerated: > 0.13
            let armDeviation = abs(normDropStdDev - 0.065)
            let armSwingVal = clamp(1.0 - armDeviation / 0.065, 0.10, 1.0)
            armSwingScore = armSwingVal
            armSwingStatus = armSwingVal >= 0.75 ? "Good" : armSwingVal >= 0.50 ? "Moderate" : "Needs work"
        }

        // --- Pelvic Drop / Hip Symmetry: left-right hip Y difference during movement ---
        // In Vision coords Y=0 is bottom, Y=1 is top.
        // (leftHip.y - rightHip.y) > 0 → left is higher → right hip drops
        // (leftHip.y - rightHip.y) < 0 → right is higher → left hip drops
        // Needs front or rear view; both hips visible with high confidence.
        var hipTiltSamples: [Double] = []
        for pose in usablePoses {
            guard let lh = pose.leftHip, let rh = pose.rightHip,
                  lh.confidence > 0.42, rh.confidence > 0.42 else { continue }
            hipTiltSamples.append(lh.y - rh.y)
        }
        let pelvicDropScore: Double
        let pelvicDropStatus: String
        if hipTiltSamples.count < 10 {
            pelvicDropScore = 0.0
            pelvicDropStatus = "Not measurable"
        } else {
            let meanTilt = hipTiltSamples.reduce(0, +) / Double(hipTiltSamples.count)
            let tiltStdDev = sqrt(hipTiltSamples.map { ($0 - meanTilt) * ($0 - meanTilt) }.reduce(0, +) / Double(hipTiltSamples.count))
            let normMeanBias = abs(meanTilt) / avgBodyH
            let normTiltStdDev = tiltStdDev / avgBodyH
            // Combined: static structural lean (× 0.5) + dynamic drop oscillation
            // Ideal total < 0.020 normalized; concerning > 0.065
            let pelvicDropMag = normMeanBias * 0.5 + normTiltStdDev
            let pelvicDropVal = clamp(1.0 - (pelvicDropMag - 0.020) / 0.045, 0.10, 1.0)
            pelvicDropScore = pelvicDropVal
            pelvicDropStatus = pelvicDropVal >= 0.75 ? "Good" : pelvicDropVal >= 0.50 ? "Moderate" : "Needs work"
        }

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
            verticalOscillationScore: vertOscScore,
            verticalOscillationStatus: vertOscStatus,
            shoulderElevationScore: shoulderElevScore,
            shoulderElevationStatus: shoulderElevStatus,
            armSwingScore: armSwingScore,
            armSwingStatus: armSwingStatus,
            pelvicDropScore: pelvicDropScore,
            pelvicDropStatus: pelvicDropStatus,
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
        let leftElbow: JointPoint?; let rightElbow: JointPoint?
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

    /// Wider moving-average smoothing (default 5-point) used for cadence signals.
    private func smoothWide(_ values: [Double], window: Int = 5) -> [Double] {
        guard values.count >= 3 else { return values }
        let half = window / 2
        return values.indices.map { i in
            let lo = max(0, i - half), hi = min(values.count - 1, i + half)
            let slice = values[lo...hi]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    /// Peak detection with relative prominence: adapts to actual signal amplitude.
    private func countPeaksRobust(in values: [Double]) -> Int {
        guard values.count > 4 else { return 0 }
        let vMin = values.min() ?? 0
        let vMax = values.max() ?? 0
        let range = vMax - vMin
        guard range > 0.005 else { return 0 }
        // Require peak to stand at least 10% of signal range above surrounding valley
        let prominence = max(0.010, range * 0.10)
        var count = 0
        for i in 1..<(values.count - 1) {
            guard values[i] > values[i-1] && values[i] > values[i+1] else { continue }
            // Compare against min in ±3-sample neighbourhood for broader context
            let lo = max(0, i - 3), hi = min(values.count - 1, i + 3)
            let localMin = values[lo...hi].min() ?? 0
            if values[i] - localMin >= prominence { count += 1 }
        }
        return count
    }

    /// Count upward zero-crossings of the mean-centred signal (robust when peaks are hard to find).
    private func zeroCrossingSteps(in values: [Double]) -> Int {
        guard values.count > 4 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        var crossings = 0
        for i in 1..<values.count where values[i-1] < mean && values[i] >= mean {
            crossings += 1
        }
        return crossings
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
