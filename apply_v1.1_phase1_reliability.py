from pathlib import Path

ROOT = Path.cwd()

def write(path, content):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content.strip() + "\n", encoding="utf-8")
    print(f"updated {path}")

write('backend/app/schemas.py', r'''
from pydantic import BaseModel
from typing import List, Optional

class Metric(BaseModel):
    name: str
    score: float
    status: str
    explanation: str

class Exercise(BaseModel):
    name: str
    category: str
    sets: int
    reps: str
    frequency_per_week: int
    reason: str

class Issue(BaseModel):
    title: str
    severity: str
    explanation: str
    recommended_exercises: List[Exercise]

class AnalysisResponse(BaseModel):
    summary: str
    confidence: float
    metrics: List[Metric]
    issues: List[Issue]
    video_quality_score: Optional[float] = None
    quality_notes: List[str] = []

class PoseMetricsInput(BaseModel):
    cadence_estimate_spm: float
    cadence_score: float
    cadence_status: str
    overstride_risk_score: float
    overstride_status: str
    trunk_lean_degrees: float
    trunk_lean_score: float
    trunk_lean_status: str
    knee_valgus_risk_score: float
    knee_valgus_status: str
    frame_count: int
    video_duration_seconds: float
    notes: List[str] = []
    video_quality_score: float = 0.7
    pose_detection_rate: float = 0.0
    quality_notes: List[str] = []
''')

write('ios/RunFormCoachAI/Models.swift', r'''
import Foundation

struct AnalysisResponse: Codable, Identifiable, Equatable {
    var id: String { summary + String(confidence) + metrics.map(\.name).joined() }
    let summary: String
    let confidence: Double
    let metrics: [Metric]
    let issues: [Issue]
    let videoQualityScore: Double?
    let qualityNotes: [String]?

    enum CodingKeys: String, CodingKey {
        case summary, confidence, metrics, issues
        case videoQualityScore = "video_quality_score"
        case qualityNotes = "quality_notes"
    }
}

struct Metric: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let score: Double
    let status: String
    let explanation: String
}

struct Issue: Codable, Identifiable, Equatable {
    var id: String { title }
    let title: String
    let severity: String
    let explanation: String
    let recommendedExercises: [Exercise]
    enum CodingKeys: String, CodingKey {
        case title, severity, explanation
        case recommendedExercises = "recommended_exercises"
    }
}

struct Exercise: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let category: String
    let sets: Int
    let reps: String
    let frequencyPerWeek: Int
    let reason: String
    enum CodingKeys: String, CodingKey {
        case name, category, sets, reps, reason
        case frequencyPerWeek = "frequency_per_week"
    }
}

struct PoseMetrics: Codable {
    let cadenceEstimateSPM: Double
    let cadenceScore: Double
    let cadenceStatus: String
    let overstrideRiskScore: Double
    let overstrideStatus: String
    let trunkLeanDegrees: Double
    let trunkLeanScore: Double
    let trunkLeanStatus: String
    let kneeValgusRiskScore: Double
    let kneeValgusStatus: String
    let frameCount: Int
    let videoDurationSeconds: Double
    let notes: [String]
    let videoQualityScore: Double
    let poseDetectionRate: Double
    let qualityNotes: [String]

    enum CodingKeys: String, CodingKey {
        case cadenceEstimateSPM = "cadence_estimate_spm"
        case cadenceScore = "cadence_score"
        case cadenceStatus = "cadence_status"
        case overstrideRiskScore = "overstride_risk_score"
        case overstrideStatus = "overstride_status"
        case trunkLeanDegrees = "trunk_lean_degrees"
        case trunkLeanScore = "trunk_lean_score"
        case trunkLeanStatus = "trunk_lean_status"
        case kneeValgusRiskScore = "knee_valgus_risk_score"
        case kneeValgusStatus = "knee_valgus_status"
        case frameCount = "frame_count"
        case videoDurationSeconds = "video_duration_seconds"
        case notes
        case videoQualityScore = "video_quality_score"
        case poseDetectionRate = "pose_detection_rate"
        case qualityNotes = "quality_notes"
    }
}

enum RunnerLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
}

struct TesterProfile: Codable, Equatable {
    var nickname: String = ""
    var level: RunnerLevel = .beginner
    var weeklyMileageKm: Double = 15
    var target: String = "General fitness"
    var injuryNote: String = ""
}

enum FeedbackRating: String, Codable, CaseIterable, Identifiable {
    case accurate = "Accurate"
    case partlyAccurate = "Partly accurate"
    case notAccurate = "Not accurate"
    case confusing = "Confusing"
    var id: String { rawValue }
}

struct AnalysisFeedback: Codable, Identifiable, Equatable {
    let id: UUID
    let rating: FeedbackRating
    let comment: String
    let createdAt: Date
}

struct AnalysisHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let videoFilename: String
    let result: AnalysisResponse
    var feedback: AnalysisFeedback?
}
''')

write('ios/RunFormCoachAI/PoseExtractor.swift', r'''
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

    func extract(from videoURL: URL) async throws -> PoseMetrics {
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
        guard framePoses.count >= 8 else { throw ExtractionError.insufficientFrames(framePoses.count) }

        var notes: [String] = []
        var qualityNotes: [String] = []
        if durationSeconds < 8 { qualityNotes.append("Clip is short. Use 10–20 seconds for better cadence and gait-cycle stability.") }
        if durationSeconds > 30 { qualityNotes.append("Clip is long. Trim to 10–20 seconds for faster, cleaner analysis.") }
        if detectionRate < 0.70 { qualityNotes.append("Pose detection rate is \(Int(detectionRate * 100))%. Use clearer lighting, tighter clothing, and keep full body in frame.") }
        if failCount > sampleTimes.count / 3 { qualityNotes.append("Many frames did not contain a usable full-body pose.") }

        let avgCompleteness = framePoses.map { $0.completeness }.reduce(0,+) / Double(framePoses.count)
        if avgCompleteness < 0.65 { qualityNotes.append("Some joints are missing. Make sure head, hips, knees and feet stay visible.") }

        let avgConfidence = framePoses.map { $0.averageConfidence }.reduce(0,+) / Double(framePoses.count)
        if avgConfidence < 0.55 { qualityNotes.append("Pose confidence is low. Improve lighting and avoid loose/dark clothing blending into the background.") }

        let videoQualityScore = clamp(0.45 * detectionRate + 0.35 * avgCompleteness + 0.20 * avgConfidence, 0.05, 0.98)
        if videoQualityScore < 0.65 { notes.append("Video quality score \(Int(videoQualityScore * 100))%; biomechanical metrics should be treated as approximate.") }

        let leftAnkleY = smooth(framePoses.compactMap { $0.leftAnkle?.y })
        let rightAnkleY = smooth(framePoses.compactMap { $0.rightAnkle?.y })
        let totalSteps = countPeaks(in: leftAnkleY) + countPeaks(in: rightAnkleY)
        let cadenceSPM = durationSeconds > 0 ? Double(totalSteps) / durationSeconds * 60.0 : 0
        let (cadenceScore, cadenceStatus): (Double, String)
        switch cadenceSPM {
        case ..<140: (cadenceScore, cadenceStatus) = (max(0.25, cadenceSPM / 180.0), "Needs work")
        case 140..<160: (cadenceScore, cadenceStatus) = (0.55, "Moderate")
        case 160...185: (cadenceScore, cadenceStatus) = (0.90, "Good")
        default: (cadenceScore, cadenceStatus) = (0.70, "Moderate")
        }

        let stanceThreshold = percentile(framePoses.flatMap { [$0.leftAnkle?.y, $0.rightAnkle?.y].compactMap { $0 } }, p: 0.35) ?? 0.28
        var overstrideValues: [Double] = []
        for pose in framePoses {
            guard let hipMidX = avgX(pose.leftHip, pose.rightHip) else { continue }
            if let la = pose.leftAnkle, la.y < stanceThreshold { overstrideValues.append(abs(la.x - hipMidX)) }
            if let ra = pose.rightAnkle, ra.y < stanceThreshold { overstrideValues.append(abs(ra.x - hipMidX)) }
        }
        let avgOverstride = overstrideValues.isEmpty ? 0.12 : overstrideValues.reduce(0, +) / Double(overstrideValues.count)
        let overstrideScore = 1.0 - clamp((avgOverstride - 0.05) / 0.17, 0, 1)
        let overstrideStatus = overstrideScore > 0.70 ? "Good" : overstrideScore > 0.45 ? "Moderate" : "Needs work"

        var trunkAngles: [Double] = []
        for pose in framePoses {
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
        for pose in framePoses {
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
            frameCount: framePoses.count,
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
    private func avgX(_ a: JointPoint?, _ b: JointPoint?) -> Double? { average(a?.x, b?.x) }
    private func avgY(_ a: JointPoint?, _ b: JointPoint?) -> Double? { average(a?.y, b?.y) }
    private func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a,b) { case let (.some(x), .some(y)): return (x+y)/2; case let (.some(x), nil): return x; case let (nil, .some(y)): return y; default: return nil }
    }
    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, value)) }
}
''')

write('backend/app/analyzer.py', r'''
import base64
import json
import os
import tempfile
from pathlib import Path

import cv2
from openai import OpenAI

from .schemas import AnalysisResponse, Exercise, Issue, Metric, PoseMetricsInput

_SYSTEM_PROMPT = """You are an expert running coach and sports biomechanics analyst. Analyze the provided video frames of a person running and give a detailed biomechanical assessment.
Return ONLY valid JSON with this exact structure: { "summary": "<1-2 sentence overall assessment>", "confidence": 0.0, "metrics": [ { "name": "", "score": 0.0, "status": "", "explanation": "" } ], "issues": [ { "title": "", "severity": "", "explanation": "", "recommended_exercises": [ { "name": "", "category": "", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": "" } ] } ] }
Always evaluate exactly these 4 metrics in order: 1. Hip stability 2. Knee tracking 3. Trunk control 4. Overstride risk. If unclear due to video angle or quality, assign a moderate score and note the limitation. Provide 1-3 issues with 2 exercises each."""

_METRICS_SYSTEM_PROMPT = """You are an expert running coach and sports biomechanics analyst.
You are given biomechanical metrics extracted from on-device Apple Vision pose detection.
Return ONLY valid JSON with this exact structure: { "summary": "<1-2 sentence overall assessment referencing the numbers and video quality>", "confidence": 0.0, "issues": [ { "title": "", "severity": "", "explanation": "", "recommended_exercises": [ { "name": "", "category": "", "sets": 0, "reps": "", "frequency_per_week": 0, "reason": "" } ] } ] }
Rules:
- Only generate issues for metrics with status "Needs work" or "Moderate". Skip "Good" metrics unless all metrics are Good.
- If video_quality_score < 0.65, lower confidence and explicitly say the report is approximate.
- Provide 2 recommended exercises per issue.
- Maximum 3 issues."""


def _extract_frames(video_path: str, num_frames: int = 8) -> list[str]:
    cap = cv2.VideoCapture(video_path)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total == 0:
        cap.release()
        return []
    indices = [int(i * total / num_frames) for i in range(num_frames)]
    frames: list[str] = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if ret:
            _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            frames.append(base64.b64encode(buf).decode("utf-8"))
    cap.release()
    return frames


def _parse_issues(data: dict) -> list[Issue]:
    return [
        Issue(
            title=iss["title"],
            severity=iss["severity"],
            explanation=iss["explanation"],
            recommended_exercises=[Exercise(**e) for e in iss.get("recommended_exercises", [])],
        )
        for iss in data.get("issues", [])
    ]


def analyze_running_video(video_bytes: bytes, filename: str) -> AnalysisResponse:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable is not set.")
    suffix = Path(filename).suffix or ".mp4"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(video_bytes)
        tmp_path = tmp.name
    try:
        frames_b64 = _extract_frames(tmp_path)
    finally:
        os.unlink(tmp_path)
    if not frames_b64:
        raise ValueError("Could not extract frames from the uploaded video.")

    content: list[dict] = [{"type": "text", "text": "Analyze the running form shown in these video frames:"}]
    for b64 in frames_b64:
        content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "low"}})

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": _SYSTEM_PROMPT}, {"role": "user", "content": content}],
        max_tokens=2000,
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content)
    return AnalysisResponse(
        summary=data["summary"],
        confidence=float(data["confidence"]),
        metrics=[Metric(**m) for m in data["metrics"]],
        issues=_parse_issues(data),
    )


def analyze_from_metrics(pose_input: PoseMetricsInput) -> AnalysisResponse:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable is not set.")

    cadence_explanation = f"Estimated cadence: {pose_input.cadence_estimate_spm:.0f} steps/min (target 160–180 spm). " + ("Consider smaller, quicker steps." if pose_input.cadence_status != "Good" else "Cadence is in the optimal range.")
    trunk_explanation = f"Average trunk angle: {abs(pose_input.trunk_lean_degrees):.1f}°. " + ("Check whether the runner is leaning from the hips instead of the ankles." if pose_input.trunk_lean_status != "Good" else "Trunk alignment looks solid.")
    quality_pct = int(pose_input.video_quality_score * 100)

    metrics = [
        Metric(name="Video quality", score=round(pose_input.video_quality_score, 2), status="Good" if pose_input.video_quality_score >= 0.75 else "Moderate" if pose_input.video_quality_score >= 0.55 else "Needs work", explanation=f"Pose detection rate {int(pose_input.pose_detection_rate * 100)}%. Higher quality means more trustworthy metrics."),
        Metric(name="Cadence", score=round(pose_input.cadence_score, 2), status=pose_input.cadence_status, explanation=cadence_explanation),
        Metric(name="Overstride risk", score=round(pose_input.overstride_risk_score, 2), status=pose_input.overstride_status, explanation="Foot landing position relative to hip center of mass. " + ("Foot may be landing ahead of the body." if pose_input.overstride_status != "Good" else "Foot strike looks well-positioned under the body.")),
        Metric(name="Trunk lean", score=round(pose_input.trunk_lean_score, 2), status=pose_input.trunk_lean_status, explanation=trunk_explanation),
        Metric(name="Knee valgus / hip stability", score=round(pose_input.knee_valgus_risk_score, 2), status=pose_input.knee_valgus_status, explanation="Knee tracking relative to the hip-ankle alignment during stance. " + ("Inward knee collapse detected — suggests hip abductor control work." if pose_input.knee_valgus_status != "Good" else "Knee alignment during stance looks stable.")),
    ]

    all_notes = pose_input.notes + pose_input.quality_notes
    notes_str = " Notes: " + "; ".join(all_notes) if all_notes else ""
    user_message = f"""Running form metrics from on-device Apple Vision pose detection:
- Video quality: {quality_pct}% | pose detection rate {pose_input.pose_detection_rate:.2f}
- Cadence: {pose_input.cadence_estimate_spm:.0f} steps/min | score {pose_input.cadence_score:.2f} | {pose_input.cadence_status}
- Overstride risk: score {pose_input.overstride_risk_score:.2f} | {pose_input.overstride_status}
- Trunk lean: {pose_input.trunk_lean_degrees:.1f}° | score {pose_input.trunk_lean_score:.2f} | {pose_input.trunk_lean_status}
- Knee valgus / hip stability: score {pose_input.knee_valgus_risk_score:.2f} | {pose_input.knee_valgus_status}
- Frames analyzed: {pose_input.frame_count} over {pose_input.video_duration_seconds:.1f}s{notes_str}
Generate targeted coaching issues and exercise recommendations based on these measurements."""

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "system", "content": _METRICS_SYSTEM_PROMPT}, {"role": "user", "content": user_message}],
        max_tokens=1500,
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content)
    metric_avg = sum(m.score for m in metrics[1:]) / 4
    quality_adjusted_confidence = min(float(data.get("confidence", metric_avg)), pose_input.video_quality_score + 0.20, 0.95)
    return AnalysisResponse(
        summary=data["summary"],
        confidence=round(quality_adjusted_confidence, 2),
        metrics=metrics,
        issues=_parse_issues(data),
        video_quality_score=round(pose_input.video_quality_score, 2),
        quality_notes=pose_input.quality_notes,
    )
''')

write('ios/RunFormCoachAI/AnalysisResultView.swift', r'''
import SwiftUI

struct AnalysisResultView: View {
    let result: AnalysisResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreCard
            if let score = result.videoQualityScore { qualityCard(score: score) }
            metricsSection
            issuesSection
        }
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
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.actionGradient)
                    .frame(width: 42, height: 42)
                Image(systemName: "dumbbell.fill").foregroundStyle(.black)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("\(exercise.category) • \(exercise.sets) sets • \(exercise.reps) • \(exercise.frequencyPerWeek)x/week")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                Text(exercise.reason).font(.caption).foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
''')

print('\nPhase 1 Reliability patch applied. Run: git diff, then rebuild iOS and redeploy backend.')
