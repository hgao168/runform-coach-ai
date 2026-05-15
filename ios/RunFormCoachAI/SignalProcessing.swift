import Foundation

// MARK: - Signal-processing pure functions (no Vision / UIKit dependency)

/// Namespace for pure signal-processing functions used by PoseExtractor.
/// All functions are deterministic, side-effect-free, and independently testable.
enum SignalProcessing {

    /// Clamp a value between lo and hi.
    static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, value))
    }

    /// 3-point moving-average smoothing.
    static func smooth(_ values: [Double]) -> [Double] {
        guard values.count >= 3 else { return values }
        return values.indices.map { i in
            let lo = max(0, i - 1), hi = min(values.count - 1, i + 1)
            let slice = values[lo...hi]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    /// Wider moving-average smoothing (default 5-point) used for cadence signals.
    static func smoothWide(_ values: [Double], window: Int = 5) -> [Double] {
        guard values.count >= 3 else { return values }
        let half = window / 2
        return values.indices.map { i in
            let lo = max(0, i - half), hi = min(values.count - 1, i + half)
            let slice = values[lo...hi]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    /// Peak detection with relative prominence: adapts to actual signal amplitude.
    static func countPeaksRobust(in values: [Double]) -> Int {
        guard values.count > 4 else { return 0 }
        let vMin = values.min() ?? 0
        let vMax = values.max() ?? 0
        let range = vMax - vMin
        guard range > 0.005 else { return 0 }
        // Require peak to stand at least 10% of signal range above surrounding valley
        let prominence = max(0.010, range * 0.10)
        var count = 0
        for i in 1..<(values.count - 1) {
            guard values[i] > values[i - 1] && values[i] > values[i + 1] else { continue }
            // Compare against min in ±3-sample neighbourhood for broader context
            let lo = max(0, i - 3), hi = min(values.count - 1, i + 3)
            let localMin = values[lo...hi].min() ?? 0
            if values[i] - localMin >= prominence { count += 1 }
        }
        return count
    }

    /// Simple peak detection with minimum prominence threshold.
    static func countPeaks(in values: [Double], minProminence: Double = 0.025) -> Int {
        guard values.count > 2 else { return 0 }
        var count = 0
        for i in 1..<(values.count - 1) where values[i] > values[i - 1] && values[i] > values[i + 1] {
            if values[i] - max(values[i - 1], values[i + 1]) >= minProminence { count += 1 }
        }
        return count
    }

    /// Count upward zero-crossings of the mean-centred signal.
    static func zeroCrossingSteps(in values: [Double]) -> Int {
        guard values.count > 4 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        var crossings = 0
        for i in 1..<values.count where values[i - 1] < mean && values[i] >= mean {
            crossings += 1
        }
        return crossings
    }

    /// Pearson correlation coefficient.
    static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = min(x.count, y.count)
        guard n >= 3 else { return 0.0 }
        let xs = Array(x.prefix(n))
        let ys = Array(y.prefix(n))
        let mx = xs.reduce(0, +) / Double(n)
        let my = ys.reduce(0, +) / Double(n)
        var num = 0.0
        var denX = 0.0
        var denY = 0.0
        for i in 0..<n {
            let dx = xs[i] - mx
            let dy = ys[i] - my
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }
        guard denX > 0.000001, denY > 0.000001 else { return 0.0 }
        return num / sqrt(denX * denY)
    }

    /// Median of an array.
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }

    /// Percentile value from sorted array.
    static func percentile(_ values: [Double], p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let idx = Int(clamp(p, 0, 1) * Double(sorted.count - 1))
        return sorted[idx]
    }

    /// Mean confidence of a list of values.
    static func meanConfidence(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Qualitative confidence band label.
    static func confidenceBand(_ value: Double) -> String {
        switch value {
        case ..<0.45: return "low"
        case ..<0.70: return "medium"
        default: return "high"
        }
    }

    /// X-axis spread between two optional points.
    static func spreadX(_ ax: Double?, _ bx: Double?) -> Double? {
        guard let ax, let bx else { return nil }
        return abs(ax - bx)
    }

    /// Safe average of two optional Doubles.
    static func average(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (.some(x), .some(y)): return (x + y) / 2
        case let (.some(x), nil): return x
        case let (nil, .some(y)): return y
        default: return nil
        }
    }

    /// Angle at vertex: angle ABC where B is the vertex.
    static func angleAtVertex(ax: Double, ay: Double, vx: Double, vy: Double, cx: Double, cy: Double) -> Double {
        let v1x = ax - vx
        let v1y = ay - vy
        let v2x = cx - vx
        let v2y = cy - vy
        let dot = v1x * v2x + v1y * v2y
        let n1 = sqrt(v1x * v1x + v1y * v1y)
        let n2 = sqrt(v2x * v2x + v2y * v2y)
        guard n1 > 0.0001, n2 > 0.0001 else { return 180.0 }
        let cosTheta = clamp(dot / (n1 * n2), -1.0, 1.0)
        return acos(cosTheta) * 180.0 / .pi
    }

    /// Weighted average of (value, weight) pairs. Zeros are excluded.
    static func weightedAverage(_ values: [(Double, Double)]) -> Double {
        var weighted = 0.0
        var weightTotal = 0.0
        for (value, weight) in values where value > 0 {
            weighted += value * weight
            weightTotal += weight
        }
        guard weightTotal > 0 else { return 0.0 }
        return clamp(weighted / weightTotal, 0.0, 1.0)
    }
}
