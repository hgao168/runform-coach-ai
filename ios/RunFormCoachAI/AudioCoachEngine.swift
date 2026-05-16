import AVFoundation
import Foundation
import os.log

// MARK: - AudioCoachEngine

/// Real-time voice coach that speaks form cues via iOS `AVSpeechSynthesizer`.
///
/// Triggered by metric thresholds (cadence too low/high, excessive vertical oscillation,
/// poor trunk lean, long ground contact time). Enforces minimum prompt interval to avoid
/// nagging. Supports English, Chinese (Simplified), and Dutch.
///
/// Usage:
/// ```swift
/// let coach = AudioCoachEngine(language: "en", minInterval: 15)
/// coach.evaluate(cadence: 155, gait: snapshot)
/// ```
public final class AudioCoachEngine: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {

    // MARK: - Public properties

    /// The language code currently in use.
    public private(set) var language: String

    /// Minimum seconds between voice prompts.
    public let minInterval: TimeInterval

    /// Whether the coach is currently speaking.
    public private(set) var isSpeaking: Bool = false

    /// Whether the coach is muted (no speech output).
    public var isMuted: Bool = false

    /// Callback invoked when a prompt is queued (for UI display).
    public var onPromptQueued: (@Sendable (CoachPrompt) -> Void)?

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private let queue = DispatchQueue(label: "com.runformcoachai.audio")
    private var lastPromptTime: Date?
    private var cadenceHistory: [Double] = []
    private var promptCount: Int = 0

    // MARK: - Init

    /// - Parameters:
    ///   - language: Language code ("en", "zh-Hans", "nl"). Default "en".
    ///   - minInterval: Minimum seconds between prompts (default 15, clamped 5–60).
    public init(language: String = "en", minInterval: TimeInterval = 15) {
        self.language = language
        self.minInterval = max(5, min(60, minInterval))
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    /// Evaluate current metrics and decide whether to speak a coaching prompt.
    ///
    /// - Parameters:
    ///   - cadence: Current steps per minute.
    ///   - gait: Latest gait analysis snapshot.
    ///   - targetCadence: Target cadence for this session (default 170).
    ///   - elapsedSeconds: Total seconds elapsed in the session.
    public func evaluate(
        cadence: CadenceSample?,
        gait: GaitSnapshot?,
        targetCadence: Double = 170,
        elapsedSeconds: TimeInterval = 0
    ) {
        queue.async { [weak self] in
            self?.evaluateSync(cadence: cadence, gait: gait,
                               targetCadence: targetCadence,
                               elapsedSeconds: elapsedSeconds)
        }
    }

    /// Speak a custom prompt immediately (respects mute, not interval).
    /// - Parameter prompt: The prompt to speak.
    public func speak(prompt: CoachPrompt) {
        guard !isMuted else { return }
        queue.async { [weak self] in
            self?.speakSync(prompt)
        }
    }

    /// Stop any in-progress speech.
    public func stopSpeaking() {
        queue.async { [weak self] in
            self?.synthesizer.stopSpeaking(at: .immediate)
            self?.isSpeaking = false
        }
    }

    /// Change the coaching language.
    /// - Parameter language: New language code ("en", "zh-Hans", "nl").
    public func setLanguage(_ language: String) {
        queue.async { [weak self] in
            self?.language = language
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                   didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                   didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                   didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    // MARK: - Private evaluation

    private func evaluateSync(
        cadence: CadenceSample?,
        gait: GaitSnapshot?,
        targetCadence: Double,
        elapsedSeconds: TimeInterval
    ) {
        // Enforce interval
        if let last = lastPromptTime {
            guard Date().timeIntervalSince(last) >= minInterval else { return }
        }

        // Skip early session (first 10s: let metrics stabilise)
        guard elapsedSeconds >= 10 else { return }

        var prompts: [CoachPrompt] = []

        // --- Cadence coaching ---
        if let cad = cadence, cad.confidence >= 0.3 {
            cadenceHistory.append(cad.stepsPerMinute)
            while cadenceHistory.count > 30 { cadenceHistory.removeFirst() }

            // Use rolling average to avoid single-sample noise
            let avgCadence = cadenceHistory.reduce(0, +) / Double(cadenceHistory.count)
            let delta = avgCadence - targetCadence

            if delta < -15 && cadenceHistory.count >= 5 {
                // Cadence too low
                prompts.append(makeCadencePrompt(delta: delta, direction: "low"))
            } else if delta > 15 && cadenceHistory.count >= 5 {
                // Cadence too high
                prompts.append(makeCadencePrompt(delta: delta, direction: "high"))
            }
        }

        // --- Gait coaching ---
        if let gait = gait {
            // Vertical oscillation
            if gait.verticalOscillationCm > 10.0 {
                prompts.append(makeGaitPrompt(.verticalOscillation,
                                              value: gait.verticalOscillationCm,
                                              unit: "cm",
                                              threshold: 10.0))
            }

            // Ground contact time
            if gait.groundContactTimeMs > 300 {
                prompts.append(makeGaitPrompt(.groundContactTime,
                                              value: gait.groundContactTimeMs,
                                              unit: "ms",
                                              threshold: 300))
            }

            // Trunk lean
            if abs(gait.trunkLeanDegrees) > 12 {
                prompts.append(makeGaitPrompt(.trunkLean,
                                              value: gait.trunkLeanDegrees,
                                              unit: "degrees",
                                              threshold: 12))
            }
        }

        // --- Speak highest-priority prompt only ---
        if let prompt = prompts.max(by: { $0.priority < $1.priority }) {
            speakSync(prompt)
        }
    }

    private func speakSync(_ prompt: CoachPrompt) {
        lastPromptTime = Date()
        promptCount += 1
        onPromptQueued?(prompt)

        guard !isMuted else { return }

        let utterance = AVSpeechUtterance(string: prompt.text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceCode(for: prompt.language))
        utterance.rate = 0.52  // slightly slower for clarity during exercise
        utterance.pitchMultiplier = 0.95
        utterance.volume = 0.9

        synthesizer.stopSpeaking(at: .word)
        synthesizer.speak(utterance)
    }

    // MARK: - Prompt factories

    private func makeCadencePrompt(delta: Double, direction: String) -> CoachPrompt {
        let absDelta = Int(abs(delta))
        let priority: Int = absDelta > 25 ? 2 : 1

        let text: String
        switch language {
        case "zh-Hans":
            if direction == "low" {
                text = "步频偏低，加快节奏，小步快跑。"
            } else {
                text = "步频偏快，放慢节奏，加大步幅。"
            }
        case "nl":
            if direction == "low" {
                text = "Cadans te laag. Verhoog je pasfrequentie met kortere passen."
            } else {
                text = "Cadans te hoog. Verlaag je tempo en verleng je passen."
            }
        default: // en
            if direction == "low" {
                text = "Cadence is \(absDelta) steps low. Shorten your stride and pick up the tempo."
            } else {
                text = "Cadence is \(absDelta) steps high. Lengthen your stride and settle into a rhythm."
            }
        }

        return CoachPrompt(text: text, language: language,
                           priority: priority, category: .cadence)
    }

    private func makeGaitPrompt(_ category: CoachPrompt.CoachCategory,
                                 value: Double, unit: String,
                                 threshold: Double) -> CoachPrompt {
        let text: String
        switch (language, category) {
        case ("zh-Hans", .verticalOscillation):
            text = "垂直振幅偏高，收紧核心，减少上下跳动。"
        case ("zh-Hans", .groundContactTime):
            text = "触地时间偏长，加快脚步转换，提高步频。"
        case ("zh-Hans", .trunkLean):
            text = value > 0
                ? "身体前倾过多，稍微挺直上身。"
                : "身体后仰，稍微前倾利用重力。"
        case ("nl", .verticalOscillation):
            text = "Te veel verticale beweging. Span je core aan en loop efficiënter."
        case ("nl", .groundContactTime):
            text = "Grondcontact te lang. Verhoog je pasfrequentie voor een lichtere landing."
        case ("nl", .trunkLean):
            text = value > 0
                ? "Je leunt te ver voorover. Richt je bovenlichaam iets op."
                : "Je leunt achterover. Helling iets naar voren voor betere voortstuwing."
        default: // en
            switch category {
            case .verticalOscillation:
                text = "Reduce bounce. Engage your core and land softly."
            case .groundContactTime:
                text = "Ground contact too long. Quick, light steps."
            case .trunkLean:
                text = value > 0
                    ? "Leaning too far forward. Straighten up slightly."
                    : "Leaning back. Tilt forward slightly from the ankles."
            default:
                text = "Adjust your form."
            }
        }

        return CoachPrompt(text: text, language: language,
                           priority: 1, category: category)
    }

    /// Map our language codes to BCP-47 codes AVSpeechSynthesizer expects.
    private func voiceCode(for language: String) -> String {
        switch language {
        case "zh-Hans": return "zh-CN"
        case "nl":      return "nl-NL"
        default:        return "en-US"
        }
    }
}
