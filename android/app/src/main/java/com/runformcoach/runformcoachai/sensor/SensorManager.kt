package com.runformcoach.runformcoachai.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager as AndroidSensorManager
import android.util.Log
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

/**
 * 单帧传感器数据，包含加速度计和陀螺仪的原始读数。
 *
 * @property accelX  X 轴加速度 (m/s²)
 * @property accelY  Y 轴加速度 (m/s²)
 * @property accelZ  Z 轴加速度 (m/s²)，含重力
 * @property gyroX   X 轴角速度 (rad/s)
 * @property gyroY   Y 轴角速度 (rad/s)
 * @property gyroZ   Z 轴角速度 (rad/s)
 * @property timestampNanos 系统启动以来的纳秒时间戳 (SensorEvent.timestamp)
 */
data class SensorFrame(
    val accelX: Float,
    val accelY: Float,
    val accelZ: Float,
    val gyroX: Float,
    val gyroY: Float,
    val gyroZ: Float,
    val timestampNanos: Long
)

/**
 * 封装 Android [SensorManager]，对外暴露 [Flow]<[SensorFrame]>。
 *
 * 使用 [AndroidSensorManager.SENSOR_DELAY_GAME] (约 20 ms 间隔) 实现 ~50 Hz 采样率。
 * 加速度计和陀螺仪各自独立注册，任一传感器不可用时不会阻塞另一传感器。
 *
 * 用法：
 * ```
 * val manager = SensorCaptureManager(context)
 * manager.sensorFrames().collect { frame -> /* 处理 */ }
 * manager.start()
 * // ...
 * manager.stop()
 * ```
 */
class SensorCaptureManager(context: Context) {

    companion object {
        private const val TAG = "SensorCaptureManager"
    }

    private val sensorManager: AndroidSensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as AndroidSensorManager

    val accelSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    val gyroSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

    // ── 缓存最新值，保证每次 emit 携带完整的六轴数据 ──────────────────────────
    @Volatile private var latestAccel = FloatArray(3)
    @Volatile private var latestGyro = FloatArray(3)

    @Volatile private var isRunning = false

    /** Signal that start() has been called; callbackFlow waits on this. */
    private val started = java.util.concurrent.atomic.AtomicBoolean(false)

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> {
                    latestAccel = event.values.clone()
                }
                Sensor.TYPE_GYROSCOPE -> {
                    latestGyro = event.values.clone()
                }
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
            Log.d(TAG, "精度变化: ${sensor?.name} → $accuracy")
        }
    }

    /**
     * 返回冷流 ([callbackFlow])，调用 [start] 后开始发射数据。
     *
     * 每秒约 50 帧。上游注册了独立的定时发射机制，
     * 避免传感器回调频率不稳定导致丢帧或频率抖动。
     */
    fun sensorFrames(): Flow<SensorFrame> = callbackFlow {
        var frameCount = 0L
        val startRealtime = System.currentTimeMillis()

        // Wait until start() is called before beginning emission
        while (!started.get()) {
            kotlinx.coroutines.delay(50)
        }

        while (isRunning) {
            val frame = SensorFrame(
                accelX = latestAccel[0],
                accelY = latestAccel[1],
                accelZ = latestAccel[2],
                gyroX = latestGyro[0],
                gyroY = latestGyro[1],
                gyroZ = latestGyro[2],
                timestampNanos = System.nanoTime()
            )

            trySend(frame)
            frameCount++

            // ~50 Hz = 20 ms 间隔
            kotlinx.coroutines.delay(20)
        }

        Log.d(TAG, "Flow 结束，共发射 $frameCount 帧，持续 ${System.currentTimeMillis() - startRealtime} ms")

        awaitClose {
            Log.d(TAG, "Flow 已关闭")
        }
    }

    // ── 生命周期控制 ─────────────────────────────────────────────────────────

    /**
     * 注册加速度计和陀螺仪监听器。任一传感器不可用时打印警告，不会抛异常。
     */
    fun start() {
        if (isRunning) {
            Log.w(TAG, "传感器已在运行，忽略重复 start()")
            return
        }

        if (accelSensor != null) {
            sensorManager.registerListener(
                sensorListener,
                accelSensor,
                AndroidSensorManager.SENSOR_DELAY_GAME
            )
            Log.i(TAG, "加速度计已注册 (${accelSensor.name}, ${accelSensor.vendor})")
        } else {
            Log.w(TAG, "设备没有加速度计！")
        }

        if (gyroSensor != null) {
            sensorManager.registerListener(
                sensorListener,
                gyroSensor,
                AndroidSensorManager.SENSOR_DELAY_GAME
            )
            Log.i(TAG, "陀螺仪已注册 (${gyroSensor.name}, ${gyroSensor.vendor})")
        } else {
            Log.w(TAG, "设备没有陀螺仪！")
        }

        isRunning = true
        started.set(true)
    }

    /**
     * 取消注册所有传感器监听器。
     */
    fun stop() {
        if (!isRunning) {
            return
        }
        sensorManager.unregisterListener(sensorListener)
        isRunning = false
        started.set(false)
        Log.i(TAG, "传感器已全部取消注册")
    }

    // ── 状态查询 ─────────────────────────────────────────────────────────────

    fun isAccelAvailable(): Boolean = accelSensor != null
    fun isGyroAvailable(): Boolean = gyroSensor != null
}
