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
                leftWrist: point(.leftWrist), rightWrist: point(.rightWrist),
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
            let meanDrop: Double = elbowDropValues.reduce(0.0, +) / Double(elbowDropValues.count)
            let dropSumSq: Double = elbowDropValues.reduce(0.0) { $0 + ($1 - meanDrop) * ($1 - meanDrop) }
            let dropStdDev: Double = sqrt(dropSumSq / Double(elbowDropValues.count))
            let normDropStdDev = dropStdDev / avgBodyH
            // Optimal oscillation: ~0.055–0.075 of body height std dev
            // Stiff: < 0.02; exaggerated: > 0.13
            let armDeviation = abs(normDropStdDev - 0.065)
            let armSwingVal = clamp(1.0 - armDeviation / 0.065, 0.10, 1.0)
            armSwingScore = armSwingVal
            armSwingStatus = armSwingVal >= 0.75 ? "Good" : armSwingVal >= 0.50 ? "Moderate" : "Needs work"
        }

        // --- Arm crossing direction ("knitting") ---
        // Detect whether elbows frequently cross body midline instead of driving front-back.
        var leftCrossVals: [Double] = []
        var rightCrossVals: [Double] = []
        for pose in usablePoses {
            guard let ls = pose.leftShoulder, let rs = pose.rightShoulder else { continue }
            let shoulderWidth = abs(rs.x - ls.x)
            guard shoulderWidth > 0.01 else { continue }
            let midX = (ls.x + rs.x) / 2.0

            if let le = pose.leftElbow, le.confidence > 0.35 {
                let leftCross = max(0.0, (le.x - midX) / shoulderWidth)
                leftCrossVals.append(leftCross)
            }
            if let re = pose.rightElbow, re.confidence > 0.35 {
                let rightCross = max(0.0, (midX - re.x) / shoulderWidth)
                rightCrossVals.append(rightCross)
            }
        }

        let armCrossingScore: Double
        let armCrossingStatus: String
        let armCrossingDirection: String
        if leftCrossVals.count < 8 || rightCrossVals.count < 8 {
            armCrossingScore = 0.0
            armCrossingStatus = "Not measurable"
            armCrossingDirection = "Not measurable"
        } else {
            let leftCrossMean = leftCrossVals.reduce(0, +) / Double(leftCrossVals.count)
            let rightCrossMean = rightCrossVals.reduce(0, +) / Double(rightCrossVals.count)
            let crossMagnitude = (leftCrossMean + rightCrossMean) / 2.0
            let score = clamp(1.0 - crossMagnitude / 0.22, 0.10, 1.0)
            armCrossingScore = score
            armCrossingStatus = score >= 0.75 ? "Good" : score >= 0.50 ? "Moderate" : "Needs work"
            if abs(leftCrossMean - rightCrossMean) < 0.02 {
                armCrossingDirection = "balanced"
            } else {
                armCrossingDirection = leftCrossMean > rightCrossMean ? "left_over_right" : "right_over_left"
            }
        }

        // --- Backward elbow drive angle ---
        // Estimate running direction from hip progression and measure rearward elbow drive angle.
        let hipMidXs = usablePoses.compactMap { avgX($0.leftHip, $0.rightHip) }
        var hipDelta: [Double] = []
        if hipMidXs.count > 1 {
            for i in 1..<hipMidXs.count { hipDelta.append(hipMidXs[i] - hipMidXs[i - 1]) }
        }
        let directionSign = median(hipDelta) >= 0 ? 1.0 : -1.0

        var backwardDriveAngles: [Double] = []
        for pose in usablePoses {
            let pairs: [(JointPoint?, JointPoint?)] = [(pose.leftShoulder, pose.leftElbow), (pose.rightShoulder, pose.rightElbow)]
            for (shoulder, elbow) in pairs {
                guard let sh = shoulder, let el = elbow else { continue }
                let dx = (sh.x - el.x) * directionSign // positive means elbow behind shoulder
                guard dx > 0 else { continue }
                let dy = abs(sh.y - el.y)
                backwardDriveAngles.append(atan2(dx, max(0.001, dy)) * 180.0 / .pi)
            }
        }

        let backwardElbowDriveAngleDegrees: Double
        let backwardElbowDriveScore: Double
        let backwardElbowDriveStatus: String
        if backwardDriveAngles.count < 8 {
            backwardElbowDriveAngleDegrees = 0.0
            backwardElbowDriveScore = 0.0
            backwardElbowDriveStatus = "Not measurable"
        } else {
            let meanDrive = backwardDriveAngles.reduce(0, +) / Double(backwardDriveAngles.count)
            backwardElbowDriveAngleDegrees = meanDrive
            let driveDeviation = abs(meanDrive - 40.0)
            let score = clamp(1.0 - driveDeviation / 35.0, 0.10, 1.0)
            backwardElbowDriveScore = score
            backwardElbowDriveStatus = score >= 0.75 ? "Good" : score >= 0.50 ? "Moderate" : "Needs work"
        }

        // --- Elbow angle (shoulder-elbow-wrist) ---
        var elbowAngleSamples: [Double] = []
        for pose in usablePoses {
            let chains: [(JointPoint?, JointPoint?, JointPoint?)] = [
                (pose.leftShoulder, pose.leftElbow, pose.leftWrist),
                (pose.rightShoulder, pose.rightElbow, pose.rightWrist),
            ]
            for (shoulder, elbow, wrist) in chains {
                guard let sh = shoulder, let el = elbow, let wr = wrist else { continue }
                let angle = angleAtVertex(a: sh, vertex: el, c: wr)
                elbowAngleSamples.append(angle)
            }
        }

        let elbowAngleDegrees: Double
        let elbowAngleScore: Double
        let elbowAngleStatus: String
        if elbowAngleSamples.count < 10 {
            elbowAngleDegrees = 0.0
            elbowAngleScore = 0.0
            elbowAngleStatus = "Not measurable"
        } else {
            let meanElbowAngle = elbowAngleSamples.reduce(0, +) / Double(elbowAngleSamples.count)
            elbowAngleDegrees = meanElbowAngle
            let elbowDeviation = abs(meanElbowAngle - 90.0)
            let score = clamp(1.0 - elbowDeviation / 45.0, 0.10, 1.0)
            elbowAngleScore = score
            elbowAngleStatus = score >= 0.75 ? "Good" : score >= 0.50 ? "Moderate" : "Needs work"
        }

        // --- Shoulder-arm independence ---
        // High torso-arm coupling suggests the torso is rotating with arm swing instead of stable carriage.
        var torsoTwist: [Double] = []
        var armPhase: [Double] = []
        for pose in usablePoses {
            guard let ls = pose.leftShoulder, let rs = pose.rightShoulder,
                  let lh = pose.leftHip, let rh = pose.rightHip,
                  let le = pose.leftElbow, let re = pose.rightElbow else { continue }
            let shoulderLine = ls.x - rs.x
            let hipLine = lh.x - rh.x
            torsoTwist.append(shoulderLine - hipLine)

            let leftOffset = le.x - ls.x
            let rightOffset = re.x - rs.x
            armPhase.append(leftOffset - rightOffset)
        }

        let shoulderArmIndependenceScore: Double
        let shoulderArmIndependenceStatus: String
        if torsoTwist.count < 10 || armPhase.count < 10 {
            shoulderArmIndependenceScore = 0.0
            shoulderArmIndependenceStatus = "Not measurable"
        } else {
            let corr = abs(pearsonCorrelation(torsoTwist, armPhase))
            let score = clamp(1.0 - corr, 0.10, 1.0)
            shoulderArmIndependenceScore = score
            shoulderArmIndependenceStatus = score >= 0.75 ? "Good" : score >= 0.50 ? "Moderate" : "Needs work"
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
            let meanTilt: Double = hipTiltSamples.reduce(0.0, +) / Double(hipTiltSamples.count)
            let tiltSumSq: Double = hipTiltSamples.reduce(0.0) { $0 + ($1 - meanTilt) * ($1 - meanTilt) }
            let tiltStdDev: Double = sqrt(tiltSumSq / Double(hipTiltSamples.count))
            let normMeanBias = abs(meanTilt) / avgBodyH
            let normTiltStdDev = tiltStdDev / avgBodyH
            // Combined: static structural lean (× 0.5) + dynamic drop oscillation
            // Ideal total < 0.020 normalized; concerning > 0.065
            let pelvicDropMag = normMeanBias * 0.5 + normTiltStdDev
            let pelvicDropVal = clamp(1.0 - (pelvicDropMag - 0.020) / 0.045, 0.10, 1.0)
            pelvicDropScore = pelvicDropVal
            pelvicDropStatus = pelvicDropVal >= 0.75 ? "Good" : pelvicDropVal >= 0.50 ? "Moderate" : "Needs work"
        }

        // --- Left/Right Step Symmetry: compare ankle Y oscillation amplitude between sides ---
        // Far-side ankle in side view has low confidence → naturally produces < 10 samples → "Not measurable"
        // Reliable in front/rear view where both ankles are clearly visible.
        var leftSymAnkleYs: [Double] = []
        var rightSymAnkleYs: [Double] = []
        for pose in usablePoses {
            if let la = pose.leftAnkle, la.confidence > 0.30 { leftSymAnkleYs.append(la.y) }
            if let ra = pose.rightAnkle, ra.confidence > 0.30 { rightSymAnkleYs.append(ra.y) }
        }
        let stepSymmetryScore: Double
        let stepSymmetryStatus: String
        if leftSymAnkleYs.count < 10 || rightSymAnkleYs.count < 10 {
            stepSymmetryScore = 0.0
            stepSymmetryStatus = "Not measurable"
        } else {
            let leftMean: Double = leftSymAnkleYs.reduce(0.0, +) / Double(leftSymAnkleYs.count)
            let rightMean: Double = rightSymAnkleYs.reduce(0.0, +) / Double(rightSymAnkleYs.count)
            let leftSumSq: Double = leftSymAnkleYs.reduce(0.0) { $0 + ($1 - leftMean) * ($1 - leftMean) }
            let rightSumSq: Double = rightSymAnkleYs.reduce(0.0) { $0 + ($1 - rightMean) * ($1 - rightMean) }
            let leftStd: Double = sqrt(leftSumSq / Double(leftSymAnkleYs.count))
            let rightStd: Double = sqrt(rightSumSq / Double(rightSymAnkleYs.count))
            let avgStd = (leftStd + rightStd) / 2.0
            if avgStd < 0.002 {
                // Signal too flat — likely static capture or extreme zoom
                stepSymmetryScore = 0.0
                stepSymmetryStatus = "Not measurable"
            } else {
                // asymmetry: 0 = perfect; ~0.15 = noticeable; ~0.30 = significant
                let asymmetry = abs(leftStd - rightStd) / avgStd
                let symVal = clamp(1.0 - asymmetry / 0.30, 0.10, 1.0)
                stepSymmetryScore = symVal
                stepSymmetryStatus = symVal >= 0.75 ? "Good" : symVal >= 0.50 ? "Moderate" : "Needs work"
            }
        }

        // --- Head Forward Position: nose X offset from shoulder line, side view only ---
        // Detects forward head / text-neck posture while running.
        // Only meaningful in side view (small shoulder X spread).
        var headOffsetSamples: [Double] = []
        var shoulderSpreadSamples: [Double] = []
        for pose in usablePoses {
            if let ls = pose.leftShoulder, let rs = pose.rightShoulder,
               ls.confidence > 0.30, rs.confidence > 0.30 {
                shoulderSpreadSamples.append(abs(ls.x - rs.x))
            }
            guard let nos = pose.nose, nos.confidence > 0.30 else { continue }
            var refX: Double? = nil
            if let ls = pose.leftShoulder, let rs = pose.rightShoulder,
               ls.confidence > 0.30, rs.confidence > 0.30 {
                refX = (ls.x + rs.x) / 2.0
            } else if let ls = pose.leftShoulder, ls.confidence > 0.40 {
                refX = ls.x
            } else if let rs = pose.rightShoulder, rs.confidence > 0.40 {
                refX = rs.x
            }
            guard let sx = refX else { continue }
            headOffsetSamples.append(abs(nos.x - sx) / avgBodyH)
        }
        // avgShoulderSpread ≥ 0.22 → front/rear view → head forward not meaningful
        let avgShoulderSpread = shoulderSpreadSamples.isEmpty ? 1.0
            : shoulderSpreadSamples.reduce(0, +) / Double(shoulderSpreadSamples.count)
        let headForwardScore: Double
        let headForwardStatus: String
        if headOffsetSamples.count < 10 || avgShoulderSpread >= 0.22 {
            headForwardScore = 0.0
            headForwardStatus = "Not measurable"
        } else {
            let meanHeadOffset = headOffsetSamples.reduce(0, +) / Double(headOffsetSamples.count)
            // ≤ 0.05 normalized: good; > 0.12: significant forward head (text neck)
            let headVal = clamp(1.0 - max(0.0, meanHeadOffset - 0.05) / 0.07, 0.10, 1.0)
            headForwardScore = headVal
            headForwardStatus = headVal >= 0.75 ? "Good" : headVal >= 0.50 ? "Moderate" : "Needs work"
        }

        // --- Composite 0-100 categories (stored as 0.0-1.0) ---
        let postureScore = weightedAverage([
            (trunkScore, 0.40),
            (shoulderElevScore, 0.30),
            (headForwardScore, 0.30),
        ])
        let efficiencyScore = weightedAverage([
            (cadenceScore, 0.40),
            (overstrideScore, 0.35),
            (vertOscScore, 0.25),
        ])
        let stabilityScore = weightedAverage([
            (valgusScore, 0.45),
            (pelvicDropScore, 0.30),
            (stepSymmetryScore, 0.25),
        ])
        let propulsionScore = weightedAverage([
            (cadenceScore, 0.35),
            (overstrideScore, 0.35),
            (backwardElbowDriveScore, 0.30),
        ])
        let armMechanicsScore = weightedAverage([
            (armSwingScore, 0.25),
            (armCrossingScore, 0.20),
            (elbowAngleScore, 0.20),
            (backwardElbowDriveScore, 0.20),
            (shoulderArmIndependenceScore, 0.15),
        ])
        let symmetryScore = weightedAverage([
            (stepSymmetryScore, 0.40),
            (pelvicDropScore, 0.35),
            (armCrossingScore, 0.25),
        ])
        let injuryRiskScore = clamp(
            1.0 - weightedAverage([
                (stabilityScore, 0.35),
                (symmetryScore, 0.20),
                (overstrideScore, 0.20),
                (postureScore, 0.10),
                (efficiencyScore, 0.15),
            ]),
            0.05,
            0.95
        )

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
            armCrossingScore: armCrossingScore,
            armCrossingStatus: armCrossingStatus,
            armCrossingDirection: armCrossingDirection,
            backwardElbowDriveScore: backwardElbowDriveScore,
            backwardElbowDriveStatus: backwardElbowDriveStatus,
            backwardElbowDriveAngleDegrees: backwardElbowDriveAngleDegrees,
            elbowAngleScore: elbowAngleScore,
            elbowAngleStatus: elbowAngleStatus,
            elbowAngleDegrees: elbowAngleDegrees,
            shoulderArmIndependenceScore: shoulderArmIndependenceScore,
            shoulderArmIndependenceStatus: shoulderArmIndependenceStatus,
            pelvicDropScore: pelvicDropScore,
            pelvicDropStatus: pelvicDropStatus,
            stepSymmetryScore: stepSymmetryScore,
            stepSymmetryStatus: stepSymmetryStatus,
            headForwardScore: headForwardScore,
            headForwardStatus: headForwardStatus,
            postureScore: postureScore,
            efficiencyScore: efficiencyScore,
            stabilityScore: stabilityScore,
            propulsionScore: propulsionScore,
            armMechanicsScore: armMechanicsScore,
            symmetryScore: symmetryScore,
            injuryRiskScore: injuryRiskScore,
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
        let leftWrist: JointPoint?; let rightWrist: JointPoint?
        let neck: JointPoint?; let nose: JointPoint?
        var points: [JointPoint] { [leftAnkle,rightAnkle,leftKnee,rightKnee,leftHip,rightHip,leftShoulder,rightShoulder,leftElbow,rightElbow,leftWrist,rightWrist,neck,nose].compactMap { $0 } }
        var completeness: Double { Double(points.count) / 14.0 }
        var averageConfidence: Double { points.isEmpty ? 0 : points.map(\.confidence).reduce(0,+) / Double(points.count) }
        var topVisibleY: Double? { points.map(\.y).max() }
        var bottomVisibleY: Double? { points.map(\.y).min() }
    }

    // MARK: - Thin wrappers delegating to SignalProcessing global functions

    private func angleAtVertex(a: JointPoint, vertex: JointPoint, c: JointPoint) -> Double {
        SignalProcessing.angleAtVertex(ax: a.x, ay: a.y, vx: vertex.x, vy: vertex.y, cx: c.x, cy: c.y)
    }

    private func weightedAverage(_ values: [(Double, Double)]) -> Double {
        SignalProcessing.weightedAverage(values)
    }

    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        SignalProcessing.pearsonCorrelation(x, y)
    }

    private func median(_ values: [Double]) -> Double {
        SignalProcessing.median(values)
    }

    private func smooth(_ values: [Double]) -> [Double] {
        SignalProcessing.smooth(values)
    }

    private func smoothWide(_ values: [Double], window: Int = 5) -> [Double] {
        SignalProcessing.smoothWide(values, window: window)
    }

    private func countPeaksRobust(in values: [Double]) -> Int {
        SignalProcessing.countPeaksRobust(in: values)
    }

    private func zeroCrossingSteps(in values: [Double]) -> Int {
        SignalProcessing.zeroCrossingSteps(in: values)
    }

    private func countPeaks(in values: [Double], minProminence: Double = 0.025) -> Int {
        SignalProcessing.countPeaks(in: values, minProminence: minProminence)
    }

    private func percentile(_ values: [Double], p: Double) -> Double? {
        SignalProcessing.percentile(values, p: p)
    }

    private func meanConfidence(_ values: [Double]) -> Double {
        SignalProcessing.meanConfidence(values)
    }

    private func confidenceBand(_ value: Double) -> String {
        SignalProcessing.confidenceBand(value)
    }

    private func spreadX(_ a: JointPoint?, _ b: JointPoint?) -> Double? {
        SignalProcessing.spreadX(a?.x, b?.x)
    }

    private func avgX(_ a: JointPoint?, _ b: JointPoint?) -> Double? {
        SignalProcessing.average(a?.x, b?.x)
    }

    private func avgY(_ a: JointPoint?, _ b: JointPoint?) -> Double? {
        SignalProcessing.average(a?.y, b?.y)
    }

    private func average(_ a: Double?, _ b: Double?) -> Double? {
        SignalProcessing.average(a, b)
    }

    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        SignalProcessing.clamp(value, lo, hi)
    }
}
