import XCTest
@testable import RunFormCoachAI

// MARK: - CoreMotionPipelineTests
/// CoreMotion pipeline专项测试：精度、状态机、边界条件 (RF-802)
final class CoreMotionPipelineTests: XCTestCase {

    // MARK: - Helpers: Simulated signal generators

    /// Generate a sinusoid simulating accelerometer magnitude at a target SPM.
    /// - Parameters:
    ///   - spm: Target steps per minute (e.g. 180).
    ///   - sampleCount: Number of samples to generate.
    ///   - samplingRate: Hz (default 60).
    ///   - amplitude: Peak-to-peak variation around baseline (g, default 0.4).
    ///   - baseline: DC offset (g, default 1.0 = gravity).
    /// - Returns: Array of Double simulating accelerometer magnitude.
    private func generateCadenceSignal(
        spm: Double,
        sampleCount: Int,
        samplingRate: Double = 60,
        amplitude: Double = 0.4,
        baseline: Double = 1.0
    ) -> [Double] {
        let frequency = spm / 60.0  // Hz
        return (0..<sampleCount).map { i in
            let t = Double(i) / samplingRate
            return baseline + amplitude * sin(2.0 * .pi * frequency * t)
        }
    }

    /// Generate an array of SensorFrame simulating running or walking.
    /// - Parameters:
    ///   - spm: Cadence in steps per minute.
    ///   - sampleCount: Number of frames.
    ///   - verticalAmplitude: Peak vertical acceleration variation (g). Running ~0.5–0.8, walking ~0.3–0.5.
    ///   - leanDeg: Trunk lean angle in degrees (positive = forward).
    ///   - pitchAmplitude: Gyro pitch rate amplitude for GCT simulation.
    private func generateSensorFrames(
        spm: Double,
        sampleCount: Int,
        verticalAmplitude: Double = 0.6,
        leanDeg: Double = 5.0,
        pitchAmplitude: Double = 1.5
    ) -> [SensorFrame] {
        let frequency = spm / 60.0
        let leanRad = leanDeg * .pi / 180.0
        // accelY ≈ g*sin(lean), accelZ ≈ -g*cos(lean) + vertical oscillation
        let accelYBase = 9.81 * sin(leanRad)
        let accelZBase = -9.81 * cos(leanRad)

        return (0..<sampleCount).map { i in
            let t = Double(i) / 60.0
            let osc = verticalAmplitude * sin(2.0 * .pi * frequency * t)
            // Gyro pitch spikes at foot strike (zero-crossings of vertical accel)
            let gyroX = abs(sin(2.0 * .pi * frequency * t)) > 0.85
                ? pitchAmplitude * 0.8 : 0.0
            return SensorFrame(
                timestamp: Double(i) / 60.0,
                accelerationX: 0.0,
                accelerationY: accelYBase,
                accelerationZ: accelZBase + osc,
                rotationRateX: gyroX,
                rotationRateY: 0.0,
                rotationRateZ: 0.0
            )
        }
    }

    // MARK: - 1. CadenceDetector Precision Tests

    /// Inject 180 SPM 正弦波 → 验证输出在 180±5 SPM
    func testCadenceDetector_180SPM_WithinTolerance() {
        let detector = CadenceDetector(alpha: 0.8, minCadenceSPM: 50,
                                       maxCadenceSPM: 240, windowSeconds: 5)
        detector.samplingRate = 60

        let signal = generateCadenceSignal(spm: 180, sampleCount: 360, amplitude: 0.4)
        let expectation = XCTestExpectation(description: "Cadence 180 SPM detected")

        detector.onCadenceUpdate = { sample in
            if sample.confidence >= 0.3 {
                XCTAssertEqual(sample.stepsPerMinute, 180.0, accuracy: 5.0,
                               "180 SPM signal should produce cadence within ±5 SPM")
                expectation.fulfill()
            }
        }

        detector.processBatch(signal)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertNotNil(detector.currentCadence)
    }

    /// Inject 160 SPM → 验证输出在 160±5 SPM
    func testCadenceDetector_160SPM_WithinTolerance() {
        let detector = CadenceDetector(alpha: 0.8, minCadenceSPM: 50,
                                       maxCadenceSPM: 240, windowSeconds: 5)
        detector.samplingRate = 60

        let signal = generateCadenceSignal(spm: 160, sampleCount: 360, amplitude: 0.4)
        let expectation = XCTestExpectation(description: "Cadence 160 SPM detected")

        detector.onCadenceUpdate = { sample in
            if sample.confidence >= 0.3 {
                XCTAssertEqual(sample.stepsPerMinute, 160.0, accuracy: 5.0,
                               "160 SPM signal should produce cadence within ±5 SPM")
                expectation.fulfill()
            }
        }

        detector.processBatch(signal)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertNotNil(detector.currentCadence)
    }

    /// 边界：未输入数据 → cadence=nil
    func testCadenceDetector_NoInput_ReturnsNilCadence() {
        let detector = CadenceDetector()
        XCTAssertNil(detector.currentCadence, "Fresh detector should have nil cadence")
    }

    /// 边界：reset 后 → cadence=nil
    func testCadenceDetector_AfterReset_ReturnsNilCadence() {
        let detector = CadenceDetector()
        detector.samplingRate = 60

        // Feed some data first, then reset
        let signal = generateCadenceSignal(spm: 180, sampleCount: 60, amplitude: 0.3)
        detector.processBatch(signal)

        // reset() is sync so cadence should be nil immediately after
        detector.reset()
        XCTAssertNil(detector.currentCadence, "Cadence should be nil after reset")
    }

    /// 边界：零振幅输入 → cadence=nil 或 confidence 极低
    func testCadenceDetector_FlatSignal_NoValidCadence() {
        let detector = CadenceDetector(alpha: 0.8, minCadenceSPM: 50,
                                       maxCadenceSPM: 240, windowSeconds: 5)
        detector.samplingRate = 60

        // All zeros — no oscillation to detect
        let flatSignal = Array(repeating: 1.0, count: 300)
        let expectation = XCTestExpectation(description: "No cadence from flat signal")
        expectation.isInverted = true  // We expect NO update

        detector.onCadenceUpdate = { _ in
            expectation.fulfill()
        }

        detector.processBatch(flatSignal)

        wait(for: [expectation], timeout: 2.0)
        // After flat input, currentCadence may still be nil
        // (or may have extremely low confidence from fallback)
        if let cadence = detector.currentCadence {
            XCTAssertLessThanOrEqual(cadence.confidence, 0.2,
                                     "Flat signal should yield very low confidence")
        }
    }

    // MARK: - 2. GaitAnalyzer Tests

    /// 注入模拟行走数据 → 验证垂直振幅在 6–10cm 范围
    func testGaitAnalyzer_Walking_VerticalOscillationInRange() {
        let analyzer = GaitAnalyzer(windowSeconds: 5.0, samplingRate: 60)
        let frames = generateSensorFrames(spm: 120, sampleCount: 360,
                                          verticalAmplitude: 0.4, pitchAmplitude: 0.8)

        let expectation = XCTestExpectation(description: "Walking gait snapshot received")

        analyzer.onGaitUpdate = { snapshot in
            XCTAssertGreaterThanOrEqual(snapshot.verticalOscillationCm, 6.0,
                                        "Walking vertical oscillation should be >= 6 cm")
            XCTAssertLessThanOrEqual(snapshot.verticalOscillationCm, 10.0,
                                     "Walking vertical oscillation should be <= 10 cm")
            expectation.fulfill()
        }

        analyzer.processBatch(frames)

        wait(for: [expectation], timeout: 3.0)
    }

    /// 注入模拟跑步数据 → 验证垂直振幅在 8–15cm 范围
    func testGaitAnalyzer_Running_VerticalOscillationInRange() {
        let analyzer = GaitAnalyzer(windowSeconds: 5.0, samplingRate: 60)
        let frames = generateSensorFrames(spm: 170, sampleCount: 360,
                                          verticalAmplitude: 0.7, pitchAmplitude: 1.8)

        let expectation = XCTestExpectation(description: "Running gait snapshot received")

        analyzer.onGaitUpdate = { snapshot in
            XCTAssertGreaterThanOrEqual(snapshot.verticalOscillationCm, 8.0,
                                        "Running vertical oscillation should be >= 8 cm")
            XCTAssertLessThanOrEqual(snapshot.verticalOscillationCm, 15.0,
                                     "Running vertical oscillation should be <= 15 cm")
            expectation.fulfill()
        }

        analyzer.processBatch(frames)

        wait(for: [expectation], timeout: 3.0)
    }

    /// 边界：无数据输入 → currentSnapshot=nil
    func testGaitAnalyzer_NoInput_ReturnsNilSnapshot() {
        let analyzer = GaitAnalyzer()
        XCTAssertNil(analyzer.currentSnapshot, "Fresh analyzer should have nil snapshot")
    }

    /// 边界：reset 后 → currentSnapshot=nil
    func testGaitAnalyzer_AfterReset_ReturnsNilSnapshot() {
        let analyzer = GaitAnalyzer(windowSeconds: 5.0, samplingRate: 60)
        let frames = generateSensorFrames(spm: 150, sampleCount: 120,
                                          verticalAmplitude: 0.5)

        analyzer.processBatch(frames)
        analyzer.reset()

        XCTAssertNil(analyzer.currentSnapshot, "Snapshot should be nil after reset")
    }

    // MARK: - 3. CoreMotionManager Permission Test

    /// 验证 NSMotionUsageDescription 在 Info.plist 中
    func testInfoPlist_ContainsMotionUsageDescription() {
        guard let plistPath = Bundle(for: type(of: self))
            .path(forResource: "Info", ofType: "plist") else {
            // Fallback: read the project-level Info.plist
            let projectPlistPath = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("RunFormCoachAI/Info.plist")
                .path

            guard FileManager.default.fileExists(atPath: projectPlistPath) else {
                // On WSL/CI: plist may not be accessible; skip gracefully
                return
            }

            guard let plist = NSDictionary(contentsOfFile: projectPlistPath) else {
                XCTFail("Cannot read Info.plist")
                return
            }

            XCTAssertNotNil(plist["NSMotionUsageDescription"],
                            "Info.plist must contain NSMotionUsageDescription key")
            if let desc = plist["NSMotionUsageDescription"] as? String {
                XCTAssertFalse(desc.isEmpty,
                               "NSMotionUsageDescription must not be empty")
            }
            return
        }

        let plist = NSDictionary(contentsOfFile: plistPath)
        XCTAssertNotNil(plist?["NSMotionUsageDescription"],
                        "Bundle Info.plist must contain NSMotionUsageDescription key")
    }

    // MARK: - 4. AudioCoachEngine Tests

    /// 低步频 → 触发 "increase cadence" 提示
    func testAudioCoach_LowCadence_TriggersIncreasePrompt() {
        let coach = AudioCoachEngine(language: "en", minInterval: 1)
        let expectation = XCTestExpectation(description: "Low cadence prompt")

        coach.onPromptQueued = { prompt in
            XCTAssertEqual(prompt.category, .cadence)
            XCTAssertTrue(prompt.text.lowercased().contains("shorten"),
                          "Low cadence should trigger increase/shorten stride prompt")
            expectation.fulfill()
        }

        let lowCadence = CadenceSample(stepsPerMinute: 140, confidence: 0.8)
        // Target cadence: 170, delta = -30 (< -15 triggers low cadence)
        coach.evaluate(cadence: lowCadence, gait: nil,
                       targetCadence: 170, elapsedSeconds: 15)

        wait(for: [expectation], timeout: 2.0)
    }

    /// 正常步频 → 不触发提示
    func testAudioCoach_NormalCadence_NoPrompt() {
        let coach = AudioCoachEngine(language: "en", minInterval: 1)
        let expectation = XCTestExpectation(description: "No prompt for normal cadence")
        expectation.isInverted = true

        coach.onPromptQueued = { _ in
            expectation.fulfill()
        }

        let normalCadence = CadenceSample(stepsPerMinute: 170, confidence: 0.8)
        coach.evaluate(cadence: normalCadence, gait: nil,
                       targetCadence: 170, elapsedSeconds: 15)

        wait(for: [expectation], timeout: 2.0)
    }

    /// 最小间隔 15s → 连续触发被抑制
    func testAudioCoach_MinInterval_SuppressesRapidPrompts() {
        let coach = AudioCoachEngine(language: "en", minInterval: 15)
        var promptCount = 0

        coach.onPromptQueued = { _ in
            promptCount += 1
        }

        let lowCadence = CadenceSample(stepsPerMinute: 140, confidence: 0.8)

        // First call: should trigger
        let firstExpectation = XCTestExpectation(description: "First prompt")
        coach.onPromptQueued = { _ in
            promptCount += 1
            if promptCount == 1 { firstExpectation.fulfill() }
        }
        coach.evaluate(cadence: lowCadence, gait: nil,
                       targetCadence: 170, elapsedSeconds: 15)
        wait(for: [firstExpectation], timeout: 2.0)

        // Second call immediately: should NOT trigger (minInterval=15s)
        let suppressedExpectation = XCTestExpectation(description: "Suppressed prompt")
        suppressedExpectation.isInverted = true
        coach.onPromptQueued = { _ in
            if promptCount > 1 { suppressedExpectation.fulfill() }
        }
        coach.evaluate(cadence: lowCadence, gait: nil,
                       targetCadence: 170, elapsedSeconds: 16)
        wait(for: [suppressedExpectation], timeout: 2.0)

        XCTAssertEqual(promptCount, 1, "Only the first prompt should fire within 15s interval")
    }

    /// 高步频 → 触发 "decrease cadence" 提示
    func testAudioCoach_HighCadence_TriggersDecreasePrompt() {
        let coach = AudioCoachEngine(language: "en", minInterval: 1)
        let expectation = XCTestExpectation(description: "High cadence prompt")

        coach.onPromptQueued = { prompt in
            XCTAssertEqual(prompt.category, .cadence)
            XCTAssertTrue(prompt.text.lowercased().contains("lengthen"),
                          "High cadence should trigger lengthen stride prompt")
            expectation.fulfill()
        }

        let highCadence = CadenceSample(stepsPerMinute: 200, confidence: 0.8)
        coach.evaluate(cadence: highCadence, gait: nil,
                       targetCadence: 170, elapsedSeconds: 15)

        wait(for: [expectation], timeout: 2.0)
    }

    /// 前 10 秒静默期 → 不触发提示
    func testAudioCoach_EarlySession_SilentPeriod() {
        let coach = AudioCoachEngine(language: "en", minInterval: 1)
        let expectation = XCTestExpectation(description: "No prompt in first 10s")
        expectation.isInverted = true

        coach.onPromptQueued = { _ in
            expectation.fulfill()
        }

        let lowCadence = CadenceSample(stepsPerMinute: 140, confidence: 0.8)
        coach.evaluate(cadence: lowCadence, gait: nil,
                       targetCadence: 170, elapsedSeconds: 3)

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - 5. RunSessionManager State Machine Tests

    /// idle→ready→running→paused→stopped→idle 全路径
    func testRunSessionManager_FullLifecycle() {
        let config = RunSessionConfig(targetCadenceSPM: 170)
        let session = RunSessionManager(config: config)

        // Phase-driven expectations for each state transition
        let readyExpectation = XCTestExpectation(description: "idle → ready")
        let runningExpectation = XCTestExpectation(description: "ready → running")
        let pausedExpectation = XCTestExpectation(description: "running → paused")
        let resumedExpectation = XCTestExpectation(description: "paused → running")
        let stoppedExpectation = XCTestExpectation(description: "running → stopped")
        let idleExpectation = XCTestExpectation(description: "stopped → idle")

        var phase = 0  // 0=start, 1=pause, 2=resume, 3=stop

        session.onStateChange = { _, new in
            switch (phase, new) {
            case (0, .ready):   readyExpectation.fulfill()
            case (0, .running): runningExpectation.fulfill()
            case (1, .paused):  pausedExpectation.fulfill()
            case (2, .running): resumedExpectation.fulfill()
            case (3, .stopped): stoppedExpectation.fulfill()
            case (3, .idle):    idleExpectation.fulfill()
            default: break
            }
        }

        // Phase 0: start
        session.start()
        wait(for: [readyExpectation, runningExpectation], timeout: 3.0, enforceOrder: true)
        XCTAssertEqual(session.state, .running)

        // Phase 1: pause
        phase = 1
        session.pause()
        wait(for: [pausedExpectation], timeout: 2.0)
        XCTAssertEqual(session.state, .paused)

        // Phase 2: resume
        phase = 2
        session.resume()
        wait(for: [resumedExpectation], timeout: 2.0)
        XCTAssertEqual(session.state, .running)

        // Phase 3: stop
        phase = 3
        session.stop()
        wait(for: [stoppedExpectation, idleExpectation], timeout: 3.0, enforceOrder: true)
        XCTAssertEqual(session.state, .idle)
    }

    /// running→stop 直接停止 (不经过 pause)
    func testRunSessionManager_RunningToStop_DirectPath() {
        let config = RunSessionConfig(targetCadenceSPM: 170)
        let session = RunSessionManager(config: config)

        var phase = 0

        let runningExpectation = XCTestExpectation(description: "ready → running")
        let stoppedExpectation = XCTestExpectation(description: "running → stopped")
        let idleExpectation = XCTestExpectation(description: "stopped → idle")

        session.onStateChange = { _, new in
            switch (phase, new) {
            case (0, .running): runningExpectation.fulfill()
            case (1, .stopped): stoppedExpectation.fulfill()
            case (1, .idle):    idleExpectation.fulfill()
            default: break
            }
        }

        // Start
        session.start()
        wait(for: [runningExpectation], timeout: 3.0)
        XCTAssertEqual(session.state, .running)

        // Stop directly from running
        phase = 1
        session.stop()
        wait(for: [stoppedExpectation, idleExpectation], timeout: 3.0)
        XCTAssertEqual(session.state, .idle)
    }

    /// 初始状态为 idle
    func testRunSessionManager_InitialStateIsIdle() {
        let config = RunSessionConfig()
        let session = RunSessionManager(config: config)
        XCTAssertEqual(session.state, .idle, "Initial state must be idle")
    }

    /// pause 只在 running 状态有效
    func testRunSessionManager_PauseFromIdle_NoOp() {
        let config = RunSessionConfig()
        let session = RunSessionManager(config: config)
        // Attempt pause from idle — should stay idle
        session.pause()
        // pause runs on queue, so check after a brief wait
        let expectation = XCTestExpectation(description: "Pause from idle no-op")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(session.state, .idle,
                           "Pause from idle should remain idle")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// resume 只在 paused 状态有效
    func testRunSessionManager_ResumeFromIdle_NoOp() {
        let config = RunSessionConfig()
        let session = RunSessionManager(config: config)
        session.resume()
        let expectation = XCTestExpectation(description: "Resume from idle no-op")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(session.state, .idle,
                           "Resume from idle should remain idle")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    /// stop 转化到 idle 后可以重新 start
    func testRunSessionManager_StopThenRestart() {
        let config = RunSessionConfig(targetCadenceSPM: 170)
        let session = RunSessionManager(config: config)

        var phase = 0
        let firstRunningExpectation = XCTestExpectation(description: "First run")
        let stopToIdleExpectation = XCTestExpectation(description: "Stop → idle")
        let secondRunningExpectation = XCTestExpectation(description: "Second run")

        session.onStateChange = { _, new in
            switch (phase, new) {
            case (0, .running): firstRunningExpectation.fulfill()
            case (1, .idle):    stopToIdleExpectation.fulfill()
            case (2, .running): secondRunningExpectation.fulfill()
            default: break
            }
        }

        // First run
        session.start()
        wait(for: [firstRunningExpectation], timeout: 3.0)

        // Stop
        phase = 1
        session.stop()
        wait(for: [stopToIdleExpectation], timeout: 3.0)
        XCTAssertEqual(session.state, .idle)

        // Second run from idle
        phase = 2
        session.start()
        wait(for: [secondRunningExpectation], timeout: 3.0)
        XCTAssertEqual(session.state, .running,
                       "Should be able to restart after stop")
    }
}
