import XCTest
@testable import RunFormCoachAI

/// Unit tests for the 15 pure functions extracted to SignalProcessing.swift (RF-403).
final class PoseExtractorTests: XCTestCase {

    // MARK: - clamp

    func testClamp_WithinRange_ReturnsValue() {
        XCTAssertEqual(SignalProcessing.clamp(5.0, 0, 10), 5.0)
        XCTAssertEqual(SignalProcessing.clamp(0.0, 0, 10), 0.0)
        XCTAssertEqual(SignalProcessing.clamp(10.0, 0, 10), 10.0)
    }

    func testClamp_BelowRange_ReturnsLo() {
        XCTAssertEqual(SignalProcessing.clamp(-1.0, 0, 10), 0.0)
        XCTAssertEqual(SignalProcessing.clamp(-100.0, -50, 50), -50.0)
    }

    func testClamp_AboveRange_ReturnsHi() {
        XCTAssertEqual(SignalProcessing.clamp(11.0, 0, 10), 10.0)
        XCTAssertEqual(SignalProcessing.clamp(200.0, -50, 50), 50.0)
    }

    func testClamp_ZeroRange_ReturnsBoundary() {
        XCTAssertEqual(SignalProcessing.clamp(5.0, 5.0, 5.0), 5.0)
        XCTAssertEqual(SignalProcessing.clamp(0.0, 5.0, 5.0), 5.0)
        XCTAssertEqual(SignalProcessing.clamp(10.0, 5.0, 5.0), 5.0)
    }

    func testClamp_NegativeRange() {
        XCTAssertEqual(SignalProcessing.clamp(-3.0, -10, -2), -3.0)
        XCTAssertEqual(SignalProcessing.clamp(0.0, -10, -2), -2.0)
    }

    // MARK: - smooth (3-point moving average)

    func testSmooth_FewerThanThree_ReturnsInput() {
        XCTAssertEqual(SignalProcessing.smooth([]), [])
        XCTAssertEqual(SignalProcessing.smooth([1.0]), [1.0])
        XCTAssertEqual(SignalProcessing.smooth([1.0, 2.0]), [1.0, 2.0])
    }

    func testSmooth_ThreePoints() {
        let result = SignalProcessing.smooth([1.0, 2.0, 3.0])
        // i=0: (1+2)/2=1.5 | i=1: (1+2+3)/3=2.0 | i=2: (2+3)/2=2.5
        XCTAssertEqual(result, [1.5, 2.0, 2.5])
    }

    func testSmooth_FivePoints() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result = SignalProcessing.smooth(values)
        // i=0: (1+2)/2=1.5 | i=4: (4+5)/2=4.5 | i=2: (2+3+4)/3=3.0
        XCTAssertEqual(result[0], 1.5)
        XCTAssertEqual(result[2], 3.0)
        XCTAssertEqual(result[4], 4.5)
    }

    func testSmooth_PreservesCount() {
        let values = Array(stride(from: 0.0, to: 100.0, by: 1.0))
        XCTAssertEqual(SignalProcessing.smooth(values).count, values.count)
    }

    // MARK: - smoothWide

    func testSmoothWide_FewerThanThree_ReturnsInput() {
        XCTAssertEqual(SignalProcessing.smoothWide([]), [])
        XCTAssertEqual(SignalProcessing.smoothWide([1.0]), [1.0])
    }

    func testSmoothWide_DefaultWindow() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result = SignalProcessing.smoothWide(values)
        // window=5, half=2
        // i=0: lo=0, hi=2 -> [1,2,3] avg=2.0
        // i=2: lo=0, hi=4 -> [1,2,3,4,5] avg=3.0
        // i=4: lo=2, hi=4 -> [3,4,5] avg=4.0
        XCTAssertEqual(result[0], 2.0)
        XCTAssertEqual(result[2], 3.0)
        XCTAssertEqual(result[4], 4.0)
        XCTAssertEqual(result.count, values.count)
    }

    func testSmoothWide_CustomWindow() {
        let values = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        let result = SignalProcessing.smoothWide(values, window: 3)
        // Window=3, half=1 → same as smooth()
        XCTAssertEqual(SignalProcessing.smoothWide(values, window: 3), SignalProcessing.smooth(values))
    }

    // MARK: - countPeaksRobust

    func testCountPeaksRobust_TooFewSamples_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.countPeaksRobust(in: []), 0)
        XCTAssertEqual(SignalProcessing.countPeaksRobust(in: [1.0]), 0)
        XCTAssertEqual(SignalProcessing.countPeaksRobust(in: [1.0, 2.0, 3.0, 4.0, 5.0]), 0)
    }

    func testCountPeaksRobust_FlatSignal_ReturnsZero() {
        let values = Array(repeating: 1.0, count: 10)
        XCTAssertEqual(SignalProcessing.countPeaksRobust(in: values), 0)
    }

    func testCountPeaksRobust_SinglePeak() {
        // One obvious peak at index 5
        let values: [Double] = [0, 0.1, 0.2, 0.3, 0.4, 1.0, 0.4, 0.3, 0.2, 0.1, 0]
        let count = SignalProcessing.countPeaksRobust(in: values)
        XCTAssertEqual(count, 1)
    }

    func testCountPeaksRobust_LowAmplitude_ReturnsZero() {
        // Range < 0.005 → no peaks detected
        let values: [Double] = [0.0, 0.001, 0.002, 0.003, 0.002, 0.001, 0.0]
        XCTAssertEqual(SignalProcessing.countPeaksRobust(in: values), 0)
    }

    // MARK: - countPeaks

    func testCountPeaks_TooFewSamples_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.countPeaks(in: []), 0)
        XCTAssertEqual(SignalProcessing.countPeaks(in: [1.0]), 0)
        XCTAssertEqual(SignalProcessing.countPeaks(in: [1.0, 2.0]), 0)
    }

    func testCountPeaks_NoPeak_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.countPeaks(in: [1.0, 2.0, 3.0]), 0)
        XCTAssertEqual(SignalProcessing.countPeaks(in: [3.0, 2.0, 1.0]), 0)
    }

    func testCountPeaks_SinglePeak() {
        let result = SignalProcessing.countPeaks(in: [0.0, 1.0, 0.0])
        XCTAssertEqual(result, 1)
    }

    func testCountPeaks_CustomProminence() {
        // Small peak prominence 0.01 < default 0.025
        let values: [Double] = [0.0, 0.02, 0.0]
        XCTAssertEqual(SignalProcessing.countPeaks(in: values, minProminence: 0.025), 0)
        XCTAssertEqual(SignalProcessing.countPeaks(in: values, minProminence: 0.01), 1)
    }

    func testCountPeaks_MultiplePeaks() {
        let values: [Double] = [0, 1, 0, 1, 0, 1, 0]
        XCTAssertEqual(SignalProcessing.countPeaks(in: values), 3)
    }

    // MARK: - zeroCrossingSteps

    func testZeroCrossingSteps_TooFewSamples_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.zeroCrossingSteps(in: []), 0)
        XCTAssertEqual(SignalProcessing.zeroCrossingSteps(in: [1.0, 2.0, 3.0, 4.0, 5.0]), 0)
    }

    func testZeroCrossingSteps_AllAboveMean_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.zeroCrossingSteps(in: [5.0, 5.1, 5.5, 5.0, 5.2, 5.0]), 0)
    }

    func testZeroCrossingSteps_Sinusoid() {
        // sin wave crosses mean=0 going up twice in 2 cycles
        let values: [Double] = [0.0, 0.5, 1.0, 0.5, 0.0, -0.5, -1.0, -0.5, 0.0, 0.5, 1.0]
        let crossings = SignalProcessing.zeroCrossingSteps(in: values)
        XCTAssertGreaterThan(crossings, 0)
    }

    // MARK: - pearsonCorrelation

    func testPearson_TooFewSamples_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.pearsonCorrelation([1.0], [1.0]), 0.0)
        XCTAssertEqual(SignalProcessing.pearsonCorrelation([1.0, 2.0], [1.0, 2.0]), 0.0)
    }

    func testPearson_PerfectPositive() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [2.0, 4.0, 6.0, 8.0, 10.0]
        let r = SignalProcessing.pearsonCorrelation(x, y)
        XCTAssertEqual(r, 1.0, accuracy: 0.0001)
    }

    func testPearson_PerfectNegative() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [5.0, 4.0, 3.0, 2.0, 1.0]
        let r = SignalProcessing.pearsonCorrelation(x, y)
        XCTAssertEqual(r, -1.0, accuracy: 0.0001)
    }

    func testPearson_ZeroVariance_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.pearsonCorrelation([1.0, 1.0, 1.0], [1.0, 2.0, 3.0]), 0.0)
        XCTAssertEqual(SignalProcessing.pearsonCorrelation([1.0, 2.0, 3.0], [1.0, 1.0, 1.0]), 0.0)
    }

    func testPearson_DifferentLengths_UsesMin() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [1.0, 2.0, 3.0]
        let r = SignalProcessing.pearsonCorrelation(x, y)
        XCTAssertEqual(r, 1.0, accuracy: 0.0001)
    }

    // MARK: - median

    func testMedian_Empty_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.median([]), 0.0)
    }

    func testMedian_OddCount() {
        XCTAssertEqual(SignalProcessing.median([3.0, 1.0, 2.0]), 2.0)
        XCTAssertEqual(SignalProcessing.median([5.0]), 5.0)
    }

    func testMedian_EvenCount() {
        XCTAssertEqual(SignalProcessing.median([1.0, 2.0, 3.0, 4.0]), 2.5)
        XCTAssertEqual(SignalProcessing.median([10.0, 20.0]), 15.0)
    }

    // MARK: - percentile

    func testPercentile_Empty_ReturnsNil() {
        XCTAssertNil(SignalProcessing.percentile([], p: 0.5))
    }

    func testPercentile_P0_ReturnsMin() {
        XCTAssertEqual(SignalProcessing.percentile([5.0, 1.0, 3.0, 2.0, 4.0], p: 0), 1.0)
    }

    func testPercentile_P100_ReturnsMax() {
        XCTAssertEqual(SignalProcessing.percentile([5.0, 1.0, 3.0, 2.0, 4.0], p: 1), 5.0)
    }

    func testPercentile_P50_ReturnsMedian() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        XCTAssertEqual(SignalProcessing.percentile(values, p: 0.5), 3.0)
    }

    func testPercentile_ClampedP() {
        let values = [1.0, 2.0, 3.0]
        XCTAssertEqual(SignalProcessing.percentile(values, p: -0.5), 1.0)
        XCTAssertEqual(SignalProcessing.percentile(values, p: 1.5), 3.0)
    }

    // MARK: - meanConfidence

    func testMeanConfidence_Empty_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.meanConfidence([]), 0)
    }

    func testMeanConfidence_NormalValues() {
        XCTAssertEqual(SignalProcessing.meanConfidence([0.5, 0.5, 0.5]), 0.5)
        XCTAssertEqual(SignalProcessing.meanConfidence([0.0, 1.0]), 0.5)
        XCTAssertEqual(SignalProcessing.meanConfidence([0.8, 0.9, 1.0]), 0.9)
    }

    func testMeanConfidence_SingleValue() {
        XCTAssertEqual(SignalProcessing.meanConfidence([0.75]), 0.75)
    }

    // MARK: - confidenceBand

    func testConfidenceBand_Low() {
        XCTAssertEqual(SignalProcessing.confidenceBand(0.0), "low")
        XCTAssertEqual(SignalProcessing.confidenceBand(0.3), "low")
        XCTAssertEqual(SignalProcessing.confidenceBand(0.44), "low")
    }

    func testConfidenceBand_Medium() {
        XCTAssertEqual(SignalProcessing.confidenceBand(0.45), "medium")
        XCTAssertEqual(SignalProcessing.confidenceBand(0.60), "medium")
        XCTAssertEqual(SignalProcessing.confidenceBand(0.69), "medium")
    }

    func testConfidenceBand_High() {
        XCTAssertEqual(SignalProcessing.confidenceBand(0.70), "high")
        XCTAssertEqual(SignalProcessing.confidenceBand(0.85), "high")
        XCTAssertEqual(SignalProcessing.confidenceBand(1.0), "high")
    }

    // MARK: - spreadX

    func testSpreadX_BothNil_ReturnsNil() {
        XCTAssertNil(SignalProcessing.spreadX(nil, nil))
    }

    func testSpreadX_OneNil_ReturnsNil() {
        XCTAssertNil(SignalProcessing.spreadX(1.0, nil))
        XCTAssertNil(SignalProcessing.spreadX(nil, 1.0))
    }

    func testSpreadX_BothValid_ReturnsAbsoluteDifference() {
        XCTAssertEqual(SignalProcessing.spreadX(1.0, 5.0), 4.0)
        XCTAssertEqual(SignalProcessing.spreadX(5.0, 1.0), 4.0)
        XCTAssertEqual(SignalProcessing.spreadX(0.0, 0.0), 0.0)
    }

    // MARK: - average

    func testAverage_BothNil_ReturnsNil() {
        XCTAssertNil(SignalProcessing.average(nil, nil))
    }

    func testAverage_OneNil_ReturnsTheOther() {
        XCTAssertEqual(SignalProcessing.average(5.0, nil), 5.0)
        XCTAssertEqual(SignalProcessing.average(nil, 3.0), 3.0)
    }

    func testAverage_BothValid_ReturnsMean() {
        XCTAssertEqual(SignalProcessing.average(4.0, 6.0), 5.0)
        XCTAssertEqual(SignalProcessing.average(0.0, 10.0), 5.0)
    }

    // MARK: - angleAtVertex

    func testAngleAtVertex_RightAngle() {
        // Vertex at (0,0), A at (1,0), C at (0,1) → 90°
        let angle = SignalProcessing.angleAtVertex(ax: 1, ay: 0, vx: 0, vy: 0, cx: 0, cy: 1)
        XCTAssertEqual(angle, 90.0, accuracy: 0.01)
    }

    func testAngleAtVertex_StraightLine() {
        // V at (1,1), A at (0,0), C at (2,2) → 180°
        let angle = SignalProcessing.angleAtVertex(ax: 0, ay: 0, vx: 1, vy: 1, cx: 2, cy: 2)
        XCTAssertEqual(angle, 180.0, accuracy: 0.01)
    }

    func testAngleAtVertex_ZeroLength_Returns180() {
        // A == V → zero vector → returns 180
        let angle = SignalProcessing.angleAtVertex(ax: 0, ay: 0, vx: 0, vy: 0, cx: 1, cy: 0)
        XCTAssertEqual(angle, 180.0, accuracy: 0.01)
    }

    func testAngleAtVertex_AcuteAngle() {
        // Equilateral triangle: angle ~ 60°
        let angle = SignalProcessing.angleAtVertex(ax: 1, ay: 0, vx: 0, vy: 0, cx: 0.5, cy: 0.8660254)
        XCTAssertEqual(angle, 60.0, accuracy: 0.1)
    }

    // MARK: - weightedAverage

    func testWeightedAverage_Empty_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.weightedAverage([]), 0.0)
    }

    func testWeightedAverage_AllZeros_ReturnsZero() {
        XCTAssertEqual(SignalProcessing.weightedAverage([(0.0, 1.0), (0.0, 2.0)]), 0.0)
    }

    func testWeightedAverage_NormalCase() {
        let result = SignalProcessing.weightedAverage([(0.5, 1.0), (1.0, 1.0)])
        // (0.5*1 + 1.0*1) / (1+1) = 0.75
        XCTAssertEqual(result, 0.75)
    }

    func testWeightedAverage_ClampedToOne() {
        let result = SignalProcessing.weightedAverage([(1.5, 1.0)])
        XCTAssertEqual(result, 1.0)
    }

    func testWeightedAverage_ClampedToZero() {
        let result = SignalProcessing.weightedAverage([(-0.5, 1.0)])
        XCTAssertEqual(result, 0.0)
    }

    func testWeightedAverage_SkipsZeros() {
        // (0, 10) excluded; only (0.8, 1) contributes → 0.8
        let result = SignalProcessing.weightedAverage([(0.0, 10.0), (0.8, 1.0)])
        XCTAssertEqual(result, 0.8)
    }

    func testWeightedAverage_DifferentWeights() {
        let result = SignalProcessing.weightedAverage([(0.2, 1.0), (0.8, 3.0)])
        // (0.2*1 + 0.8*3) / (1+3) = (0.2 + 2.4) / 4 = 0.65
        XCTAssertEqual(result, 0.65, accuracy: 0.0001)
    }
}
