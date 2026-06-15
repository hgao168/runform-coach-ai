package com.runformcoach.runformcoachai

import android.graphics.Bitmap
import android.graphics.Canvas
import android.content.Context
import android.os.Environment
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

/**
 * ViewModel for RF-912 Weekly Training Insight Report.
 *
 * Fetches 4-week trend data from GET /sessions/trends and exposes
 * computed deltas, badges, and AI suggestions to the UI.
 */
@HiltViewModel
class WeeklyInsightViewModel @Inject constructor(
    private val api: RunFormApi,
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    // ── UI State ───────────────────────────────────────────────────────────────

    private val _state = MutableStateFlow<WeeklyInsightState>(WeeklyInsightState.Loading)
    val state: StateFlow<WeeklyInsightState> = _state.asStateFlow()

    // ── Computed deltas (derived from WeeklyTrendsResponse) ────────────────────

    private val _cadenceDelta = MutableStateFlow<MetricDelta?>(null)
    val cadenceDelta: StateFlow<MetricDelta?> = _cadenceDelta.asStateFlow()

    private val _amplitudeDelta = MutableStateFlow<MetricDelta?>(null)
    val amplitudeDelta: StateFlow<MetricDelta?> = _amplitudeDelta.asStateFlow()

    private val _gctDelta = MutableStateFlow<MetricDelta?>(null)
    val gctDelta: StateFlow<MetricDelta?> = _gctDelta.asStateFlow()

    // ── Sharing ────────────────────────────────────────────────────────────────

    private val _shareCardBitmap = MutableStateFlow<Bitmap?>(null)
    val shareCardBitmap: StateFlow<Bitmap?> = _shareCardBitmap.asStateFlow()

    // ── Initial Load ───────────────────────────────────────────────────────────

    init {
        loadTrends()
    }

    // ── Data Loading ───────────────────────────────────────────────────────────

    fun loadTrends() {
        _state.value = WeeklyInsightState.Loading
        viewModelScope.launch {
            try {
                val response = api.fetchWeeklyTrends()
                _state.value = WeeklyInsightState.Success(response)

                // Compute deltas
                val cur = response.currentWeek
                val prev = response.previousWeek
                _cadenceDelta.value = computeDelta(
                    cur.avgCadenceSPM, prev.avgCadenceSPM, "SPM"
                )
                _amplitudeDelta.value = computeDelta(
                    cur.avgAmplitudeCm, prev.avgAmplitudeCm, "cm", invertGood = true
                )
                _gctDelta.value = computeDelta(
                    cur.avgGCTMs, prev.avgGCTMs, "ms", invertGood = true
                )
            } catch (e: Exception) {
                _state.value = WeeklyInsightState.Error(
                    e.message ?: "Failed to load trends"
                )
            }
        }
    }

    // ── Share Card Generation ─────────────────────────────────────────────────

    /**
     * Generates a share card bitmap by drawing into a Canvas.
     * In a real app, this would be done via Compose's `drawToBitmap` or
     * by capturing the share card composable. For now we generate a simple
     * painted bitmap.
     */
    fun generateShareCard() {
        viewModelScope.launch(Dispatchers.Default) {
            try {
                val data = (_state.value as? WeeklyInsightState.Success)?.data ?: return@launch
                val bitmap = withContext(Dispatchers.Main) {
                    renderShareCard(data)
                }
                _shareCardBitmap.value = bitmap
            } catch (e: Exception) {
                // silently fail; user can retry
            }
        }
    }

    private fun renderShareCard(data: WeeklyTrendsResponse): Bitmap {
        val width = 1080
        val height = 1080
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Background
        val bgPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#050A17")
            style = android.graphics.Paint.Style.FILL
        }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)

        // Accent bar
        val accentPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#40F5C2")
            style = android.graphics.Paint.Style.FILL
        }
        canvas.drawRect(0f, 0f, width.toFloat(), 6f, accentPaint)

        // Title
        val titlePaint = android.graphics.Paint().apply {
            color = android.graphics.Color.WHITE
            textSize = 56f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            isAntiAlias = true
        }
        canvas.drawText("My RunForm Weekly", 60f, 100f, titlePaint)
        canvas.drawText("Training Insights", 60f, 165f, titlePaint)

        // Week labels
        val subtitlePaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#A0FFFFFF")
            textSize = 30f
            isAntiAlias = true
        }
        canvas.drawText(
            "${data.currentWeek.weekLabel} vs ${data.previousWeek.weekLabel}",
            60f, 230f, subtitlePaint
        )

        // Metrics section
        var yPos = 320f
        val metricPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.WHITE
            textSize = 34f
            isAntiAlias = true
        }
        val deltaGoodPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#40F5C2")
            textSize = 34f
            isAntiAlias = true
        }
        val deltaBadPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#FF5252")
            textSize = 34f
            isAntiAlias = true
        }
        val labelPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#60FFFFFF")
            textSize = 24f
            isAntiAlias = true
        }

        fun drawMetric(label: String, current: Double, previous: Double, unit: String, invertGood: Boolean) {
            val d = computeDelta(current, previous, unit, invertGood)
            canvas.drawText(label, 60f, yPos, labelPaint)
            yPos += 36f
            val deltaStr = when (d.direction) {
                TrendDirection.UP -> "▲ ${String.format("%.1f", d.delta)} $unit"
                TrendDirection.DOWN -> "▼ ${String.format("%.1f", d.delta)} $unit"
                TrendDirection.FLAT -> "— ${String.format("%.1f", d.delta)} $unit"
            }
            val deltaPaint = if (d.direction == TrendDirection.UP) deltaGoodPaint else deltaBadPaint
            canvas.drawText(
                "${String.format("%.1f", current)} $unit → $deltaStr  (${String.format("%.1f", d.deltaPct)}%)",
                60f, yPos, if (d.direction == TrendDirection.FLAT) subtitlePaint else deltaPaint
            )
            yPos += 50f
        }

        drawMetric("Cadence", data.currentWeek.avgCadenceSPM, data.previousWeek.avgCadenceSPM, "SPM", false)
        drawMetric("Vert. Osc.", data.currentWeek.avgAmplitudeCm, data.previousWeek.avgAmplitudeCm, "cm", true)
        drawMetric("GCT", data.currentWeek.avgGCTMs, data.previousWeek.avgGCTMs, "ms", true)

        // Badges
        if (data.badges.isNotEmpty()) {
            yPos += 20f
            canvas.drawText("Badges Earned", 60f, yPos, labelPaint)
            yPos += 40f
            data.badges.forEach { badge ->
                canvas.drawText("🏅 ${badge.badgeName}", 60f, yPos, metricPaint)
                yPos += 40f
            }
        }

        // Footer
        val footerPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#40FFFFFF")
            textSize = 22f
            isAntiAlias = true
        }
        canvas.drawText("RunForm Coach AI", 60f, height - 80f, footerPaint)
        canvas.drawText(
            "Generated ${SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(Date())}",
            60f, height - 50f, footerPaint
        )

        return bitmap
    }

    /**
     * Save share card bitmap to Pictures directory.
     * Returns the File path on success, null on failure.
     */
    fun saveShareCardToDisk(bitmap: Bitmap): String? {
        return try {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val file = File(dir, "runform_weekly_${System.currentTimeMillis()}.png")
            FileOutputStream(file).use { fos ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 90, fos)
            }
            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    // ── Reset ──────────────────────────────────────────────────────────────────

    fun clearShareCard() {
        _shareCardBitmap.value = null
    }
}
