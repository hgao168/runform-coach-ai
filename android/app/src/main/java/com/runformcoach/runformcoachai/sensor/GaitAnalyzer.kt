package com.runformcoach.runformcoachai.sensor

import android.util.Log
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.exp
import kotlin.math.sqrt

// ── GaitSnapshot ─────────────────────────────────────────────────────────────

/**
 * 实时步态快照，由 [GaitAnalyzer] 产出。
 *
 * @property verticalOscillationCm  垂直振幅 (cm)
 * @property groundContactTimeMs    触地时间估算 (ms)
 * @property trunkLeanDegrees       躯干倾角 (°), 正值 = 前倾
 * @property cadenceSPM             快照时的滚动平均步频
 * @property timestamp              快照时间戳 (epoch millis)
 */
data class GaitSnapshot(
    val verticalOscillationCm: Double = 0.0,
    val groundContactTimeMs: Double = 0.0,
    val trunkLeanDegrees: Double = 0.0,
    val cadenceSPM: Double = 0.0,
    val timestamp: Long = System.currentTimeMillis()
)

/**
 * 垂直振幅滚动统计。
 */
data class VerticalOscillationStats(
    val mean: Double,
    val stdDev: Double,
    val trend: Double
)

// ── GaitAnalyzer ─────────────────────────────────────────────────────────────

/**
 * 实时步态指标提取器 —— 加速度计 + 陀螺仪融合。
 *
 * 从 [SensorFrame] 滑动窗口计算:
 * - **垂直振幅** (cm): 垂直加速度去除重力后双重积分
 * - **触地时间** (ms): 从陀螺仪 pitch-rate 零交叉估算
 * - **躯干倾角** (°): 矢状面重力向量倾角
 *
 * 生物力学公式对齐视频分析 [PoseExtractor]。
 *
 * 输出 [StateFlow]<[GaitSnapshot]?> 供 UI 订阅。
 *
 * 用法:
 * ```
 * val analyzer = GaitAnalyzer(windowSeconds = 5.0, samplingRate = 60.0)
 * analyzer.process(sensorFrame)
 * analyzer.currentSnapshot.collect { snapshot -> ... }
 * ```
 */
class GaitAnalyzer(
    /** 分析窗口时长 (秒)，限制 3–10。 */
    windowSeconds: Double = 5.0,
    /** 假定采样率 (Hz) —— 用于积分时间步长。 */
    val samplingRate: Double = 60.0
) {
    companion object {
        private const val TAG = "GaitAnalyzer"
        private const val GRAVITY_THRESHOLD = 0.85
        /** 每次发射快照的最小间隔 (秒)。 */
        private const val EMIT_THROTTLE_SEC = 1.0
        /** 速度积分器衰减周期 (约每 30 秒样本数)。 */
        private const val VELOCITY_DECAY_PERIOD_SAMPLES = 1800  // 30s * 60 Hz
    }

    /** 分析窗口时长 (秒)。 */
    val windowSeconds: Double = maxOf(3.0, minOf(10.0, windowSeconds))

    // ── 公开状态 ──────────────────────────────────────────────────────────────
    private val _currentSnapshot = MutableStateFlow<GaitSnapshot?>(null)

    /// Latest cadence SPM, injected by RunSessionManager from CadenceDetector.
    @Volatile var latestCadenceSPM: Double = 0.0
    val currentSnapshot: StateFlow<GaitSnapshot?> = _currentSnapshot.asStateFlow()

    private val _verticalOscillationStats = MutableStateFlow<VerticalOscillationStats?>(null)
    val verticalOscillationStats: StateFlow<VerticalOscillationStats?> = _verticalOscillationStats.asStateFlow()

    // ── 内部状态 ──────────────────────────────────────────────────────────────

    private val accelZHistory = ArrayDeque<Double>()
    private val accelYHistory = ArrayDeque<Double>()
    private val gyroXHistory = ArrayDeque<Double>()
    private val timestamps = ArrayDeque<Long>()
    private var frameCount: Int = 0
    private var lastSnapshotEmitTime: Long = 0L

    // 垂直振幅积分状态
    private var velocityZ: Double = 0.0
    private var positionZ: Double = 0.0
    private val positionZHistory = ArrayDeque<Double>()
    private var lastTimestampNanos: Long? = null

    // 重力基线 (加速度 Z 轴的慢速指数移动平均)
    private var gravityBaseline: Double = -1.0

    private val maxHistorySamples: Int
        get() = maxOf((windowSeconds * samplingRate).toInt(), 60)

    // ── 公开 API ──────────────────────────────────────────────────────────────

    /** 喂入单个 [SensorFrame]，可能产出一个步态更新。 */
    fun process(frame: SensorFrame) {
        processSync(frame)
    }

    /** 批量处理 (例如环形缓冲区快照)。 */
    fun processBatch(frames: List<SensorFrame>) {
        for (frame in frames) {
            processSync(frame)
        }
    }

    /** 重置所有累积状态。 */
    fun reset() {
        accelZHistory.clear()
        accelYHistory.clear()
        gyroXHistory.clear()
        timestamps.clear()
        positionZHistory.clear()
        frameCount = 0
        velocityZ = 0.0
        positionZ = 0.0
        lastTimestampNanos = null
        gravityBaseline = -1.0
        _currentSnapshot.value = null
        _verticalOscillationStats.value = null
        lastSnapshotEmitTime = 0L
    }

    // ── 内部处理 ──────────────────────────────────────────────────────────────

    private fun processSync(frame: SensorFrame) {
        frameCount++

        // 追加到历史缓冲区 (使用 accelZ 作为垂直, accelY 作为前后, gyroX 为 pitch rate)
        accelZHistory.addLast(frame.accelZ.toDouble())
        accelYHistory.addLast(frame.accelY.toDouble())
        gyroXHistory.addLast(frame.gyroX.toDouble())
        timestamps.addLast(frame.timestampNanos)

        // 强制窗口大小
        while (accelZHistory.size > maxHistorySamples) {
            accelZHistory.removeFirst()
            accelYHistory.removeFirst()
            gyroXHistory.removeFirst()
            timestamps.removeFirst()
            if (positionZHistory.isNotEmpty()) positionZHistory.removeFirst()
        }

        // ── 垂直振幅 (双重积分) ─────────────────────────────────────────────

        // 更新重力基线 (慢速 EMA)
        val alphaGrav = 0.95
        gravityBaseline = alphaGrav * gravityBaseline + (1.0 - alphaGrav) * frame.accelZ

        // 去除重力 → 动态垂直加速度
        val dynamicAccelZ = frame.accelZ - gravityBaseline

        // 积分: v[n] = v[n-1] + a[n] * dt
        if (lastTimestampNanos != null) {
            val dtSec = maxOf(0.001, (frame.timestampNanos - lastTimestampNanos!!) / 1_000_000_000.0)
            velocityZ += dynamicAccelZ * dtSec

            // 高通滤波速度去除漂移 (τ = 1.5s)
            val alphaVel = exp(-dtSec / 1.5)
            velocityZ *= alphaVel

            // 积分速度 → 位移
            positionZ += velocityZ * dtSec

            // 漂移补偿: 缓慢泄露位移趋向 0
            positionZ *= 0.998
        }
        lastTimestampNanos = frame.timestampNanos

        positionZHistory.addLast(positionZ)
        while (positionZHistory.size > maxHistorySamples) {
            positionZHistory.removeFirst()
        }

        // ── 躯干倾角 ────────────────────────────────────────────────────────

        // 从加速度计估算: lean ≈ atan2(accelY, -accelZ)
        // accelY = 前后, accelZ = 垂直 (正值向上时, 直立时 accelZ ≈ -1g)
        val smoothedAccelY = exponentialSmoothLast(accelYHistory, alpha = 0.9)
        val smoothedAccelZ = exponentialSmoothLast(accelZHistory, alpha = 0.9)
        val leanRadians = atan2(smoothedAccelY, -smoothedAccelZ)
        val trunkLeanDeg = leanRadians * 180.0 / Math.PI

        // ── 触地时间 (GCT) ──────────────────────────────────────────────────

        val gctEstimate = estimateGCT(gyroXHistory)

        // ── 垂直振幅计算 ────────────────────────────────────────────────────

        val vertOscCm = computeVerticalOscillation()

        // ── 滚动统计 ────────────────────────────────────────────────────────

        if (positionZHistory.size >= 10) {
            val meanPos = positionZHistory.sum() / positionZHistory.size
            val stdPos = stdDev(positionZHistory)
            val trend = computeTrend(positionZHistory)
            _verticalOscillationStats.value = VerticalOscillationStats(
                mean = meanPos, stdDev = stdPos, trend = trend
            )
        }

        // 定期衰减速度积分器，防止长时间运行中漂移无限增长
        if (frameCount % VELOCITY_DECAY_PERIOD_SAMPLES == 0) {
            velocityZ *= 0.5
        }

        // ── 限流发射 (最多 1 Hz) ───────────────────────────────────────────

        val now = System.currentTimeMillis()
        val throttleMs = (EMIT_THROTTLE_SEC * 1000).toLong()
        if (now - lastSnapshotEmitTime < throttleMs) {
            return
        }
        lastSnapshotEmitTime = now

        val snapshot = GaitSnapshot(
            verticalOscillationCm = vertOscCm,
            groundContactTimeMs = gctEstimate,
            trunkLeanDegrees = trunkLeanDeg,
            cadenceSPM = latestCadenceSPM,
            timestamp = now
        )
        _currentSnapshot.value = snapshot
    }

    // ── 指标计算 ──────────────────────────────────────────────────────────────

    /**
     * 从位移历史计算垂直振幅 (峰峰值 / 2, 单位 cm)。
     *
     * positionZ 单位: g·s² → ×9.81 m/s² → m → ×100 cm。
     */
    private fun computeVerticalOscillation(): Double {
        if (positionZHistory.size < 10) return 0.0
        val positionsM = positionZHistory.map { it * 9.81 }
        val pMin = positionsM.minOrNull() ?: 0.0
        val pMax = positionsM.maxOrNull() ?: 0.0
        val amplitudeM = (pMax - pMin) / 2.0
        val amplitudeCm = amplitudeM * 100.0
        return clamp(amplitudeCm, 0.0, 35.0)
    }

    /**
     * 从陀螺仪 pitch-rate 信号估算触地时间。
     *
     * 支撑期脚部作为支点产生快速俯仰旋转。
     * GCT ≈ 陀螺仪幅值超过峰值 30% 的样本数 / 采样率。
     */
    private fun estimateGCT(gyroHistory: List<Double>): Double {
        if (gyroHistory.size < 10) return 0.0
        val absGyro = gyroHistory.map { abs(it) }
        val peak = absGyro.maxOrNull() ?: 0.0
        if (peak <= 0.1) return 0.0

        val threshold = peak * 0.3
        var aboveThreshold = 0
        for (v in absGyro) {
            if (v >= threshold) aboveThreshold++
        }
        val durationSec = aboveThreshold / samplingRate
        val durationMs = durationSec * 1000.0
        // 典型跑步者 GCT: 150–300 ms
        return clamp(durationMs, 80.0, 500.0)
    }

    /** 对历史序列最后值的指数移动平均。 */
    private fun exponentialSmoothLast(history: List<Double>, alpha: Double): Double {
        if (history.isEmpty()) return 0.0
        if (history.size == 1) return history[0]
        val latest = history.last()
        val prevAvg = history.dropLast(1).sum() / (history.size - 1)
        return alpha * prevAvg + (1.0 - alpha) * latest
    }

    /** 简单趋势: 近期一半与较旧一半均值之差。 */
    private fun computeTrend(values: List<Double>): Double {
        val n = values.size
        if (n < 8) return 0.0
        val mid = n / 2
        val olderMean = values.subList(0, mid).sum() / mid
        val recentMean = values.subList(mid, n).sum() / (n - mid)
        return recentMean - olderMean
    }

    /** 总体标准差。 */
    private fun stdDev(values: List<Double>): Double {
        val n = values.size.toDouble()
        if (n <= 1) return 0.0
        val m = values.sum() / n
        val variance = values.sumOf { (it - m) * (it - m) } / n
        return sqrt(variance)
    }

    private fun clamp(value: Double, min: Double, max: Double): Double {
        return value.coerceIn(min, max)
    }
}
