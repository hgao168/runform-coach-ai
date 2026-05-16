import Foundation
import os.log

// MARK: - CadenceDetector

/// Real-time step-frequency detector using accelerometer data.
///
/// Pipeline:
/// 1. Low-pass filter (α = 0.8) to isolate the ~2–4 Hz step signal from high-frequency noise.
/// 2. Mean-centre the filtered signal.
/// 3. Zero-crossing detection to count steps.
/// 4. Convert step count in window → steps per minute (SPM).
/// 5. Apply hysteresis and confidence scoring.
///
/// Integrates with `SignalProcessing` pure functions for peak detection and smoothing.
public final class CadenceDetector: @unchecked Sendable {

    // MARK: - Configuration

    /// Low-pass filter smoothing factor (0 = no filtering, 1 = maximum smoothing).
    /// α = 0.8 is tuned for running cadence (~2.5–3.2 Hz) at 60 Hz sampling.
    public let alpha: Double

    /// Minimum plausible cadence in SPM (below this → flagged low confidence).
    public let minCadenceSPM: Double

    /// Maximum plausible cadence in SPM (above this → clamped).
    public let maxCadenceSPM: Double

    /// The analysis window duration in seconds.
    public let windowSeconds: TimeInterval

    // MARK: - State

    /// Most recent cadence estimate.
    public private(set) var currentCadence: CadenceSample?

    /// Callback invoked when a new cadence estimate is available.
    /// Called on an internal serial queue — dispatch to main if updating UI.
    public var onCadenceUpdate: (@Sendable (CadenceSample) -> Void)?

    // MARK: - Private

    private let queue = DispatchQueue(label: "com.runformcoachai.cadence")
    private var filteredValue: Double = 0.0
    private var filteredHistory: [Double] = []
    private var rawHistory: [Double] = []
    private var sampleCount: Int = 0
    private var lastStepTime: TimeInterval?
    private var stepIntervals: [Double] = []  // recent step-to-step intervals in seconds

    // Maximum number of samples in history (windowSeconds * ~60 Hz)
    private var maxHistorySamples: Int {
        max(Int(windowSeconds * 60), 90)
    }

    // MARK: - Init

    /// - Parameters:
    ///   - alpha: Low-pass filter factor (default 0.8).
    ///   - minCadenceSPM: Minimum plausible cadence (default 50).
    ///   - maxCadenceSPM: Maximum plausible cadence (default 240).
    ///   - windowSeconds: Analysis window duration (default 5).
    public init(
        alpha: Double = 0.8,
        minCadenceSPM: Double = 50,
        maxCadenceSPM: Double = 240,
        windowSeconds: TimeInterval = 5
    ) {
        self.alpha = SignalProcessing.clamp(alpha, 0.0, 1.0)
        self.minCadenceSPM = minCadenceSPM
        self.maxCadenceSPM = maxCadenceSPM
        self.windowSeconds = windowSeconds
    }

    // MARK: - Public API

    /// Feed a single accelerometer magnitude sample and optionally produce a cadence update.
    ///
    /// The caller should pass the magnitude of the accelerometer vector:
    /// `sqrt(accelX² + accelY² + accelZ²)` or just the vertical axis `accelZ`
    /// depending on phone orientation. For best results, use the axis most aligned
    /// with the vertical (gravity) direction.
    ///
    /// - Parameter value: The accelerometer magnitude or single-axis value (g-force).
    public func process(value: Double) {
        queue.async { [weak self] in
            self?.processSync(value)
        }
    }

    /// Process a batch of samples at once (e.g., from a ring buffer snapshot).
    /// - Parameter values: Array of accelerometer magnitudes in time order.
    public func processBatch(_ values: [Double]) {
        queue.async { [weak self] in
            for v in values {
                self?.processSync(v)
            }
        }
    }

    /// Reset the detector state.
    public func reset() {
        queue.sync {
            filteredValue = 0.0
            filteredHistory.removeAll(keepingCapacity: true)
            rawHistory.removeAll(keepingCapacity: true)
            sampleCount = 0
            lastStepTime = nil
            stepIntervals.removeAll(keepingCapacity: true)
            currentCadence = nil
        }
    }

    // MARK: - Private processing

    private func processSync(_ value: Double) {
        // 1. Low-pass filter: y[n] = α * y[n-1] + (1-α) * x[n]
        filteredValue = alpha * filteredValue + (1.0 - alpha) * value
        filteredHistory.append(filteredValue)
        rawHistory.append(value)
        sampleCount += 1

        // Enforce history window
        while filteredHistory.count > maxHistorySamples {
            filteredHistory.removeFirst()
            rawHistory.removeFirst()
        }

        // 2. Mean-centre and zero-crossing detection
        guard filteredHistory.count >= 5 else { return }

        let mean = filteredHistory.reduce(0, +) / Double(filteredHistory.count)

        // Detect upward zero-crossings in recent tail of filtered history
        // We look at the last few samples to detect new steps
        let recentCount = min(filteredHistory.count, 8)
        let startIdx = filteredHistory.count - recentCount

        for i in (startIdx + 1)..<filteredHistory.count {
            let prev = filteredHistory[i - 1] - mean
            let curr = filteredHistory[i] - mean
            if prev < 0 && curr >= 0 {
                // Upward zero-crossing = step detected
                let stepTime = Double(sampleCount - (filteredHistory.count - i)) / 60.0
                // Prevent double-counting: enforce minimum 0.15s between steps (~400 SPM max)
                if let last = lastStepTime {
                    let interval = max(0.15, stepTime - last)
                    stepIntervals.append(interval)
                    while stepIntervals.count > 60 { stepIntervals.removeFirst() }
                }
                lastStepTime = stepTime
            }
        }

        // 3. Compute cadence from step intervals
        let cadenceSPM: Double
        let confidence: Double

        if stepIntervals.count >= 2 {
            let avgInterval = stepIntervals.reduce(0, +) / Double(stepIntervals.count)
            cadenceSPM = SignalProcessing.clamp(60.0 / avgInterval, minCadenceSPM, maxCadenceSPM)
            // Confidence based on interval consistency and sample count
            let cv = stepIntervals.count >= 3
                ? stdDev(stepIntervals) / avgInterval
                : 1.0
            let consistencyScore = SignalProcessing.clamp(1.0 - cv, 0.0, 1.0)
            let sampleScore = min(1.0, Double(stepIntervals.count) / 8.0)
            confidence = 0.5 * consistencyScore + 0.5 * sampleScore
        } else if filteredHistory.count >= maxHistorySamples / 2 {
            // Fallback: use zeroCrossingSteps from SignalProcessing on the window
            let smoothValues = SignalProcessing.smoothWide(filteredHistory)
            let zcCount = SignalProcessing.zeroCrossingSteps(in: smoothValues)
            let windowTime = Double(filteredHistory.count) / 60.0
            let rawSPM = windowTime > 0 ? Double(zcCount) / windowTime * 60.0 : 0
            cadenceSPM = SignalProcessing.clamp(rawSPM, minCadenceSPM, maxCadenceSPM)
            confidence = max(0.1, min(0.6, Double(zcCount) / 15.0))
        } else {
            return // not enough data yet
        }

        // 4. Emit update (throttled: at most every 0.5s to avoid flooding)
        let sample = CadenceSample(
            stepsPerMinute: cadenceSPM,
            confidence: confidence,
            windowDuration: windowSeconds
        )

        if let current = currentCadence {
            let interval = sample.timestamp.timeIntervalSince(current.timestamp)
            guard interval >= 0.5 else { return }
        }

        currentCadence = sample
        onCadenceUpdate?(sample)
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
