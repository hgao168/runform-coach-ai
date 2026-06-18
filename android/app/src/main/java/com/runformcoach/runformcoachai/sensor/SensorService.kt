package com.runformcoach.runformcoachai.sensor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.runformcoach.runformcoachai.MainActivity
import com.runformcoach.runformcoachai.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch

/**
 * 前台服务骨架 —— 在 App 退到后台时保持传感器采集存活。
 *
 * - 创建通知渠道 "RunForm Running"
 * - 启动时开启传感器采集，将数据推入 [RingBuffer]
 * - 销毁时停止传感器、释放协程
 *
 * 在 AndroidManifest.xml 中需声明：
 * ```
 * <service
 *     android:name=".sensor.SensorService"
 *     android:foregroundServiceType="dataSync"
 *     android:exported="false" />
 * ```
 */
class SensorService : Service() {

    companion object {
        private const val TAG = "SensorService"
        const val CHANNEL_ID = "runform_running"
        const val CHANNEL_NAME = "RunForm Running"
        const val NOTIFICATION_ID = 1001

        /** 启动服务。 */
        fun start(context: Context) {
            val intent = Intent(context, SensorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** 停止服务。 */
        fun stop(context: Context) {
            context.stopService(Intent(context, SensorService::class.java))
        }
    }

    // ── 核心依赖 ─────────────────────────────────────────────────────────────

    private lateinit var sensorCaptureManager: SensorCaptureManager
    val ringBuffer = RingBuffer<SensorFrame>(capacity = 300)

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var collectJob: Job? = null

    // ── 生命周期 ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")

        createNotificationChannel()
        sensorCaptureManager = SensorCaptureManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand flags=$flags startId=$startId")

        startForeground(NOTIFICATION_ID, buildNotification())

        sensorCaptureManager.start()

        // 将传感器数据持续推入环形缓冲区
        collectJob = serviceScope.launch {
            sensorCaptureManager.sensorFrames()
                .catch { e -> Log.e(TAG, "传感器 Flow 异常", e) }
                .collect { frame ->
                    ringBuffer.add(frame)
                }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        collectJob?.cancel()
        sensorCaptureManager.stop()
        serviceScope.cancel()
        ringBuffer.clear()
        super.onDestroy()
    }

    // ── 通知 ─────────────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW  // 低优先级，不发出声音
            ).apply {
                description = "RunForm 跑步姿态分析后台采集通知"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RunForm Injury Prevention Coach")
            .setContentText("正在采集跑步姿态数据…")
            .setSmallIcon(android.R.drawable.ic_menu_compass)  // 占位图标
            .setContentIntent(pendingIntent)
            .setOngoing(true)               // 不可滑动删除
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
}
