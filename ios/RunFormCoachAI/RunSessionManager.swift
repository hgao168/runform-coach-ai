import Foundation
import os.log

// MARK: - RunSessionManager

/// Orchestrates the real-time running coach pipeline:
/// `CoreMotionManager → CadenceDetector → GaitAnalyzer → AudioCoachEngine`
///
/// Manages session lifecycle with a state machine:
/// `idle → ready → running → paused → stopped`
///
/// Provides aggregated real-time data callbacks for UI updates.
///
/// Usage:
/// ```swift
/// let session = RunSessionManager(config: RunSessionConfig())
/// session.onMetricsUpdate = { cadence, gait in
///     // update UI
/// }
/// session.start()
/// // ... run ...
/// session.pause()
/// session.resume()
/// session.stop()
/// ```
public final class RunSessionManager: @unchecked Sendable {

    // MARK: - Public types

    /// Aggregated session metrics delivered to UI callbacks.
    public struct SessionMetrics: Sendable {
        public let cadence: CadenceSample?
        public let gait: GaitSnapshot?
        public let elapsedSeconds: TimeInterval
        public let state: RunSessionState
        public let promptHistory: [CoachPrompt]

        public init(
            cadence: CadenceSample? = nil,
            gait: GaitSnapshot? = nil,
            elapsedSeconds: TimeInterval = 0,
            state: RunSessionState = .idle,
            promptHistory: [CoachPrompt] = []
        ) {
            self.cadence = cadence
            self.gait = gait
            self.elapsedSeconds = elapsedSeconds
            self.state = state
            self.promptHistory = promptHistory
        }
    }

    // MARK: - Public properties

    /// Current session state.
    public private(set) var state: RunSessionState = .idle

    /// Session configuration.
    public let config: RunSessionConfig

    /// Elapsed session time in seconds.
    public private(set) var elapsedSeconds: TimeInterval = 0

    /// History of coaching prompts delivered this session.
    public private(set) var promptHistory: [CoachPrompt] = []

    /// Callback invoked on each metrics update (~1 Hz).
    public var onMetricsUpdate: (@Sendable (SessionMetrics) -> Void)?

    /// Callback invoked on state transitions.
    public var onStateChange: (@Sendable (RunSessionState, RunSessionState) -> Void)?

    /// Callback invoked when a coach prompt is spoken (for UI overlay).
    public var onCoachPrompt: (@Sendable (CoachPrompt) -> Void)?

    // MARK: - Pipeline components

    public let motionManager: CoreMotionManager
    public let cadenceDetector: CadenceDetector
    public let gaitAnalyzer: GaitAnalyzer
    public let audioCoach: AudioCoachEngine

    // MARK: - Private

    private let queue = DispatchQueue(label: "com.runformcoachai.session")
    private var sessionStartDate: Date?
    private var pauseStartDate: Date?
    private var totalPausedSeconds: TimeInterval = 0
    private var metricsTimer: DispatchSourceTimer?

    // MARK: - Init

    /// - Parameters:
    ///   - config: Session configuration (cadence target, language, intervals, etc.).
    ///   - motionManager: Optional pre-configured CoreMotionManager. Created if nil.
    ///   - cadenceDetector: Optional pre-configured CadenceDetector. Created if nil.
    ///   - gaitAnalyzer: Optional pre-configured GaitAnalyzer. Created if nil.
    ///   - audioCoach: Optional pre-configured AudioCoachEngine. Created if nil.
    public init(
        config: RunSessionConfig = RunSessionConfig(),
        motionManager: CoreMotionManager? = nil,
        cadenceDetector: CadenceDetector? = nil,
        gaitAnalyzer: GaitAnalyzer? = nil,
        audioCoach: AudioCoachEngine? = nil
    ) {
        self.config = config

        self.motionManager = motionManager ?? CoreMotionManager(
            samplingRate: config.samplingRate,
            windowSeconds: config.sensorWindowSeconds
        )

        self.cadenceDetector = cadenceDetector ?? CadenceDetector(
            alpha: 0.8,
            windowSeconds: config.sensorWindowSeconds
        )
        // Sync samplingRate for accurate timestamp estimation
        self.cadenceDetector.samplingRate = self.motionManager.samplingRate

        self.gaitAnalyzer = gaitAnalyzer ?? GaitAnalyzer(
            windowSeconds: config.sensorWindowSeconds,
            samplingRate: config.samplingRate
        )

        self.audioCoach = audioCoach ?? AudioCoachEngine(
            language: config.coachingLanguage,
            minInterval: config.minPromptInterval
        )

        setupPipeline()
    }

    // MARK: - Public API: State machine

    /// Transition from idle → ready → running.
    public func start() {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.state == .idle || self.state == .ready else {
                os_log(.info, "RunSessionManager: cannot start from state %{public}@",
                       self.state.rawValue)
                return
            }
            self.transition(to: .ready)
            self.transition(to: .running)
            self.sessionStartDate = Date()
            self.totalPausedSeconds = 0
            self.elapsedSeconds = 0
            self.promptHistory.removeAll()
            self.motionManager.startUpdates()
            self.startMetricsTimer()
        }
    }

    /// Pause the session (sensors keep running but metrics and coaching pause).
    public func pause() {
        queue.async { [weak self] in
            guard let self, self.state == .running else { return }
            self.pauseStartDate = Date()
            self.transition(to: .paused)
        }
    }

    /// Resume from paused state.
    public func resume() {
        queue.async { [weak self] in
            guard let self, self.state == .paused else { return }
            if let pauseStart = self.pauseStartDate {
                self.totalPausedSeconds += Date().timeIntervalSince(pauseStart)
                self.pauseStartDate = nil
            }
            self.transition(to: .running)
        }
    }

    /// Stop the session completely.
    public func stop() {
        queue.async { [weak self] in
            guard let self, self.state != .idle, self.state != .stopped else { return }
            // Accumulate any active pause before stopping
            if let pauseStart = self.pauseStartDate {
                self.totalPausedSeconds += Date().timeIntervalSince(pauseStart)
                self.pauseStartDate = nil
            }
            self.motionManager.stopUpdates()
            self.stopMetricsTimer()
            self.cadenceDetector.reset()
            self.gaitAnalyzer.reset()
            self.audioCoach.stopSpeaking()
            self.transition(to: .stopped)
            self.transition(to: .idle)
        }
    }

    // MARK: - Pipeline setup

    private func setupPipeline() {
        // Wire: CoreMotion → CadenceDetector + GaitAnalyzer

        motionManager.onFrame = { [weak self] frame in
            guard let self else { return }
            // Feed cadence detector: use vertical acceleration magnitude
            let accelMag = sqrt(
                frame.accelerationX * frame.accelerationX +
                frame.accelerationY * frame.accelerationY +
                frame.accelerationZ * frame.accelerationZ
            )
            self.cadenceDetector.process(value: accelMag)

            // Feed gait analyzer with full frame
            self.gaitAnalyzer.process(frame: frame)
        }

        // Wire: CadenceDetector → AudioCoach evaluation
        cadenceDetector.onCadenceUpdate = { [weak self] cadence in
            guard let self else { return }
            // Inject latest cadence into gait analyzer for snapshot enrichment
            self.gaitAnalyzer.latestCadenceSPM = cadence.currentSPM
            let gait = self.gaitAnalyzer.currentSnapshot
            let elapsed = self.elapsedSeconds
            self.audioCoach.evaluate(
                cadence: cadence,
                gait: gait,
                targetCadence: self.config.targetCadenceSPM,
                elapsedSeconds: elapsed
            )
        }

        // Wire: AudioCoach prompts → UI callback
        audioCoach.onPromptQueued = { [weak self] prompt in
            guard let self else { return }
            self.promptHistory.append(prompt)
            // Keep last 50 prompts max
            if self.promptHistory.count > 50 {
                self.promptHistory.removeFirst(self.promptHistory.count - 50)
            }
            self.onCoachPrompt?(prompt)
        }
    }

    // MARK: - Metrics timer

    /// Fires at ~1 Hz to deliver aggregated session metrics to the UI.
    private func startMetricsTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self, self.state == .running else { return }
            if let start = self.sessionStartDate {
                self.elapsedSeconds = Date().timeIntervalSince(start) - self.totalPausedSeconds
            }
            let metrics = SessionMetrics(
                cadence: self.cadenceDetector.currentCadence,
                gait: self.gaitAnalyzer.currentSnapshot,
                elapsedSeconds: self.elapsedSeconds,
                state: self.state,
                promptHistory: self.promptHistory
            )
            self.onMetricsUpdate?(metrics)
        }
        timer.resume()
        metricsTimer = timer
    }

    private func stopMetricsTimer() {
        metricsTimer?.cancel()
        metricsTimer = nil
    }

    // MARK: - State transitions

    private func transition(to newState: RunSessionState) {
        let oldState = state
        guard oldState != newState else { return }
        state = newState
        os_log(.info, "RunSessionManager: %{public}@ → %{public}@",
               oldState.rawValue, newState.rawValue)
        onStateChange?(oldState, newState)
    }
}
