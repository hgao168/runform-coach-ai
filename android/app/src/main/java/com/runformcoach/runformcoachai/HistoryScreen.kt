package com.runformcoach.runformcoachai

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToInt

@Composable
fun HistoryScreen(vm: AppViewModel) {
    var showClearDialog by remember { mutableStateOf(false) }
    var expandedId by remember { mutableStateOf<String?>(null) }
    var trendExpanded by remember { mutableStateOf(true) }

    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            title = { Text("Clear History", color = Color.White) },
            text = { Text("Delete all analysis records?", color = AppColors.TextSecondary) },
            confirmButton = {
                TextButton(onClick = {
                    vm.clearHistory()
                    showClearDialog = false
                }) { Text("Delete All", color = AppColors.Red) }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) { Text("Cancel", color = AppColors.TextSecondary) }
            },
            containerColor = AppColors.Ink,
            titleContentColor = Color.White
        )
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("History", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text("${vm.history.size} analyses", color = AppColors.TextSecondary, fontSize = 13.sp)
            }
            if (vm.history.isNotEmpty()) {
                IconButton(onClick = { showClearDialog = true }) {
                    Icon(Icons.Default.Delete, contentDescription = "Clear", tint = AppColors.Red)
                }
            }
        }

        if (vm.history.isEmpty()) {
            // Empty state
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.History,
                        contentDescription = null,
                        tint = AppColors.TextMuted,
                        modifier = Modifier.size(64.dp)
                    )
                    Text(
                        stringResource(R.string.no_analyses_yet),
                        color = AppColors.TextSecondary,
                        fontSize = 17.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        stringResource(R.string.go_to_analyze),
                        color = AppColors.TextMuted,
                        fontSize = 14.sp
                    )
                }
            }
        } else {
            // ── Trend chart section ────────────────────────────────────────
            TrendChartSection(
                history = vm.history,
                expanded = trendExpanded,
                onToggle = { trendExpanded = !trendExpanded }
            )

            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(vm.history, key = { it.id }) { item ->
                    HistoryItemCard(
                        item = item,
                        expanded = expandedId == item.id,
                        onClick = {
                            expandedId = if (expandedId == item.id) null else item.id
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun HistoryItemCard(
    item: AnalysisHistoryItem,
    expanded: Boolean,
    onClick: () -> Unit
) {
    val context = LocalContext.current
    val dateStr = remember(item.createdAt) {
        SimpleDateFormat("MMM d, yyyy  HH:mm", Locale.getDefault())
            .format(Date(item.createdAt))
    }
    val confidencePct = (item.result.confidence * 100).toInt()
    val ringColor = when {
        confidencePct >= 75 -> AppColors.Mint
        confidencePct >= 50 -> AppColors.Orange
        else -> AppColors.Red
    }

    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(dateStr, color = AppColors.TextSecondary, fontSize = 12.sp)
                    Text(item.result.summary, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, lineHeight = 18.sp)
                }
                Spacer(Modifier.width(12.dp))
                // Confidence badge
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(ringColor.copy(alpha = 0.2f))
                        .border(1.dp, ringColor.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Text("$confidencePct%", color = ringColor, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                }
            }

            // Issue pills + share card button row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (item.result.issues.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.weight(1f)) {
                        item.result.issues.take(3).forEach { issue ->
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(AppColors.Orange.copy(alpha = 0.15f))
                                    .padding(horizontal = 8.dp, vertical = 3.dp)
                            ) {
                                Text(issue.title, color = AppColors.Orange, fontSize = 11.sp)
                            }
                        }
                        if (item.result.issues.size > 3) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(AppColors.Card)
                                    .padding(horizontal = 8.dp, vertical = 3.dp)
                            ) {
                                Text("+${item.result.issues.size - 3} more", color = AppColors.TextMuted, fontSize = 11.sp)
                            }
                        }
                    }
                } else {
                    Spacer(Modifier.weight(1f))
                }
                // RF-1001: Share as image card
                IconButton(onClick = {
                    Toast.makeText(context, context.getString(R.string.share_card_saving), Toast.LENGTH_SHORT).show()
                    CoroutineScope(Dispatchers.IO).launch {
                        val bitmap = ShareCardRenderer.renderHistoryCard(context, item)
                        val uri = ShareCardRenderer.saveToGallery(context, bitmap, "runform_history")
                        bitmap.recycle()
                        CoroutineScope(Dispatchers.Main).launch {
                            if (uri != null) {
                                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "image/png"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                Toast.makeText(context, context.getString(R.string.share_card_saved), Toast.LENGTH_SHORT).show()
                                context.startActivity(Intent.createChooser(shareIntent, context.getString(R.string.share)))
                            } else {
                                Toast.makeText(context, context.getString(R.string.share_card_failed), Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                }) {
                    Icon(
                        imageVector = Icons.Default.Image,
                        contentDescription = stringResource(R.string.share_card),
                        tint = AppColors.Cyan,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            // Expanded result
            if (expanded) {
                AnalysisResultScreen(result = item.result)
            }
        }
    }
}

// ── Trend Chart ─────────────────────────────────────────────────────────────

private data class TrendPoint(
    val timestamp: Long,
    val dateLabel: String,
    val cadence: Double?,
    val verticalOscillation: Double?,
    val groundContactTime: Double?
)

private data class TrendTooltipData(
    val point: TrendPoint,
    val metricName: String,
    val value: Double,
    val x: Float,
    val y: Float
)

@Composable
private fun TrendChartSection(
    history: List<AnalysisHistoryItem>,
    expanded: Boolean,
    onToggle: () -> Unit
) {
    val trendData = remember(history) { extractTrendData(history) }
    var tooltip by remember { mutableStateOf<TrendTooltipData?>(null) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        // Header row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onToggle)
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                stringResource(R.string.trends),
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            Icon(
                imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                contentDescription = if (expanded) "Collapse" else "Expand",
                tint = AppColors.TextSecondary
            )
        }

        if (expanded) {
            Spacer(Modifier.height(8.dp))

            if (trendData.size < 2) {
                // Not enough data for trends
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            stringResource(R.string.no_trend_data),
                            color = AppColors.TextSecondary,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            stringResource(R.string.need_more_analyses),
                            color = AppColors.TextMuted,
                            fontSize = 12.sp
                        )
                    }
                }
            } else {
                // Trend chart card
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column {
                        // Legend row
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            TrendLegendDot(
                                color = AppColors.Cyan,
                                label = stringResource(R.string.cadence)
                            )
                            TrendLegendDot(
                                color = AppColors.Mint,
                                label = stringResource(R.string.vertical_oscillation)
                            )
                            TrendLegendDot(
                                color = AppColors.Orange,
                                label = stringResource(R.string.ground_contact_time)
                            )
                        }
                        Spacer(Modifier.height(12.dp))

                        // Canvas chart with tooltip overlay
                        Box(modifier = Modifier.fillMaxWidth().height(200.dp)) {
                            TrendCanvasChart(
                                data = trendData,
                                onTap = { point, metricName, value, x, y ->
                                    tooltip = if (tooltip?.point == point &&
                                        tooltip?.metricName == metricName
                                    ) {
                                        null // toggle off
                                    } else {
                                        TrendTooltipData(
                                            point, metricName, value, x, y
                                        )
                                    }
                                }
                            )

                            // Tooltip overlay
                            tooltip?.let { tip ->
                                TrendTooltip(
                                    tooltip = tip,
                                    onDismiss = { tooltip = null }
                                )
                            }
                        }

                        // Tap hint
                        Text(
                            stringResource(R.string.tap_for_detail),
                            color = AppColors.TextMuted,
                            fontSize = 10.sp,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 6.dp),
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TrendLegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(color)
        )
        Spacer(Modifier.width(4.dp))
        Text(label, color = AppColors.TextSecondary, fontSize = 11.sp)
    }
}

@Composable
private fun TrendTooltip(
    tooltip: TrendTooltipData,
    onDismiss: () -> Unit
) {
    val metricColor = when (tooltip.metricName) {
        "Cadence" -> AppColors.Cyan
        "Vertical Osc." -> AppColors.Mint
        "GCT" -> AppColors.Orange
        else -> Color.White
    }

    val pct = (tooltip.value * 100).roundToInt()

    Box(
        modifier = Modifier
            .offset { IntOffset(tooltip.x.roundToInt() - 60, tooltip.y.roundToInt() - 70) }
            .clip(RoundedCornerShape(8.dp))
            .background(AppColors.Ink)
            .border(1.dp, metricColor.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp)
    ) {
        Column {
            Text(
                tooltip.metricName,
                color = metricColor,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                "$pct%",
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                tooltip.point.dateLabel,
                color = AppColors.TextMuted,
                fontSize = 10.sp
            )
        }
    }
}

@Composable
private fun TrendCanvasChart(
    data: List<TrendPoint>,
    onTap: (TrendPoint, String, Double, Float, Float) -> Unit
) {
    // Collect non-null values for global range
    val allValues = data.flatMap { listOfNotNull(it.cadence, it.verticalOscillation, it.groundContactTime) }
    val globalMin = if (allValues.isNotEmpty()) allValues.min() else 0.0
    val globalMax = if (allValues.isNotEmpty()) allValues.max() else 1.0
    val range = if (globalMax - globalMin < 0.01) 0.1 else globalMax - globalMin
    val adjustedMin = (globalMin - range * 0.1).coerceAtLeast(0.0)
    val adjustedMax = (globalMax + range * 0.1).coerceAtMost(1.0)
    val adjustedRange = if (adjustedMax - adjustedMin < 0.001) 1.0 else adjustedMax - adjustedMin

    val dateFormat = remember { java.text.SimpleDateFormat("M/d", Locale.getDefault()) }

    Canvas(
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(data) {
                detectTapGestures { tapOffset ->
                    val paddingLeft = 48f
                    val paddingRight = 16f
                    val paddingTop = 12f
                    val paddingBottom = 28f
                    val chartWidth = size.width - paddingLeft - paddingRight
                    val chartHeight =
                        size.height - paddingTop - paddingBottom

                    if (tapOffset.x < paddingLeft || tapOffset.x > size.width - paddingRight ||
                        tapOffset.y < paddingTop || tapOffset.y > size.height - paddingBottom
                    ) return@detectTapGestures

                    val stepX =
                        chartWidth / (data.size - 1).coerceAtLeast(1)
                    val index =
                        ((tapOffset.x - paddingLeft) / stepX).roundToInt()
                            .coerceIn(0, data.size - 1)
                    val point = data[index]

                    // Find closest metric to tap Y
                    val metrics = listOfNotNull(
                        point.cadence?.let {
                            Triple(
                                "Cadence",
                                it,
                                paddingTop + chartHeight * (1 - ((it - adjustedMin) / adjustedRange)).toFloat()
                            )
                        },
                        point.verticalOscillation?.let {
                            Triple(
                                "Vertical Osc.",
                                it,
                                paddingTop + chartHeight * (1 - ((it - adjustedMin) / adjustedRange)).toFloat()
                            )
                        },
                        point.groundContactTime?.let {
                            Triple(
                                "GCT",
                                it,
                                paddingTop + chartHeight * (1 - ((it - adjustedMin) / adjustedRange)).toFloat()
                            )
                        }
                    )
                    val closest =
                        metrics.minByOrNull { abs(it.third - tapOffset.y) }
                            ?: return@detectTapGestures
                    onTap(
                        point,
                        closest.first,
                        closest.second,
                        tapOffset.x,
                        tapOffset.y
                    )
                }
            }
    ) {
        val paddingLeft = 48f
        val paddingRight = 16f
        val paddingTop = 12f
        val paddingBottom = 28f
        val chartWidth = size.width - paddingLeft - paddingRight
        val chartHeight = size.height - paddingTop - paddingBottom

        val stepX =
            chartWidth / (data.size - 1).coerceAtLeast(1)

        // ── Grid lines & Y-axis labels ──
        val gridCount = 4
        for (i in 0..gridCount) {
            val y = paddingTop + chartHeight * i / gridCount
            val labelVal =
                adjustedMax - adjustedRange * i / gridCount

            // Grid line
            drawLine(
                color = Color.White.copy(alpha = 0.08f),
                start = Offset(paddingLeft, y),
                end = Offset(size.width - paddingRight, y),
                strokeWidth = 1f
            )

            // Y label
            val label = "${(labelVal * 100).roundToInt()}%"
            drawContext.canvas.nativeCanvas.drawText(
                label,
                paddingLeft - 8f,
                y + 4f,
                android.graphics.Paint().apply {
                    color = 0x60FFFFFF.toInt()
                    textSize = 22f
                    textAlign = android.graphics.Paint.Align.RIGHT
                    isAntiAlias = true
                }
            )
        }

        // ── Helpers ──
        fun pointX(index: Int): Float =
            paddingLeft + index * stepX

        fun pointY(value: Double): Float =
            paddingTop + chartHeight * (1 - ((value - adjustedMin) / adjustedRange)).toFloat()

        // ── Draw each metric line ──
        fun drawMetricLine(
            values: List<Double?>,
            lineColor: Color
        ) {
            val pts = data.mapIndexedNotNull { i, _ ->
                values[i]?.let { Offset(pointX(i), pointY(it)) }
            }
            if (pts.size < 2) return

            // Fill area under line
            val fillPath = Path().apply {
                moveTo(pts.first().x, paddingTop + chartHeight)
                pts.forEach { lineTo(it.x, it.y) }
                lineTo(pts.last().x, paddingTop + chartHeight)
                close()
            }
            drawPath(fillPath, lineColor.copy(alpha = 0.10f))

            // Stroke line
            val linePath = Path().apply {
                moveTo(pts.first().x, pts.first().y)
                for (i in 1 until pts.size) {
                    lineTo(pts[i].x, pts[i].y)
                }
            }
            drawPath(
                linePath,
                lineColor,
                style = Stroke(
                    width = 2.5f,
                    cap = StrokeCap.Round,
                    join = StrokeJoin.Round
                )
            )

            // Data point dots
            pts.forEach { pt ->
                drawCircle(lineColor, radius = 4f, center = pt)
                drawCircle(
                    Color.White.copy(alpha = 0.6f),
                    radius = 2f,
                    center = pt
                )
            }
        }

        drawMetricLine(data.map { it.cadence }, AppColors.Cyan)
        drawMetricLine(
            data.map { it.verticalOscillation },
            AppColors.Mint
        )
        drawMetricLine(
            data.map { it.groundContactTime },
            AppColors.Orange
        )

        // ── X-axis labels ──
        val labelInterval = when {
            data.size <= 5 -> 1
            data.size <= 10 -> 2
            else -> (data.size / 5).coerceAtLeast(1)
        }
        for (i in data.indices) {
            if (i % labelInterval == 0 || i == data.size - 1) {
                val x = pointX(i)
                drawContext.canvas.nativeCanvas.drawText(
                    data[i].dateLabel,
                    x,
                    size.height - 4f,
                    android.graphics.Paint().apply {
                        color = 0x60FFFFFF.toInt()
                        textSize = 20f
                        textAlign = android.graphics.Paint.Align.CENTER
                        isAntiAlias = true
                    }
                )
            }
        }
    }
}

private fun extractTrendData(history: List<AnalysisHistoryItem>): List<TrendPoint> {
    val dateFormat = java.text.SimpleDateFormat("M/d", Locale.getDefault())
    return history
        .asReversed() // DAO returns newest-first; oldest-first for chart
        .takeLast(20)
        .map { item ->
            TrendPoint(
                timestamp = item.createdAt,
                dateLabel = dateFormat.format(java.util.Date(item.createdAt)),
                cadence = item.result.metrics.find {
                    it.name.contains("cadence", ignoreCase = true)
                }?.score,
                verticalOscillation = item.result.metrics.find {
                    it.name.contains("vertical", ignoreCase = true)
                }?.score,
                groundContactTime = item.result.metrics.find {
                    it.name.contains("ground", ignoreCase = true) ||
                            it.name.contains("gct", ignoreCase = true)
                }?.score
            )
        }
}
