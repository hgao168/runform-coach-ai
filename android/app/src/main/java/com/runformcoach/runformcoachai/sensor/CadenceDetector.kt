package com.runformcoach.runformcoachai.sensor

import android.util.Log
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.math.sqrt

// ── CadenceSample ────────────────────────────────────────────────────────────

/**
 * 实时步频估计值，由 [CadenceDetector] 产出。
 */
data class CadenceSample(
    val stepsPerMinute: Double,
    val timestamp: Long = System.currentTimeMillis(),
    val confidence: Double = 0.0,
    val windowDurationSeconds: Double = 5.0
)

// ── CadenceDetector ──────────────────────────────────────────────────────────

/**
 * 实时步频检测器 —— 基于 TYPE_ACCELEROMETER 零交叉峰值检测。
 *
 * 管线:
 * 1. 低通滤波 (α = 0.8) 隔离 ~2–4 Hz 步频信号
 * 2. 均值中心化
 * 3. 向上零交叉检测计步
 * 4. 时间窗口 → SPM
 * 5. 滞后 + 置信度评分
 *
 * 输出 [StateFlow]<[CadenceSample]?> 供 UI 层订阅;
 * 同时暴露 [Flow]<[Float]> 输出步频 BPM (步/分)。
 *
 * 用法:
 * ```
 * val detector = CadenceDetector(alpha = 0.8)
 * detector.process(accelMagnitude)
 * // 订阅:
 * detector.cadenceBpmFlow.collect { bpm -> ... }
 * ```
 */
class CadenceDetector(
    /** 低通滤波因子 (0 = 无滤波, 1 = 最大平滑)。默认 0.8 针对 ~60 Hz 跑步步频调优。 */
    val alpha: Double = 0.8,
    /** 最小合理步频 SPM (低于此值 → 低置信度)。 */
    val minCadenceSPM: Double = 50.0,
    /** 最大合理步频 SPM (高于此值 → 截断)。 */
    val maxCadenceSPM: Double = 240.0,
    /** 分析窗口时长 (秒)。 */
    val windowSeconds: Double = 5.0
) {
    companion object {
        private const val TAG = "CadenceDetector"
        /** 采样率假设 (Hz) —— 用于时间戳推算。 */
        private const val ASSUMED_HZ = 60.0
        /** 两步之间最小间隔 (秒) ≈ 400 SPM 上限。 */
        private const val MIN_STEP_INTERVAL = 0.15
        /** 每次发射的最小间隔 (秒) —— 限流，避免 flooding。 */
        private const val EMIT_THROTTLE_SEC = 0.5
    }

    // ── 公开状态 ──────────────────────────────────────────────────────────────

    /** 最新步频估计。 */
    private val _currentCadence = MutableStateFlow<CadenceSample?>(null)
    val currentCadence: StateFlow<CadenceSample?> = _currentCadence.asStateFlow()

    /** Flow<Float> 输出步频 BPM —— 对应规范中的 Flow<Float>。 */
    private val _cadenceBpmFlow = MutableSharedFlow<Float>(replay = 0, extraBufferCapacity = 8)
    val cadenceBpmFlow: Flow<Float> = _cadenceBpmFlow

    // ── 内部状态 ──────────────────────────────────────────────────────────────

    private var filteredValue: Double = 0.0
    private val filteredHistory = ArrayDeque<Double>()
    private val rawHistory = ArrayDeque<Double>()
    private var sampleCount: Int = 0
    private var lastStepSampleIndex: Int? = null
    private val stepIntervals = ArrayDeque<Double>()  // 最近步间间隔 (秒)
    private var lastEmitTimestamp: Long = 0L

    /** 历史最大样本数: windowSeconds * 60 Hz，至少 90。 */
    private val maxHistorySamples: Int
        get() = maxOf((windowSeconds * ASSUMED_HZ).toInt(), 90)

    // ── 公开 API ──────────────────────────────────────────────────────────────

    /**
     * 喂入单个加速度值 (magnitude 或单轴 g-force) 并可能产出一个步频更新。
     *
     * 调用方应传入加速度向量模长 `sqrt(ax²+ay²+az²)` 或最接近垂直方向的单轴值。
     */
    fun process(value: Double) {
        processSync(value)
    }

    /**
     * 批量处理 (例如环形缓冲区快照)。
     */
    fun processBatch(values: List<Double>) {
        for (v in values) {
            processSync(v)
        }
    }

    /** 重置检测器状态。 */
    fun reset() {
        filteredValue = 0.0
        filteredHistory.clear()
        rawHistory.clear()
        sampleCount = 0
        lastStepSampleIndex = null
        stepIntervals.clear()
        _currentCadence.value = null
        lastEmitTimestamp = 0L
    }

    // ── 内部处理 ──────────────────────────────────────────────────────────────

    private fun processSync(value: Double) {
        // 1. 低通滤波: y[n] = α * y[n-1] + (1-α) * x[n]
        filteredValue = alpha * filteredValue + (1.0 - alpha) * value
        filteredHistory.addLast(filteredValue)
        rawHistory.addLast(value)
        sampleCount++

        // 强制历史窗口大小
        while (filteredHistory.size > maxHistorySamples) {
            filteredHistory.removeFirst()
            rawHistory.removeFirst()
        }

        // 2. 均值中心化 + 零交叉检测
        if (filteredHistory.size < 5) return

        val mean = filteredHistory.sum() / filteredHistory.size

        // 在最近 N 个滤波样本中检测向上零交叉
        val recentCount = minOf(filteredHistory.size, 8)
        val startIdx = filteredHistory.size - recentCount

        for (i in (startIdx + 1) until filteredHistory.size) {
            val prev = filteredHistory[i - 1] - mean
            val curr = filteredHistory[i] - mean
            if (prev < 0 && curr >= 0) {
                // 向上零交叉 = 检测到一步
                val stepSampleIdx = sampleCount - (filteredHistory.size - i)
                if (lastStepSampleIndex != null) {
                    val rawInterval = (stepSampleIdx - lastStepSampleIndex!!) / ASSUMED_HZ
                    val interval = maxOf(MIN_STEP_INTERVAL, rawInterval)
                    stepIntervals.addLast(interval)
                    while (stepIntervals.size > 60) {
                        stepIntervals.removeFirst()
                    }
                }
                lastStepSampleIndex = stepSampleIdx
            }
        }

        // 3. 从步间间隔计算步频
        val cadenceSPM: Double
        val confidence: Double

        if (stepIntervals.size >= 2) {
            val avgInterval = stepIntervals.sum() / stepIntervals.size
            cadenceSPM = clamp(60.0 / avgInterval, minCadenceSPM, maxCadenceSPM)
            val cv = if (stepIntervals.size >= 3) {
                stdDev(stepIntervals) / avgInterval
            } else 1.0
            val consistencyScore = clamp(1.0 - cv, 0.0, 1.0)
            val sampleScore = minOf(1.0, stepIntervals.size.toDouble() / 8.0)
            confidence = 0.5 * consistencyScore + 0.5 * sampleScore
        } else if (filteredHistory.size >= maxHistorySamples / 2) {
            // 回退: 对整个窗口做零交叉计数
            val zcCount = countZeroCrossings(filteredHistory)
            val windowTime = filteredHistory.size / ASSUMED_HZ
            val rawSPM = if (windowTime > 0) zcCount / windowTime * 60.0 else 0.0
            cadenceSPM = clamp(rawSPM, minCadenceSPM, maxCadenceSPM)
            confidence = maxOf(0.1, minOf(0.6, zcCount / 15.0))
        } else {
            // 数据不足
            return
        }

        // 4. 限流发射 (最多每 0.5s 一次)
        val now = System.currentTimeMillis()
        if (now - lastEmitTimestamp < (EMIT_THROTTLE_SEC * 1000).toLong()) {
            return
        }
        lastEmitTimestamp = now

        val sample = CadenceSample(
            stepsPerMinute = cadenceSPM,
            timestamp = now,
            confidence = confidence,
            windowDurationSeconds = windowSeconds
        )
        _currentCadence.value = sample
        _cadenceBpmFlow.tryEmit(cadenceSPM.toFloat())
    }

    // ── 工具函数 ──────────────────────────────────────────────────────────────

    /** 向上零交叉计数 (均值中心化后)。 */
    private fun countZeroCrossings(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        val mean = values.sum() / values.size
        var count = 0
        for (i in 1 until values.size) {
            if (values[i - 1] - mean < 0 && values[i] - mean >= 0) {
                count++
            }
        }
        return count.toDouble()
    }

    /** 总体标准差。 */
    private fun stdDev(values: List<Double>): Double {
        val n = values.size.toDouble()
        if (n <= 1) return 0.0
        val m = values.sum() / n
        val variance = values.sumOf { (it - m) * (it - m) } / n
        return sqrt(variance)
    }

    /** 截断到 [min, max] 区间。 */
    private fun clamp(value: Double, min: Double, max: Double): Double {
        return value.coerceIn(min, max)
    }
}
