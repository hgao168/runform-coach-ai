package com.runformcoach.runformcoachai.sensor

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject

// ── 会话状态枚举 ─────────────────────────────────────────────────────────────

/**
 * [RunSessionManager] 会话状态机状态。
 */
enum class RunSessionState {
    idle,
    ready,
    running,
    paused,
    stopped
}

// ── 会话配置 ──────────────────────────────────────────────────────────────────

/**
 * 实时跑步会话配置。
 *
 * @property targetCadenceSPM      目标步频 (步/分)
 * @property coachingLanguage      教练语言代码 ("en", "zh", "nl")
 * @property minPromptIntervalSec  语音提示最小间隔 (秒)
 * @property sensorWindowSeconds   传感器缓冲窗口 (秒), 限制 3–10
 * @property samplingRate          传感器采样率 (Hz)
 */
data class RunSessionConfig(
    val targetCadenceSPM: Double = 170.0,
    val coachingLanguage: String = "en",
    val minPromptIntervalSec: Int = 15,
    val sensorWindowSeconds: Double = 6.0,
    val samplingRate: Double = 60.0
) {
    init {
        require(sensorWindowSeconds in 3.0..10.0) {
            "sensorWindowSeconds 必须在 3–10 之间, 实际: $sensorWindowSeconds"
        }
    }
}

// ── 会话指标 ──────────────────────────────────────────────────────────────────

/**
 * 聚合会话指标，通过 [onMetricsUpdate] 回调投递给 UI。
 */
data class SessionMetrics(
    val cadence: CadenceSample? = null,
    val gait: GaitSnapshot? = null,
    val elapsedSeconds: Double = 0.0,
    val state: RunSessionState = RunSessionState.idle,
    val promptHistory: List<CoachPrompt> = emptyList()
)

// ── RunSessionManager ────────────────────────────────────────────────────────

/**
 * 实时跑步教练管线编排器:
 * `SensorCaptureManager → CadenceDetector → GaitAnalyzer → AudioCoachEngine`
 *
 * 状态机: `idle → ready → running → paused → stopped`
 *
 * 使用 [StateFlow] 暴露状态和指标, [@HiltViewModel] 注入。
 *
 * 用法:
 * ```
 * // Hilt 自动注入
 * @HiltViewModel
 * class MyViewModel @Inject constructor(
 *     private val sessionManager: RunSessionManager
 * ) : ViewModel() { ... }
 *
 * // 或手动创建
 * val session = RunSessionManager(context, config)
 * session.start()
 * session.pause()
 * session.resume()
 * session.stop()
 * ```
 */
@HiltViewModel
class RunSessionManager @Inject constructor(
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    companion object {
        private const val TAG = "RunSessionManager"
        private const val METRICS_INTERVAL_MS = 1000L  // 1 Hz
        private const val MAX_PROMPT_HISTORY = 50
    }

    // ── 公开属性 ──────────────────────────────────────────────────────────────

    /** 当前会话状态。 */
    private val _state = MutableStateFlow(RunSessionState.idle)
    val state: StateFlow<RunSessionState> = _state.asStateFlow()

    /** 会话配置。 */
    var config: RunSessionConfig = RunSessionConfig()
        private set

    /** 已用时间 (秒)，排除暂停时段。 */
    private val _elapsedSeconds = MutableStateFlow(0.0)
    val elapsedSeconds: StateFlow<Double> = _elapsedSeconds.asStateFlow()

    /** 本会话中播报过的教练提示历史。 */
    private val _promptHistory = MutableStateFlow<List<CoachPrompt>>(emptyList())
    val promptHistory: StateFlow<List<CoachPrompt>> = _promptHistory.asStateFlow()

    /** 聚合指标回调 (供 UI 更新)。 */
    var onMetricsUpdate: ((SessionMetrics) -> Unit)? = null

    /** 状态转换回调。 */
    var onStateChange: ((old: RunSessionState, new: RunSessionState) -> Unit)? = null

    /** 教练提示播报回调 (供 UI overlay)。 */
    var onCoachPrompt: ((CoachPrompt) -> Unit)? = null

    // ── 管线组件 ──────────────────────────────────────────────────────────────

    lateinit var sensorCaptureManager: SensorCaptureManager
        private set

    lateinit var cadenceDetector: CadenceDetector
        private set

    lateinit var gaitAnalyzer: GaitAnalyzer
        private set

    lateinit var audioCoach: AudioCoachEngine
        private set

    // ── 内部状态 ──────────────────────────────────────────────────────────────

    private var sessionStartTimeMillis: Long = 0L
    private var pauseStartTimeMillis: Long? = null
    private var totalPausedMillis: Long = 0L
    private var metricsJob: Job? = null
    private var sensorCollectJob: Job? = null

    // ── 初始化管线 ────────────────────────────────────────────────────────────

    /**
     * 使用默认配置或指定配置初始化管线组件。
     *
     * 一般在 [init] 或首次 [start] 之前调用。
     */
    fun configure(cfg: RunSessionConfig = RunSessionConfig()) {
        config = cfg

        sensorCaptureManager = SensorCaptureManager(appContext)

        cadenceDetector = CadenceDetector(
            alpha = 0.8,
            windowSeconds = config.sensorWindowSeconds,
            minCadenceSPM = 50.0,
            maxCadenceSPM = 240.0
        )

        gaitAnalyzer = GaitAnalyzer(
            windowSeconds = config.sensorWindowSeconds,
            samplingRate = config.samplingRate
        )

        audioCoach = AudioCoachEngine(
            appContext,
            language = config.coachingLanguage,
            minIntervalSeconds = config.minPromptIntervalSec
        )

        wirePipeline()
    }

    // ── 管线连接 ──────────────────────────────────────────────────────────────

    private fun wirePipeline() {
        // SensorCaptureManager → CadenceDetector + GaitAnalyzer
        sensorCollectJob?.cancel()
        sensorCollectJob = viewModelScope.launch {
            sensorCaptureManager.sensorFrames().collect { frame ->
                // 计算加速度向量模长喂给步频检测器
                val accelMag = kotlin.math.sqrt(
                    (frame.accelX * frame.accelX +
                     frame.accelY * frame.accelY +
                     frame.accelZ * frame.accelZ).toDouble()
                )
                cadenceDetector.process(accelMag)

                // 完整帧喂给步态分析器
                gaitAnalyzer.process(frame)
            }
        }

        // CadenceDetector → AudioCoach 评估
        viewModelScope.launch {
            cadenceDetector.currentCadence.collectLatest { cadence ->
                if (cadence != null && _state.value == RunSessionState.running) {
                    // Inject latest cadence into gait analyzer for snapshot enrichment
                    gaitAnalyzer.latestCadenceSPM = cadence.currentSPM
                    val gait = gaitAnalyzer.currentSnapshot.value
                    audioCoach.evaluate(
                        cadence = cadence,
                        gait = gait,
                        targetCadence = config.targetCadenceSPM,
                        elapsedSeconds = _elapsedSeconds.value
                    )
                }
            }
        }

        // AudioCoach 提示 → UI 回调 + 历史
        audioCoach.onPromptQueued = { prompt ->
            val current = _promptHistory.value.toMutableList()
            current.add(prompt)
            if (current.size > MAX_PROMPT_HISTORY) {
                current.removeAt(0)
            }
            _promptHistory.value = current
            onCoachPrompt?.invoke(prompt)
        }
    }

    // ── 公开 API: 状态机 ──────────────────────────────────────────────────────

    /**
     * idle → ready → running。
     */
    fun start() {
        if (_state.value != RunSessionState.idle && _state.value != RunSessionState.ready) {
            Log.w(TAG, "无法从 ${_state.value} 启动")
            return
        }

        // 确保管线已配置
        if (!::sensorCaptureManager.isInitialized) {
            configure(config)
        }

        transitionTo(RunSessionState.ready)
        transitionTo(RunSessionState.running)

        sessionStartTimeMillis = System.currentTimeMillis()
        totalPausedMillis = 0L
        _elapsedSeconds.value = 0.0
        _promptHistory.value = emptyList()

        sensorCaptureManager.start()
        startMetricsTimer()
    }

    /** 暂停会话 (传感器继续运行，但指标和教练暂停)。 */
    fun pause() {
        if (_state.value != RunSessionState.running) return
        pauseStartTimeMillis = System.currentTimeMillis()
        transitionTo(RunSessionState.paused)
    }

    /** 从暂停恢复。 */
    fun resume() {
        if (_state.value != RunSessionState.paused) return
        pauseStartTimeMillis?.let { start ->
            totalPausedMillis += System.currentTimeMillis() - start
            pauseStartTimeMillis = null
        }
        transitionTo(RunSessionState.running)
    }

    /** 完全停止会话。 */
    fun stop() {
        if (_state.value == RunSessionState.idle || _state.value == RunSessionState.stopped) return

        sensorCaptureManager.stop()
        stopMetricsTimer()
        cadenceDetector.reset()
        gaitAnalyzer.reset()
        audioCoach.stopSpeaking()
        sensorCollectJob?.cancel()

        transitionTo(RunSessionState.stopped)
        transitionTo(RunSessionState.idle)
    }

    // ── 指标定时器 (~1 Hz) ────────────────────────────────────────────────────

    private fun startMetricsTimer() {
        metricsJob?.cancel()
        metricsJob = viewModelScope.launch {
            while (true) {
                delay(METRICS_INTERVAL_MS)
                if (_state.value != RunSessionState.running) continue

                // 更新已用时间 (扣除暂停)
                val now = System.currentTimeMillis()
                _elapsedSeconds.value =
                    ((now - sessionStartTimeMillis - totalPausedMillis) / 1000.0)
                    .coerceAtLeast(0.0)

                // 发射聚合指标
                val metrics = SessionMetrics(
                    cadence = cadenceDetector.currentCadence.value,
                    gait = gaitAnalyzer.currentSnapshot.value,
                    elapsedSeconds = _elapsedSeconds.value,
                    state = _state.value,
                    promptHistory = _promptHistory.value
                )
                onMetricsUpdate?.invoke(metrics)
            }
        }
    }

    private fun stopMetricsTimer() {
        metricsJob?.cancel()
        metricsJob = null
    }

    // ── 状态转换 ──────────────────────────────────────────────────────────────

    private fun transitionTo(newState: RunSessionState) {
        val oldState = _state.value
        if (oldState == newState) return
        _state.value = newState
        Log.i(TAG, "$oldState → $newState")
        onStateChange?.invoke(oldState, newState)
    }

    // ── ViewModel 生命周期 ────────────────────────────────────────────────────

    override fun onCleared() {
        super.onCleared()
        stopMetricsTimer()
        sensorCollectJob?.cancel()
        sensorCaptureManager.stop()
        audioCoach.shutdown()
        Log.d(TAG, "RunSessionManager 已清理")
    }
}
