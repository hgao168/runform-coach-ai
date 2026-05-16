package com.runformcoach.runformcoachai.sensor

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.Locale

// ── CoachPrompt ──────────────────────────────────────────────────────────────

/** 教练提示类别。 */
enum class CoachCategory {
    cadence,
    verticalOscillation,
    groundContactTime,
    trunkLean,
    general
}

/**
 * 由 [AudioCoachEngine] 生成的教练语音提示。
 *
 * @property text      要朗读的文本
 * @property language  语言代码 ("en", "zh", "nl")
 * @property priority  优先级 (0=信息, 1=建议, 2=警告)
 * @property category  触发该提示的指标类别
 */
data class CoachPrompt(
    val text: String,
    val language: String = "en",
    val priority: Int = 0,
    val category: CoachCategory = CoachCategory.general
)

// ── AudioCoachEngine ─────────────────────────────────────────────────────────

/**
 * 实时语音教练 —— 通过 Android [TextToSpeech] 播报跑姿提示。
 *
 * 由指标阈值触发 (步频太低/太高、垂直振幅过大、躯干倾角不当、触地时间过长)。
 * 强制最小提示间隔 (默认 15s) 避免频繁打扰。
 * 支持英文、简体中文、荷兰语。
 *
 * 用法:
 * ```
 * val coach = AudioCoachEngine(context, language = "en", minInterval = 15)
 * coach.evaluate(cadence = sample, gait = snapshot)
 * ```
 */
class AudioCoachEngine(
    private val context: Context,
    /** 语言代码 ("en", "zh", "nl")。默认 "en"。 */
    language: String = "en",
    /** 两次语音提示之间的最小秒数 (限制 5–60)。 */
    val minIntervalSeconds: Int = 15
) {
    companion object {
        private const val TAG = "AudioCoachEngine"
        private const val CADENCE_HISTORY_MAX = 30
        private const val EARLY_SESSION_SKIP_SEC = 10.0
    }

    // ── 公开属性 ──────────────────────────────────────────────────────────────

    /** 当前语言代码。 */
    var language: String = language
        private set

    /** 最小提示间隔 (秒)。 */
    val minInterval: Int = maxOf(5, minOf(60, minIntervalSeconds))

    /** 当前是否正在播报。 */
    var isSpeaking: Boolean = false
        private set

    /** 是否静音 (不输出语音)。 */
    var isMuted: Boolean = false

    /** 提示排队时的回调 (供 UI 显示)。 */
    var onPromptQueued: ((CoachPrompt) -> Unit)? = null

    // ── 内部状态 ──────────────────────────────────────────────────────────────

    private var tts: TextToSpeech? = null
    private var ttsInitialized: Boolean = false
    private var lastPromptTimeMillis: Long = 0L
    private val cadenceHistory = ArrayDeque<Double>()
    private var promptCount: Int = 0

    // ── 初始化 ────────────────────────────────────────────────────────────────

    init {
        initTTS()
    }

    private fun initTTS() {
        tts = TextToSpeech(context) { status ->
            ttsInitialized = (status == TextToSpeech.SUCCESS)
            if (ttsInitialized) {
                tts?.language = resolveLocale(language)
                Log.i(TAG, "TTS 初始化成功, 语言: ${tts?.language}")
            } else {
                Log.e(TAG, "TTS 初始化失败, status=$status")
            }
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                isSpeaking = true
            }
            override fun onDone(utteranceId: String?) {
                isSpeaking = false
            }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                isSpeaking = false
                Log.w(TAG, "TTS 播报错误, utteranceId=$utteranceId")
            }
        })
    }

    // ── 公开 API ──────────────────────────────────────────────────────────────

    /**
     * 根据当前指标评估是否需要播报教练提示。
     *
     * @param cadence         当前步频样本 (可为 null)
     * @param gait            最新步态快照 (可为 null)
     * @param targetCadence   本次训练目标步频 (默认 170)
     * @param elapsedSeconds  已用时 (秒)
     */
    fun evaluate(
        cadence: CadenceSample?,
        gait: GaitSnapshot?,
        targetCadence: Double = 170.0,
        elapsedSeconds: Double = 0.0
    ) {
        // 强制间隔
        val now = System.currentTimeMillis()
        val intervalMs = minInterval * 1000L
        if (now - lastPromptTimeMillis < intervalMs) return

        // 跳过训练前 10 秒 (让指标稳定)
        if (elapsedSeconds < EARLY_SESSION_SKIP_SEC) return

        val prompts = mutableListOf<CoachPrompt>()

        // ── 步频教练 ────────────────────────────────────────────────────────

        if (cadence != null && cadence.confidence >= 0.3) {
            cadenceHistory.addLast(cadence.stepsPerMinute)
            while (cadenceHistory.size > CADENCE_HISTORY_MAX) {
                cadenceHistory.removeFirst()
            }

            val avgCadence = cadenceHistory.sum() / cadenceHistory.size
            val delta = avgCadence - targetCadence

            if (delta < -15 && cadenceHistory.size >= 5) {
                prompts.add(makeCadencePrompt(delta = delta, direction = "low"))
            } else if (delta > 15 && cadenceHistory.size >= 5) {
                prompts.add(makeCadencePrompt(delta = delta, direction = "high"))
            }
        }

        // ── 步态教练 ────────────────────────────────────────────────────────

        if (gait != null) {
            // 垂直振幅
            if (gait.verticalOscillationCm > 10.0) {
                prompts.add(makeGaitPrompt(
                    CoachCategory.verticalOscillation,
                    value = gait.verticalOscillationCm,
                    unit = "cm",
                    threshold = 10.0
                ))
            }

            // 触地时间
            if (gait.groundContactTimeMs > 300) {
                prompts.add(makeGaitPrompt(
                    CoachCategory.groundContactTime,
                    value = gait.groundContactTimeMs,
                    unit = "ms",
                    threshold = 300.0
                ))
            }

            // 躯干倾角
            if (kotlin.math.abs(gait.trunkLeanDegrees) > 12) {
                prompts.add(makeGaitPrompt(
                    CoachCategory.trunkLean,
                    value = gait.trunkLeanDegrees,
                    unit = "degrees",
                    threshold = 12.0
                ))
            }
        }

        // ── 取最高优先级播报 ────────────────────────────────────────────────

        if (prompts.isNotEmpty()) {
            val bestPrompt = prompts.maxByOrNull { it.priority } ?: return
            speakSync(bestPrompt)
        }
    }

    /**
     * 立即播报一条自定义提示 (不受间隔限制，但遵循静音)。
     */
    fun speak(prompt: CoachPrompt) {
        if (isMuted) return
        speakSync(prompt)
    }

    /** 停止正在进行的语音。 */
    fun stopSpeaking() {
        tts?.stop()
        isSpeaking = false
    }

    /** 切换教练语言。 */
    fun setLanguage(newLanguage: String) {
        language = newLanguage
        tts?.language = resolveLocale(newLanguage)
    }

    /** 释放 TTS 资源。 */
    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsInitialized = false
    }

    // ── 内部播报 ──────────────────────────────────────────────────────────────

    private fun speakSync(prompt: CoachPrompt) {
        lastPromptTimeMillis = System.currentTimeMillis()
        promptCount++
        onPromptQueued?.invoke(prompt)

        if (isMuted) return

        // 如 TTS 未初始化则尝试重新初始化
        if (!ttsInitialized || tts == null) {
            initTTS()
            if (!ttsInitialized) return
        }

        val utteranceId = "coach_$promptCount"
        tts?.apply {
            // 切换语速和音调 (稍慢，运动时更清晰)
            setSpeechRate(0.52f)
            setPitch(0.95f)
            language = resolveLocale(prompt.language)

            // Android TTS API: >21 使用 speak(CharSequence, int, Bundle, String)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                speak(prompt.text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
            } else {
                @Suppress("DEPRECATION")
                speak(prompt.text, TextToSpeech.QUEUE_FLUSH, null)
            }
        }
    }

    // ── 提示工厂方法 ─────────────────────────────────────────────────────────

    private fun makeCadencePrompt(delta: Double, direction: String): CoachPrompt {
        val absDelta = kotlin.math.abs(delta).toInt()
        val priority = if (absDelta > 25) 2 else 1

        val text = when (language) {
            "zh" -> if (direction == "low") {
                "步频偏低，加快节奏，小步快跑。"
            } else {
                "步频偏快，放慢节奏，加大步幅。"
            }
            "nl" -> if (direction == "low") {
                "Cadans te laag. Verhoog je pasfrequentie met kortere passen."
            } else {
                "Cadans te hoog. Verlaag je tempo en verleng je passen."
            }
            else -> if (direction == "low") {
                "Cadence is $absDelta steps low. Shorten your stride and pick up the tempo."
            } else {
                "Cadence is $absDelta steps high. Lengthen your stride and settle into a rhythm."
            }
        }

        return CoachPrompt(
            text = text,
            language = language,
            priority = priority,
            category = CoachCategory.cadence
        )
    }

    private fun makeGaitPrompt(
        category: CoachCategory,
        value: Double,
        unit: String,
        threshold: Double
    ): CoachPrompt {
        val text = when (language) {
            "zh" -> when (category) {
                CoachCategory.verticalOscillation ->
                    "垂直振幅偏高，收紧核心，减少上下跳动。"
                CoachCategory.groundContactTime ->
                    "触地时间偏长，加快脚步转换，提高步频。"
                CoachCategory.trunkLean ->
                    if (value > 0) "身体前倾过多，稍微挺直上身。"
                    else "身体后仰，稍微前倾利用重力。"
                else -> "调整跑姿。"
            }
            "nl" -> when (category) {
                CoachCategory.verticalOscillation ->
                    "Te veel verticale beweging. Span je core aan en loop efficiënter."
                CoachCategory.groundContactTime ->
                    "Grondcontact te lang. Verhoog je pasfrequentie voor een lichtere landing."
                CoachCategory.trunkLean ->
                    if (value > 0) "Je leunt te ver voorover. Richt je bovenlichaam iets op."
                    else "Je leunt achterover. Helling iets naar voren voor betere voortstuwing."
                else -> "Pas je houding aan."
            }
            else -> when (category) {
                CoachCategory.verticalOscillation ->
                    "Reduce bounce. Engage your core and land softly."
                CoachCategory.groundContactTime ->
                    "Ground contact too long. Quick, light steps."
                CoachCategory.trunkLean ->
                    if (value > 0) "Leaning too far forward. Straighten up slightly."
                    else "Leaning back. Tilt forward slightly from the ankles."
                else -> "Adjust your form."
            }
        }

        return CoachPrompt(
            text = text,
            language = language,
            priority = 1,
            category = category
        )
    }

    // ── Locale 解析 ───────────────────────────────────────────────────────────

    /**
     * 将语言代码映射到 Android [Locale]。
     * "zh" → Simplified Chinese, "nl" → Dutch, 否则 → English US。
     */
    private fun resolveLocale(lang: String): Locale {
        return when (lang) {
            "zh" -> Locale.SIMPLIFIED_CHINESE
            "nl" -> Locale("nl", "NL")
            else -> Locale.US
        }
    }
}
