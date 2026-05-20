package com.runformcoach.runformcoachai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.TrendingDown
import androidx.compose.material.icons.filled.TrendingFlat
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import kotlin.math.abs

// ── Weekly Insight Screen (RF-912) ───────────────────────────────────────────

/**
 * Full-screen weekly training insight report.
 *
 * Sections:
 * 1. Header with week labels + refresh/share buttons
 * 2. This Week vs Last Week metric comparison cards (Cadence, Amplitude, GCT)
 * 3. Weekly mileage / sessions summary
 * 4. Achievement badges
 * 5. AI-generated coaching suggestions
 */
@Composable
fun WeeklyInsightScreen(
    vm: WeeklyInsightViewModel = hiltViewModel(),
    onShareClicked: () -> Unit = {}
) {
    val state by vm.state.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Header ─────────────────────────────────────────────────────────────
        WeeklyInsightHeader(
            vm = vm,
            onShareClicked = onShareClicked
        )

        // ── Body ───────────────────────────────────────────────────────────────
        when (val s = state) {
            is WeeklyInsightState.Loading -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(300.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = AppColors.Mint)
                        Spacer(Modifier.height(16.dp))
                        Text(
                            stringResource(R.string.weekly_insights_loading),
                            color = AppColors.TextSecondary,
                            fontSize = 14.sp
                        )
                    }
                }
            }

            is WeeklyInsightState.Error -> {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            stringResource(R.string.weekly_insights_error_title),
                            color = AppColors.Orange,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            s.message,
                            color = AppColors.TextSecondary,
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center
                        )
                        Spacer(Modifier.height(16.dp))
                        // Retry button styled as a text link
                        Text(
                            stringResource(R.string.weekly_insights_retry),
                            color = AppColors.Mint,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.padding(4.dp)
                        )
                    }
                }
            }

            is WeeklyInsightState.Success -> {
                val data = s.data

                // ── 1. This Week vs Last Week comparisons ───────────────────────
                SectionTitle(stringResource(R.string.weekly_insights_week_over_week))

                // Cadence card
                DeltaMetricCard(
                    label = "Cadence",
                    currentValue = data.currentWeek.avgCadenceSPM,
                    previousValue = data.previousWeek.avgCadenceSPM,
                    unit = "SPM",
                    invertGood = false,
                    color = AppColors.Cyan,
                    description = "Higher cadence reduces overstride risk"
                )

                // Amplitude card
                DeltaMetricCard(
                    label = "Vertical Oscillation",
                    currentValue = data.currentWeek.avgAmplitudeCm,
                    previousValue = data.previousWeek.avgAmplitudeCm,
                    unit = "cm",
                    invertGood = true,
                    color = AppColors.Mint,
                    description = "Lower oscillation = more efficient stride"
                )

                // GCT card
                DeltaMetricCard(
                    label = "Ground Contact Time",
                    currentValue = data.currentWeek.avgGCTMs,
                    previousValue = data.previousWeek.avgGCTMs,
                    unit = "ms",
                    invertGood = true,
                    color = AppColors.Violet,
                    description = "Shorter GCT = faster turnover"
                )

                // ── 2. Weekly mileage / session stats ──────────────────────────
                SectionTitle(stringResource(R.string.weekly_insights_stats))
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        StatBadge(
                            label = "Distance",
                            value = String.format("%.1f km", data.currentWeek.totalDistanceKm),
                            color = AppColors.Mint
                        )
                        StatBadge(
                            label = "Sessions",
                            value = "${data.currentWeek.totalSessions}",
                            color = AppColors.Cyan
                        )
                        StatBadge(
                            label = "Duration",
                            value = String.format("%.0f min", data.currentWeek.totalDurationMin),
                            color = AppColors.Violet
                        )
                    }
                }

                // ── 3. Achievement Badges ──────────────────────────────────────
                if (data.badges.isNotEmpty()) {
                    SectionTitle(stringResource(R.string.weekly_insights_badges))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        data.badges.forEach { badge ->
                            BadgeCard(badge)
                        }
                    }
                }

                // ── 4. AI Coaching Suggestion ──────────────────────────────────
                data.aiSuggestion?.let { suggestion ->
                    SectionTitle(stringResource(R.string.weekly_insights_ai_coach))
                    GlassCard(
                        modifier = Modifier.fillMaxWidth(),
                        cornerRadius = 12
                    ) {
                        Row(verticalAlignment = Alignment.Top) {
                            Text(
                                "💡",
                                fontSize = 20.sp,
                                modifier = Modifier.padding(end = 12.dp, top = 2.dp)
                            )
                            Text(
                                suggestion,
                                color = Color.White,
                                fontSize = 14.sp,
                                lineHeight = 21.sp
                            )
                        }
                    }
                }

                // ── 5. Weekly Trend Mini-Bars ──────────────────────────────────
                if (data.weeklyTrends.size >= 2) {
                    SectionTitle(stringResource(R.string.weekly_insights_4week_trends))
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        WeeklyTrendMiniBars(data.weeklyTrends)
                    }
                }

                // Bottom spacer
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

// ── Header ────────────────────────────────────────────────────────────────────

@Composable
private fun WeeklyInsightHeader(
    vm: WeeklyInsightViewModel,
    onShareClicked: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(
                "Weekly Insights",
                color = Color.White,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                "Your training trends at a glance",
                color = AppColors.TextSecondary,
                fontSize = 13.sp
            )
        }
        Row {
            IconButton(onClick = { vm.loadTrends() }) {
                Icon(
                    Icons.Default.Refresh,
                    contentDescription = "Refresh",
                    tint = AppColors.TextSecondary
                )
            }
            IconButton(onClick = {
                vm.generateShareCard()
                onShareClicked()
            }) {
                Icon(
                    Icons.Default.Share,
                    contentDescription = "Share",
                    tint = AppColors.Mint
                )
            }
        }
    }
}

// ── Delta Metric Card ─────────────────────────────────────────────────────────

@Composable
private fun DeltaMetricCard(
    label: String,
    currentValue: Double,
    previousValue: Double,
    unit: String,
    invertGood: Boolean,
    color: Color,
    description: String
) {
    val delta = remember(currentValue, previousValue) {
        computeDelta(currentValue, previousValue, unit, invertGood)
    }

    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column {
            // Header row: label + trend arrow
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    label,
                    color = AppColors.TextSecondary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        when (delta.direction) {
                            TrendDirection.UP -> "Improving"
                            TrendDirection.DOWN -> "Declining"
                            TrendDirection.FLAT -> "Stable"
                        },
                        color = when (delta.direction) {
                            TrendDirection.UP -> AppColors.Green
                            TrendDirection.DOWN -> AppColors.Red
                            TrendDirection.FLAT -> AppColors.TextSecondary
                        },
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium
                    )
                    Spacer(Modifier.width(4.dp))
                    Icon(
                        imageVector = when (delta.direction) {
                            TrendDirection.UP -> Icons.Default.TrendingUp
                            TrendDirection.DOWN -> Icons.Default.TrendingDown
                            TrendDirection.FLAT -> Icons.Default.TrendingFlat
                        },
                        contentDescription = null,
                        tint = when (delta.direction) {
                            TrendDirection.UP -> AppColors.Green
                            TrendDirection.DOWN -> AppColors.Red
                            TrendDirection.FLAT -> AppColors.TextSecondary
                        },
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Main value row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Bottom
            ) {
                Text(
                    String.format("%.1f", currentValue),
                    color = color,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    unit,
                    color = AppColors.TextSecondary,
                    fontSize = 16.sp,
                    modifier = Modifier.padding(bottom = 4.dp)
                )
                Spacer(Modifier.weight(1f))
                // Delta badge
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(
                            when (delta.direction) {
                                TrendDirection.UP -> AppColors.Green.copy(alpha = 0.15f)
                                TrendDirection.DOWN -> AppColors.Red.copy(alpha = 0.15f)
                                TrendDirection.FLAT -> AppColors.TextMuted.copy(alpha = 0.1f)
                            }
                        )
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Text(
                        buildString {
                            append(if (delta.direction == TrendDirection.UP) "+" else "")
                            append(String.format("%.1f", delta.delta))
                            append(" $unit")
                        },
                        color = when (delta.direction) {
                            TrendDirection.UP -> AppColors.Green
                            TrendDirection.DOWN -> AppColors.Red
                            TrendDirection.FLAT -> AppColors.TextSecondary
                        },
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            Spacer(Modifier.height(4.dp))

            // Previous value reference + percentage
            Row {
                Text(
                    "Last week: ${String.format("%.1f", previousValue)} $unit",
                    color = AppColors.TextMuted,
                    fontSize = 11.sp
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "(${String.format("%+.1f", delta.deltaPct)}%)",
                    color = when (delta.direction) {
                        TrendDirection.UP -> AppColors.Green
                        TrendDirection.DOWN -> AppColors.Red
                        TrendDirection.FLAT -> AppColors.TextMuted
                    },
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(Modifier.height(4.dp))

            // Description
            Text(
                description,
                color = AppColors.TextMuted,
                fontSize = 11.sp,
                lineHeight = 15.sp
            )
        }
    }
}

// ── Stat Badge ────────────────────────────────────────────────────────────────

@Composable
private fun StatBadge(
    label: String,
    value: String,
    color: Color
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            value,
            color = color,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(2.dp))
        Text(
            label,
            color = AppColors.TextMuted,
            fontSize = 11.sp
        )
    }
}

// ── Badge Card ────────────────────────────────────────────────────────────────

@Composable
private fun BadgeCard(badge: UserBadge) {
    GlassCard(
        modifier = Modifier.weight(1f),
        cornerRadius = 12
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth()
        ) {
            // Badge icon
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(AppColors.Mint.copy(alpha = 0.15f))
                    .border(1.dp, AppColors.Mint.copy(alpha = 0.3f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    badge.badgeIcon.ifEmpty { "🏅" },
                    fontSize = 22.sp
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                badge.badgeName,
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(4.dp))
            Text(
                badge.badgeDescription,
                color = AppColors.TextMuted,
                fontSize = 10.sp,
                textAlign = TextAlign.Center,
                lineHeight = 14.sp
            )
        }
    }
}

// ── Weekly Trend Mini-Bars ────────────────────────────────────────────────────

@Composable
private fun WeeklyTrendMiniBars(trends: List<WeekSummary>) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        // Cadence trend row
        TrendBarRow(
            title = "Cadence (SPM)",
            values = trends.map { it.avgCadenceSPM },
            color = AppColors.Cyan,
            unit = "SPM",
            formatter = { String.format("%.0f", it) }
        )
        // Amplitude trend row
        TrendBarRow(
            title = "Vert. Osc. (cm)",
            values = trends.map { it.avgAmplitudeCm },
            color = AppColors.Mint,
            unit = "cm",
            formatter = { String.format("%.1f", it) },
            invertGood = true
        )
        // GCT trend row
        TrendBarRow(
            title = "GCT (ms)",
            values = trends.map { it.avgGCTMs },
            color = AppColors.Violet,
            unit = "ms",
            formatter = { String.format("%.0f", it) },
            invertGood = true
        )
        // Distance trend row
        TrendBarRow(
            title = "Distance (km)",
            values = trends.map { it.totalDistanceKm },
            color = AppColors.Orange,
            unit = "km",
            formatter = { String.format("%.1f", it) }
        )
    }
}

@Composable
private fun TrendBarRow(
    title: String,
    values: List<Double>,
    color: Color,
    unit: String,
    formatter: (Double) -> String,
    invertGood: Boolean = false
) {
    val maxVal = values.maxOrNull() ?: 1.0
    val minVal = values.minOrNull() ?: 0.0
    val range = if (maxVal - minVal < 0.001) 1.0 else maxVal - minVal

    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(title, color = AppColors.TextMuted, fontSize = 10.sp)
            Text(
                "${formatter(values.lastOrNull() ?: 0.0)} $unit",
                color = color,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        Spacer(Modifier.height(2.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            values.forEachIndexed { i, v ->
                val barFraction = ((v - minVal) / range).toFloat().coerceIn(0.02f, 1f)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(24.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height((24 * barFraction).dp)
                            .align(Alignment.BottomCenter)
                            .clip(RoundedCornerShape(topStart = 2.dp, topEnd = 2.dp))
                            .background(color.copy(alpha = if (i == values.lastIndex) 1f else 0.4f))
                    )
                }
            }
        }
    }
}
