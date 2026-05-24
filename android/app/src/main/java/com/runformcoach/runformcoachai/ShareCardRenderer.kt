package com.runformcoach.runformcoachai

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.media.MediaScannerConnection
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * RF-1001: Share Card Renderer
 *
 * Renders standalone share card images using android.graphics.Canvas → Bitmap → save to gallery.
 * Three card types: analysis result, history record, training plan.
 *
 * Usage (e.g. from AnalysisResultScreen):
 * ```
 * val bitmap = ShareCardRenderer.renderAnalysisCard(context, result)
 * val uri = ShareCardRenderer.saveToGallery(context, bitmap, "runform_analysis")
 * // then share uri via Intent
 * ```
 */
object ShareCardRenderer {

    // ── Card dimensions (3:4 aspect ratio, generous size for social sharing) ──────
    const val CARD_WIDTH = 1080
    const val CARD_HEIGHT = 1440

    // ── Palette ──────────────────────────────────────────────────────────────────
    private val BG_START = android.graphics.Color.parseColor("#050A17")   // Midnight
    private val BG_END = android.graphics.Color.parseColor("#08172B")     // Navy
    private val MINT = android.graphics.Color.parseColor("#40F5C2")
    private val CYAN = android.graphics.Color.parseColor("#1AABFF")
    private val ORANGE = android.graphics.Color.parseColor("#FF9E38")
    private val VIOLET = android.graphics.Color.parseColor("#7866FF")
    private val RED = android.graphics.Color.parseColor("#FF5252")
    private val TEXT_PRIMARY = android.graphics.Color.WHITE
    private val TEXT_SECONDARY = android.graphics.Color.parseColor("#A0FFFFFF")
    private val TEXT_MUTED = android.graphics.Color.parseColor("#60FFFFFF")
    private val CARD_SURFACE = android.graphics.Color.parseColor("#18FFFFFF")
    private val CARD_BORDER = android.graphics.Color.parseColor("#20FFFFFF")
    private val DIVIDER = android.graphics.Color.parseColor("#15FFFFFF")

    // ── Standard paddings ───────────────────────────────────────────────────────
    private const val PAD_H = 64f
    private const val PAD_V = 56f

    // ══════════════════════════════════════════════════════════════════════════════
    // ── Public API ───────────────────────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * Render an analysis result share card.
     *
     * @param context     Android context (for locale-aware date strings).
     * @param result      The [AnalysisResponse] to render.
     * @param dateLabel   Optional date string (e.g. from history item).
     * @return            [Bitmap] of the card (1080×1440).
     */
    fun renderAnalysisCard(
        context: Context,
        result: AnalysisResponse,
        dateLabel: String? = null
    ): Bitmap {
        val bmp = Bitmap.createBitmap(CARD_WIDTH, CARD_HEIGHT, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        drawBackground(c)

        var y = PAD_V

        // ── Header: RunForm Logo + timestamp ──
        y = drawHeader(c, context, dateLabel, y)

        // ── Divider ──
        y = drawDivider(c, y, 16f, 24f)

        // ── Title: "Analysis Result" ──
        y = drawSectionTitle(c, context.getString(R.string.share_card_analysis_title), y)

        // ── Overall Score Ring ──
        val scorePct = (result.confidence * 100).toInt()
        y = drawScoreRing(c, context.getString(R.string.overall_score), scorePct, y)

        // ── Key metric rings row (Cadence / Amplitude / GCT) ──
        y = drawMetricRings(c, result, y)

        // ── Key Findings ──
        if (result.issues.isNotEmpty()) {
            y = drawDivider(c, y, 12f, 20f)
            y = drawSectionTitle(c, context.getString(R.string.share_card_key_findings), y)
            y = drawFindings(c, result, y)
        }

        // ── Footer ──
        drawFooter(c)

        return bmp
    }

    /**
     * Render a history record share card.
     *
     * @param context        Android context.
     * @param item           The [AnalysisHistoryItem] to render.
     * @param trendData      Optional trend data points for mini chart (null = skip chart).
     * @return               [Bitmap] of the card (1080×1440).
     */
    fun renderHistoryCard(
        context: Context,
        item: AnalysisHistoryItem,
        trendData: List<Float>? = null    // normalized scores 0..1
    ): Bitmap {
        val bmp = Bitmap.createBitmap(CARD_WIDTH, CARD_HEIGHT, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        drawBackground(c)

        var y = PAD_V

        // ── Header ──
        val dateStr = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
            .format(Date(item.createdAt))
        y = drawHeader(c, context, dateStr, y)

        // ── Divider ──
        y = drawDivider(c, y, 16f, 24f)

        // ── Title: "History" ──
        y = drawSectionTitle(c, context.getString(R.string.share_card_history_title), y)

        // ── Date + Score ──
        val scorePct = (item.result.confidence * 100).toInt()
        y = drawScoreRing(c, dateStr, scorePct, y)

        // ── Summary text ──
        y = drawBodyText(c, item.result.summary, y)

        // ── Trend mini chart (if data available) ──
        if (trendData != null && trendData.size >= 2) {
            y = drawDivider(c, y, 12f, 16f)
            y = drawSectionTitle(c, context.getString(R.string.trends), y)
            y = drawMiniTrendChart(c, trendData, y)
        }

        // ── Footer ──
        drawFooter(c)

        return bmp
    }

    /**
     * Render a training plan share card.
     *
     * @param context  Android context.
     * @param plan     The [TrainingPlanResponse] to render.
     * @param planType Label for the plan type (e.g. "Weekly Plan", "Marathon Plan").
     * @return         [Bitmap] of the card (1080×1440).
     */
    fun renderPlanCard(
        context: Context,
        plan: TrainingPlanResponse,
        planType: String
    ): Bitmap {
        val bmp = Bitmap.createBitmap(CARD_WIDTH, CARD_HEIGHT, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        drawBackground(c)

        var y = PAD_V

        // ── Header ──
        y = drawHeader(c, context, null, y)

        // ── Divider ──
        y = drawDivider(c, y, 16f, 24f)

        // ── Title: Plan type ──
        y = drawSectionTitle(c, planType, y)

        // ── Weekly km badge ──
        val kmStr = context.getString(R.string.share_card_weekly_km, plan.plannedWeeklyKm.toInt())
        val daysStr = context.getString(R.string.share_card_run_days, plan.runningDays)

        y = drawPlanStats(c, kmStr, daysStr, y)

        // ── Summary ──
        y = drawBodyText(c, plan.summary, y)

        // ── Key workouts ──
        if (plan.workouts.isNotEmpty()) {
            y = drawDivider(c, y, 12f, 16f)
            y = drawSectionTitle(c, context.getString(R.string.share_card_key_workouts), y)
            y = drawWorkouts(c, plan, y)
        }

        // ── Footer ──
        drawFooter(c)

        return bmp
    }

    /**
     * Save a bitmap to the device gallery via MediaStore (Android 10+) or
     * MediaScannerConnection (legacy).
     *
     * @return The content [Uri] of the saved image, or null on failure.
     */
    fun saveToGallery(context: Context, bitmap: Bitmap, filenamePrefix: String): Uri? {
        return try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val filename = "${filenamePrefix}_$timestamp.png"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ : use MediaStore
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/RunForm")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val uri = context.contentResolver.insert(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values
                )
                uri?.let {
                    context.contentResolver.openOutputStream(it)?.use { out ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    }
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    context.contentResolver.update(it, values, null, null)
                }
                uri
            } else {
                // Legacy: save to file and scan
                val dir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                    "RunForm"
                )
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, filename)
                FileOutputStream(file).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                }
                MediaScannerConnection.scanFile(
                    context,
                    arrayOf(file.absolutePath),
                    arrayOf("image/png"),
                    null
                )
                Uri.fromFile(file)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ── Shared Drawing Helpers ──────────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════════════════

    private fun drawBackground(c: Canvas) {
        // Gradient from top (Midnight) to bottom (Navy)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val gradient = android.graphics.LinearGradient(
            0f, 0f, 0f, CARD_HEIGHT.toFloat(),
            BG_START, BG_END,
            android.graphics.Shader.TileMode.CLAMP
        )
        paint.shader = gradient
        c.drawRect(0f, 0f, CARD_WIDTH.toFloat(), CARD_HEIGHT.toFloat(), paint)
    }

    /**
     * Draw the RunForm header: logo text + optional subtitle (date).
     * @return new y position after header.
     */
    private fun drawHeader(c: Canvas, context: Context, subtitle: String?, topY: Float): Float {
        var y = topY

        // RunForm wordmark: bold "RUNFORM" with mint accent dot
        val logoPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_PRIMARY
            textSize = 42f
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.04f
        }
        val logoMsr = Rect()
        logoPaint.getTextBounds("RUNFORM", 0, 7, logoMsr)
        val logoH = logoMsr.height().toFloat()
        val logoW = logoPaint.measureText("RUNFORM")

        // Centered
        val logoX = (CARD_WIDTH - logoW) / 2f
        c.drawText("RUNFORM", logoX, y + logoH, logoPaint)

        // Mint dot after "RUNFORM"
        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = MINT }
        c.drawCircle(logoX + logoW + 12f, y + logoH / 2f, 5f, dotPaint)

        y += logoH + 4f

        // "Injury Prevention Coach" tagline
        val taglinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = MINT
            textSize = 16f
            letterSpacing = 0.12f
        }
        val tlMsr = Rect()
        taglinePaint.getTextBounds("Injury Prevention Coach", 0, 23, tlMsr)
        c.drawText("Injury Prevention Coach", (CARD_WIDTH - taglinePaint.measureText("Injury Prevention Coach")) / 2f, y + tlMsr.height().toFloat(), taglinePaint)

        y += tlMsr.height().toFloat()

        // Optional subtitle
        if (subtitle != null) {
            y += 16f
            val subPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = TEXT_MUTED
                textSize = 18f
            }
            val subMsr = Rect()
            subPaint.getTextBounds(subtitle, 0, subtitle.length, subMsr)
            c.drawText(subtitle, (CARD_WIDTH - subPaint.measureText(subtitle)) / 2f, y + subMsr.height().toFloat(), subPaint)
            y += subMsr.height().toFloat()
        }

        return y
    }

    private fun drawDivider(c: Canvas, topY: Float, marginTop: Float, marginBottom: Float): Float {
        val y = topY + marginTop
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = DIVIDER
            strokeWidth = 1f
        }
        c.drawLine(PAD_H, y, CARD_WIDTH - PAD_H, y, paint)
        return y + marginBottom
    }

    private fun drawSectionTitle(c: Canvas, title: String, topY: Float): Float {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = MINT
            textSize = 20f
            letterSpacing = 0.08f
            typeface = Typeface.DEFAULT_BOLD
        }
        val msr = Rect()
        paint.getTextBounds(title, 0, title.length, msr)
        val textW = paint.measureText(title)
        c.drawText(title, (CARD_WIDTH - textW) / 2f, topY + msr.height().toFloat(), paint)
        return topY + msr.height().toFloat() + 24f
    }

    private fun drawBodyText(c: Canvas, text: String, topY: Float): Float {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_SECONDARY
            textSize = 22f
        }
        val lineHeight = 34f
        val maxWidth = CARD_WIDTH - PAD_H * 2
        val lines = wrapText(text, paint, maxWidth).take(4)
        var y = topY + 8f
        for (line in lines) {
            val msr = Rect()
            paint.getTextBounds(line, 0, line.length, msr)
            c.drawText(line, (CARD_WIDTH - paint.measureText(line)) / 2f, y + msr.height().toFloat(), paint)
            y += lineHeight
        }
        return y
    }

    // ── Score Ring ──────────────────────────────────────────────────────────────

    private fun drawScoreRing(c: Canvas, label: String, scorePct: Int, topY: Float): Float {
        val centerX = CARD_WIDTH / 2f
        val ringRadius = 100f
        val strokeWidth = 16f
        val ringTop = topY + 24f
        val centerY = ringTop + ringRadius

        val rect = RectF(
            centerX - ringRadius,
            centerY - ringRadius,
            centerX + ringRadius,
            centerY + ringRadius
        )

        // Background ring
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = CARD_BORDER
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth
            strokeCap = Paint.Cap.ROUND
        }
        c.drawArc(rect, -90f, 360f, false, bgPaint)

        // Foreground ring
        val ringColor = when {
            scorePct >= 75 -> MINT
            scorePct >= 50 -> ORANGE
            else -> RED
        }
        val fgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ringColor
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth
            strokeCap = Paint.Cap.ROUND
        }
        val sweep = (360f * scorePct.coerceIn(0, 100) / 100f)
        c.drawArc(rect, -90f, sweep, false, fgPaint)

        // Score text inside ring
        val scorePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_PRIMARY
            textSize = 48f
            typeface = Typeface.DEFAULT_BOLD
        }
        val scoreText = "$scorePct%"
        val scoreMsr = Rect()
        scorePaint.getTextBounds(scoreText, 0, scoreText.length, scoreMsr)
        c.drawText(
            scoreText,
            centerX - scorePaint.measureText(scoreText) / 2f,
            centerY + scoreMsr.height() / 2f,
            scorePaint
        )

        // Label below ring
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_MUTED
            textSize = 18f
        }
        val labelMsr = Rect()
        labelPaint.getTextBounds(label, 0, label.length, labelMsr)
        c.drawText(
            label,
            centerX - labelPaint.measureText(label) / 2f,
            centerY + ringRadius + 28f,
            labelPaint
        )

        return centerY + ringRadius + 48f
    }

    // ── Metric Rings (Cadence / Amplitude / GCT) ────────────────────────────────

    private fun drawMetricRings(c: Canvas, result: AnalysisResponse, topY: Float): Float {
        val metricNames = listOf("Cadence", "Amplitude", "GCT")
        val metricColors = listOf(CYAN, MINT, ORANGE)
        val metrics = result.metrics

        val ringRadius = 72f
        val strokeWidth = 12f
        val spacing = 40f
        val totalW = ringRadius * 2 * 3 + spacing * 2
        val startX = (CARD_WIDTH - totalW) / 2f + ringRadius

        var y = topY + 16f

        for (i in 0 until 3) {
            val cx = startX + i * (ringRadius * 2 + spacing)
            val cy = y + ringRadius

            val metric = metrics.getOrNull(i)
            val scorePct = ((metric?.score ?: 0.0) * 100).toInt()
            val name = if (metric != null) metricNameLabel(metric.name, metricNames[i]) else metricNames[i]

            val rect = RectF(cx - ringRadius, cy - ringRadius, cx + ringRadius, cy + ringRadius)

            // Background
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = CARD_BORDER
                style = Paint.Style.STROKE
                this.strokeWidth = strokeWidth
                strokeCap = Paint.Cap.ROUND
            }
            c.drawArc(rect, -90f, 360f, false, bgPaint)

            // Foreground
            val fgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = metricColors[i]
                style = Paint.Style.STROKE
                this.strokeWidth = strokeWidth
                strokeCap = Paint.Cap.ROUND
            }
            c.drawArc(rect, -90f, (360f * scorePct.coerceIn(0, 100) / 100f), false, fgPaint)

            // Score
            val scPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = metricColors[i]
                textSize = 28f
                typeface = Typeface.DEFAULT_BOLD
            }
            val scText = "$scorePct%"
            val scMsr = Rect()
            scPaint.getTextBounds(scText, 0, scText.length, scMsr)
            c.drawText(scText, cx - scPaint.measureText(scText) / 2f, cy + scMsr.height() / 2f, scPaint)

            // Label
            val lbPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = TEXT_MUTED
                textSize = 16f
            }
            val lbMsr = Rect()
            lbPaint.getTextBounds(name, 0, name.length, lbMsr)
            c.drawText(name, cx - lbPaint.measureText(name) / 2f, cy + ringRadius + 26f, lbPaint)

        }

        return y + ringRadius * 2 + 46f
    }

    private fun metricNameLabel(apiName: String, fallback: String): String = when {
        apiName.contains("cadence", ignoreCase = true) -> "Cadence"
        apiName.contains("amplitude", ignoreCase = true) || apiName.contains("oscillation", ignoreCase = true) -> "Amplitude"
        apiName.contains("ground", ignoreCase = true) || apiName.contains("gct", ignoreCase = true) -> "GCT"
        else -> apiName.take(12)
    }

    // ── Key Findings ────────────────────────────────────────────────────────────

    private fun drawFindings(c: Canvas, result: AnalysisResponse, topY: Float): Float {
        var y = topY
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_SECONDARY
            textSize = 20f
        }
        val maxW = CARD_WIDTH - PAD_H * 2
        val lineH = 36f

        for (issue in result.issues.take(3)) {
            val text = "• ${issue.title}"
            val lines = wrapText(text, titlePaint, maxW)
            for (line in lines) {
                val msr = Rect()
                titlePaint.getTextBounds(line, 0, line.length, msr)
                c.drawText(line, PAD_H, y + msr.height().toFloat(), titlePaint)
                y += lineH
            }
        }
        return y + 8f
    }

    // ── Plan Stats ──────────────────────────────────────────────────────────────

    private fun drawPlanStats(c: Canvas, kmText: String, daysText: String, topY: Float): Float {
        var y = topY + 16f
        val cardW = (CARD_WIDTH - PAD_H * 2 - 24f) / 2f
        val cardH = 100f
        val corner = 24f

        // Left card: Weekly km
        val leftX = PAD_H
        val rightX = PAD_H + cardW + 24f

        drawStatCard(c, leftX, y, cardW, cardH, corner, kmText, MINT)
        drawStatCard(c, rightX, y, cardW, cardH, corner, daysText, CYAN)

        return y + cardH + 32f
    }

    private fun drawStatCard(
        c: Canvas, x: Float, y: Float, w: Float, h: Float,
        corner: Float, text: String, accentColor: Int
    ) {
        val rect = RectF(x, y, x + w, y + h)
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = CARD_SURFACE
        }
        c.drawRoundRect(rect, corner, corner, bgPaint)

        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = CARD_BORDER
            style = Paint.Style.STROKE
            strokeWidth = 1f
        }
        c.drawRoundRect(rect, corner, corner, borderPaint)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accentColor
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
        }
        val msr = Rect()
        textPaint.getTextBounds(text, 0, text.length, msr)
        c.drawText(
            text,
            x + (w - textPaint.measureText(text)) / 2f,
            y + h / 2f + msr.height() / 2f,
            textPaint
        )
    }

    // ── Key Workouts ────────────────────────────────────────────────────────────

    private fun drawWorkouts(c: Canvas, plan: TrainingPlanResponse, topY: Float): Float {
        var y = topY
        val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_PRIMARY
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
        }
        val detailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_SECONDARY
            textSize = 18f
        }
        val maxW = CARD_WIDTH - PAD_H * 2

        for (workout in plan.workouts.take(5)) {
            // Day + Title in one line
            val dayName = dayLabel(workout.day)
            val line1 = "$dayName  ${workout.title}"
            val lines1 = wrapText(line1, namePaint, maxW)
            for (ln in lines1) {
                val msr = Rect()
                namePaint.getTextBounds(ln, 0, ln.length, msr)
                c.drawText(ln, PAD_H, y + msr.height().toFloat(), namePaint)
                y += 32f
            }

            // Category + intensity tag
            val catStr = "${workout.category} · ${workout.intensity}"
            val msr2 = Rect()
            detailPaint.getTextBounds(catStr, 0, catStr.length, msr2)
            c.drawText(catStr, PAD_H + 16f, y + msr2.height().toFloat(), detailPaint)
            y += 28f

            // Distance / Duration if present
            val extras = mutableListOf<String>()
            workout.distanceKm?.let { extras.add("${it} km") }
            workout.durationMinutes?.let { extras.add("${it} min") }
            if (extras.isNotEmpty()) {
                val extraStr = extras.joinToString("  ·  ")
                val msr3 = Rect()
                detailPaint.getTextBounds(extraStr, 0, extraStr.length, msr3)
                c.drawText(extraStr, PAD_H + 16f, y + msr3.height().toFloat(), detailPaint)
                y += 28f
            }
            y += 8f
        }

        return y
    }

    // ── Mini Trend Chart ────────────────────────────────────────────────────────

    private fun drawMiniTrendChart(c: Canvas, data: List<Float>, topY: Float): Float {
        val chartW = CARD_WIDTH - PAD_H * 2
        val chartH = 120f
        val chartTop = topY + 12f
        val chartBottom = chartTop + chartH

        // Card background
        val cardRect = RectF(PAD_H, chartTop, CARD_WIDTH - PAD_H, chartBottom)
        val cardPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CARD_SURFACE }
        c.drawRoundRect(cardRect, 20f, 20f, cardPaint)

        // Line chart
        val stepX = chartW / (data.size - 1).coerceAtLeast(1)
        val linePath = Path()
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = MINT
            style = Paint.Style.STROKE
            strokeWidth = 4f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        data.forEachIndexed { i, value ->
            val x = PAD_H + stepX * i
            val y = chartBottom - (value.coerceIn(0f, 1f) * (chartH - 20f)) - 10f
            if (i == 0) linePath.moveTo(x, y) else linePath.lineTo(x, y)
        }
        c.drawPath(linePath, linePaint)

        // Fill under line
        val fillPath = Path(linePath)
        fillPath.lineTo(PAD_H + stepX * (data.size - 1), chartBottom)
        fillPath.lineTo(PAD_H, chartBottom)
        fillPath.close()

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = MINT
            alpha = 30
            style = Paint.Style.FILL
        }
        c.drawPath(fillPath, fillPaint)

        return chartBottom + 24f
    }

    // ── Footer ──────────────────────────────────────────────────────────────────

    private fun drawFooter(c: Canvas) {
        // Divider line
        val divY = CARD_HEIGHT - 100f
        val divPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = DIVIDER
            strokeWidth = 1f
        }
        c.drawLine(PAD_H, divY, CARD_WIDTH - PAD_H, divY, divPaint)

        // Footer text
        val footerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TEXT_MUTED
            textSize = 18f
        }
        val footerText = "Generated by RunForm Injury Prevention Coach  ·  runform.coach"
        val msr = Rect()
        footerPaint.getTextBounds(footerText, 0, footerText.length, msr)
        c.drawText(footerText, (CARD_WIDTH - footerPaint.measureText(footerText)) / 2f, divY + 44f, footerPaint)
    }

    // ── Utilities ───────────────────────────────────────────────────────────────

    /** Simple text wrapping by word. */
    private fun wrapText(text: String, paint: Paint, maxWidth: Float): List<String> {
        val words = text.split(' ')
        val lines = mutableListOf<String>()
        var currentLine = StringBuilder()
        for (word in words) {
            val testLine = if (currentLine.isEmpty()) word else "$currentLine $word"
            if (paint.measureText(testLine) <= maxWidth) {
                if (currentLine.isNotEmpty()) currentLine.append(' ')
                currentLine.append(word)
            } else {
                if (currentLine.isNotEmpty()) {
                    lines.add(currentLine.toString())
                }
                currentLine = StringBuilder(word)
            }
        }
        if (currentLine.isNotEmpty()) lines.add(currentLine.toString())
        return lines.ifEmpty { listOf(text) }
    }

    private fun dayLabel(day: String): String = when (day.lowercase().take(3)) {
        "mon" -> "Mon"
        "tue" -> "Tue"
        "wed" -> "Wed"
        "thu" -> "Thu"
        "fri" -> "Fri"
        "sat" -> "Sat"
        "sun" -> "Sun"
        else -> day
    }
}
