import Foundation
import os.log

// MARK: - GaitAnalyzer

/// Real-time gait metric extractor using fused accelerometer + gyroscope data.
///
/// Computes from a sliding window of `SensorFrame` samples:
/// - **Vertical oscillation** (cm): Double-integrate vertical acceleration after gravity removal.
/// - **Ground contact time** (ms): Estimated from gyroscope pitch-rate zero-crossing during stance.
/// - **Trunk lean angle** (degrees): Tilt of the gravity vector in the sagittal plane.
///
/// Uses `SignalProcessing` pure functions for smoothing and statistics.
/// Biomechanical formulas are aligned with `PoseExtractor`'s video-based analysis.
public final class GaitAnalyzer: @unchecked Sendable {

    // MARK: - Configuration

    /// Analysis window duration in seconds.
    public let windowSeconds: TimeInterval

    /// Assumed sampling rate (Hz) — used for integration time-step.
    public let samplingRate: Double

    /// Gravity magnitude threshold for lean estimation (g).
    private let gravityThreshold: Double = 0.85

    // MARK: - State

    /// Most recent gait snapshot.
    public private(set) var currentSnapshot: GaitSnapshot?

    /// Latest cadence SPM value, injected by RunSessionManager from CadenceDetector.
    public var latestCadenceSPM: Double = 0.0

    /// Rolling statistics for the current window.
    public private(set) var verticalOscillationStats: (mean: Double, stdDev: Double, trend: Double)?

    /// Callback invoked when a new gait snapshot is computed.
    public var onGaitUpdate: (@Sendable (GaitSnapshot) -> Void)?

    // MARK: - Private

    private let queue = DispatchQueue(label: "com.runformcoachai.gait")
    private var accelZHistory: [Double] = []       // vertical acceleration
    private var accelYHistory: [Double] = []       // forward acceleration (for lean)
    private var gyroXHistory: [Double] = []        // pitch rate (for GCT)
    private var timestamps: [TimeInterval] = []
    private var frameCount: Int = 0
    private var lastSnapshotTime: Date?

    // Integration state for vertical oscillation
    private var velocityZ: Double = 0.0
    private var positionZ: Double = 0.0
    private var positionZHistory: [Double] = []
    private var lastTimestamp: TimeInterval?

    // Gravity estimate (slow-moving baseline of accelZ)
    private var gravityBaseline: Double = -1.0

    private var maxHistorySamples: Int {
        max(Int(windowSeconds * samplingRate), 60)
    }

    // MARK: - Init

    /// - Parameters:
    ///   - windowSeconds: Analysis window (default 5.0, range 3–10).
    ///   - samplingRate: Expected sensor rate in Hz (default 60).
    public init(windowSeconds: TimeInterval = 5.0, samplingRate: Double = 60) {
        self.windowSeconds = max(3, min(10, windowSeconds))
        self.samplingRate = samplingRate
    }

    // MARK: - Public API

    /// Feed a single `SensorFrame` and optionally produce a gait update.
    /// - Parameter frame: The sensor data point.
    public func process(frame: SensorFrame) {
        queue.async { [weak self] in
            self?.processSync(frame)
        }
    }

    /// Process a batch of frames (e.g., from ring buffer snapshot).
    /// - Parameter frames: Array of sensor frames in time order.
    public func processBatch(_ frames: [SensorFrame]) {
        queue.async { [weak self] in
            for frame in frames {
                self?.processSync(frame)
            }
        }
    }

    /// Reset all accumulated state.
    public func reset() {
        queue.sync {
            accelZHistory.removeAll(keepingCapacity: true)
            accelYHistory.removeAll(keepingCapacity: true)
            gyroXHistory.removeAll(keepingCapacity: true)
            timestamps.removeAll(keepingCapacity: true)
            positionZHistory.removeAll(keepingCapacity: true)
            frameCount = 0
            velocityZ = 0.0
            positionZ = 0.0
            lastTimestamp = nil
            gravityBaseline = -1.0
            currentSnapshot = nil
            verticalOscillationStats = nil
            lastSnapshotTime = nil
        }
    }

    // MARK: - Private processing

    private func processSync(_ frame: SensorFrame) {
        frameCount += 1

        // Append to history buffers
        accelZHistory.append(frame.accelerationZ)
        accelYHistory.append(frame.accelerationY)
        gyroXHistory.append(frame.rotationRateX)
        timestamps.append(frame.timestamp)

        // Enforce window
        while accelZHistory.count > maxHistorySamples {
            accelZHistory.removeFirst()
            accelYHistory.removeFirst()
            gyroXHistory.removeFirst()
            timestamps.removeFirst()
            if !positionZHistory.isEmpty { positionZHistory.removeFirst() }
        }

        // --- Vertical Oscillation via double-integration ---

        // Update gravity baseline with slow exponential smoothing
        let alphaGrav = 0.95  // slow adaptation
        gravityBaseline = alphaGrav * gravityBaseline + (1.0 - alphaGrav) * frame.accelerationZ

        // Remove gravity → dynamic vertical acceleration
        let dynamicAccelZ = frame.accelerationZ - gravityBaseline

        // Integrate: v[n] = v[n-1] + a[n] * dt
        if let lastTS = lastTimestamp {
            let dt = max(0.001, frame.timestamp - lastTS)
            velocityZ += dynamicAccelZ * dt

            // High-pass filter velocity to remove drift (τ = 1.5s)
            let alphaVel = exp(-dt / 1.5)
            velocityZ *= alphaVel

            // Integrate velocity → position
            positionZ += velocityZ * dt

            // Drift compensation: leak position toward zero slowly
            positionZ *= 0.998
        }
        lastTimestamp = frame.timestamp

        positionZHistory.append(positionZ)
        while positionZHistory.count > maxHistorySamples {
            positionZHistory.removeFirst()
        }

        // --- Trunk Lean Angle ---

        // From accelerometer: lean ≈ atan2(accelY, -accelZ) when phone is portrait
        // accelY = forward, accelZ = up (negative when upright due to gravity)
        // lean > 0 = forward lean
        let smoothedAccelY = exponentialSmooth(accelYHistory, alpha: 0.9)
        let smoothedAccelZ = exponentialSmooth(accelZHistory, alpha: 0.9)
        let leanRadians = atan2(smoothedAccelY, -smoothedAccelZ)
        let trunkLeanDeg = leanRadians * 180.0 / .pi

        // --- Ground Contact Time ---

        // Estimated from gyro pitch-rate pattern:
        // During foot strike, there's a rapid pitch deceleration spike.
        // GCT ≈ width of gyro spike above threshold.
        let gctEstimate = estimateGCT(from: gyroXHistory)

        // --- Compute snapshot ---
        let vertOscCm = computeVerticalOscillation()

        // Update rolling statistics
        if positionZHistory.count >= 10 {
            let meanPos = positionZHistory.reduce(0, +) / Double(positionZHistory.count)
            let stdPos = stdDev(positionZHistory)
            // Trend: slope of linear regression on last N samples
            let trend = computeTrend(positionZHistory)
            verticalOscillationStats = (mean: meanPos, stdDev: stdPos, trend: trend)
        }

        // Gentle per-frame velocity decay prevents unbounded drift without visible jumps.
        // 0.9995 per frame at 60 Hz ≈ 3% decay per second — smooth and imperceptible.
        velocityZ *= 0.9995

        // Emit snapshot (throttled: at most every 1.0s)
        let now = Date()
        if let last = lastSnapshotTime, now.timeIntervalSince(last) < 1.0 {
            return
        }
        lastSnapshotTime = now

        let cadenceForSnapshot: Double = latestCadenceSPM

        let snapshot = GaitSnapshot(
            verticalOscillationCm: vertOscCm,
            groundContactTimeMs: gctEstimate,
            trunkLeanDegrees: trunkLeanDeg,
            cadenceSPM: cadenceForSnapshot,
            timestamp: now
        )
        currentSnapshot = snapshot
        onGaitUpdate?(snapshot)
    }

    // MARK: - Metric computations

    /// Vertical oscillation amplitude from position history (peak-to-peak / 2, in cm).
    /// G-force to cm conversion: 1g ≈ 9.81 m/s², acceleration double-integrated.
    private func computeVerticalOscillation() -> Double {
        guard positionZHistory.count >= 10 else { return 0 }

        // positionZ is in meters (g * s² → multiply by 9.81 to get meters)
        let positionsM = positionZHistory.map { $0 * 9.81 }
        let pMin = positionsM.min() ?? 0
        let pMax = positionsM.max() ?? 0
        let amplitudeM = (pMax - pMin) / 2.0
        let amplitudeCm = amplitudeM * 100.0

        return SignalProcessing.clamp(amplitudeCm, 0, 35)
    }

    /// Estimate ground contact time from gyroscope pitch-rate signal.
    ///
    /// During stance, the foot acts as a pivot producing a rapid pitch rotation.
    /// GCT ≈ duration the gyro magnitude stays above 30% of its peak.
    private func estimateGCT(from gyroHistory: [Double]) -> Double {
        guard gyroHistory.count >= 10 else { return 0 }

        let absGyro = gyroHistory.map { abs($0) }
        guard let peak = absGyro.max(), peak > 0.1 else { return 0 }

        let threshold = peak * 0.3
        var aboveThreshold = 0
        for val in absGyro where val >= threshold {
            aboveThreshold += 1
        }

        // Convert sample count to milliseconds
        let durationSec = Double(aboveThreshold) / samplingRate
        let durationMs = durationSec * 1000.0

        // Typical GCT for runners: 150–300ms
        return SignalProcessing.clamp(durationMs, 80, 500)
    }

    /// Exponential moving average of the last value in history.
    private func exponentialSmooth(_ history: [Double], alpha: Double) -> Double {
        guard !history.isEmpty else { return 0 }
        guard history.count > 1 else { return history[0] }
        // Use the latest value as anchor, blend slightly with history
        let latest = history.last!
        let prevAvg = history.dropLast().reduce(0, +) / Double(history.count - 1)
        return alpha * prevAvg + (1.0 - alpha) * latest
    }

    /// Simple trend: sign of difference between recent and older halves.
    private func computeTrend(_ values: [Double]) -> Double {
        let n = values.count
        guard n >= 8 else { return 0 }
        let mid = n / 2
        let olderMean = values[0..<mid].reduce(0, +) / Double(mid)
        let recentMean = values[mid..<n].reduce(0, +) / Double(n - mid)
        return recentMean - olderMean
    }

    /// Population standard deviation.
    private func stdDev(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }
        let m = values.reduce(0, +) / n
        let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / n
        return sqrt(variance)
    }
}
