package com.runformcoach.runformcoachai

import android.content.Intent
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import java.util.Locale

/**
 * Full-screen comparison result view.
 * Displays similarity score, coaching narrative, top gaps,
 * metric-by-metric breakdown, and athlete biography.
 */
@Composable
fun CompareResultScreen(
    result: CompareResponse,
    athleteName: String,
    onClose: () -> Unit,
    compareVm: CompareViewModel = hiltViewModel()
) {
    val compareResultState by compareVm.compareResultState.collectAsState()
    val customCompareResultState by compareVm.customCompareResultState.collectAsState()
    val isLoading = compareResultState is CompareResultState.Loading ||
        customCompareResultState is CompareResultState.Loading
    val error = (compareResultState as? CompareResultState.Error)?.message
        ?: (customCompareResultState as? CompareResultState.Error)?.message

    if (isLoading) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                CircularProgressIndicator(color = AppColors.Mint, modifier = Modifier.size(44.dp))
                Text(
                    text = stringResource(R.string.comparing_your_form),
                    color = AppColors.TextSecondary,
                    fontSize = 14.sp
                )
            }
        }
        return
    }

    if (error != null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = AppColors.Orange,
                    modifier = Modifier.size(40.dp)
                )
                Text(stringResource(R.string.comparison_failed), color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(error, color = AppColors.TextSecondary, fontSize = 13.sp)
                TextButton(onClick = onClose) {
                    Text(stringResource(R.string.compare_go_back), color = AppColors.Mint)
                }
            }
        }
        return
    }

    // Result content
    Column(modifier = Modifier.fillMaxSize()) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onClose) {
                Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.close), tint = AppColors.Mint)
            }
            Text(
                text = athleteName,
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
            // ── RF-207: Share button ───────────────────────────────────────
            val context = LocalContext.current
            IconButton(onClick = {
                val scorePercent = (result.overallSimilarityScore * 100).toInt()
                val topGap = result.topGaps.firstOrNull() ?: "N/A"
                val subject = context.getString(R.string.share_compare_subject, "me", athleteName)
                val body = context.getString(R.string.share_compare_body, athleteName, scorePercent, topGap)
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    putExtra(Intent.EXTRA_TEXT, body)
                }
                context.startActivity(Intent.createChooser(shareIntent, context.getString(R.string.share)))
            }) {
                Icon(Icons.Default.Share, contentDescription = stringResource(R.string.share), tint = AppColors.Mint)
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                horizontal = 16.dp,
                vertical = 8.dp
            ),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            // ── Similarity Card ────────────────────────────────────────────────
            item { SimilarityCard(result = result) }

            // ── Coaching Narrative ─────────────────────────────────────────────
            if (result.coachingNarrative.isNotBlank()) {
                item { NarrativeCard(text = result.coachingNarrative) }
            }

            // ── Top Gaps ───────────────────────────────────────────────────────
            if (result.topGaps.isNotEmpty()) {
                item { TopGapsCard(gaps = result.topGaps) }
            }

            // ── Metric Breakdown ───────────────────────────────────────────────
            if (result.comparisons.isNotEmpty()) {
                item { SectionTitle(stringResource(R.string.metric_breakdown)) }
                items(result.comparisons) { comparison ->
                    MetricComparisonRow(comparison = comparison)
                }
            }

            // ── Athlete Bio ────────────────────────────────────────────────────
            item { AthleteBioCard(profile = result.athlete) }

            // ── Bottom spacer ──────────────────────────────────────────────────
            item { Spacer(Modifier.height(32.dp)) }
        }
    }
}

// ── Similarity Card ────────────────────────────────────────────────────────────

@Composable
private fun SimilarityCard(result: CompareResponse) {
    val initials = result.athlete.name
        .split(" ")
        .mapNotNull { it.firstOrNull()?.toString() }
        .take(2)
        .joinToString("")

    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Athlete initials circle
            Box(
                modifier = Modifier
                    .size(54.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = listOf(AppColors.Mint, AppColors.Cyan)
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = initials.ifEmpty { "?" },
                    color = Color.Black,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = result.athlete.name,
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = result.athlete.event,
                    color = AppColors.Mint,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text = result.athlete.achievement,
                    color = AppColors.TextSecondary,
                    fontSize = 11.sp,
                    maxLines = 2
                )
            }

            // Overall similarity ring
            SimilarityRing(
                score = result.overallSimilarityScore,
                modifier = Modifier.size(76.dp)
            )
        }
    }
}

@Composable
private fun SimilarityRing(score: Double, modifier: Modifier = Modifier) {
    val clampedScore = score.coerceIn(0.0, 1.0)
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val strokeWidth = size.minDimension * 0.10f
            val inset = strokeWidth / 2f
            val arcSize = Size(size.width - strokeWidth, size.height - strokeWidth)
            val topLeft = Offset(inset, inset)
            // Background ring
            drawArc(
                color = AppColors.Border,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
            // Progress ring with warm gradient
            drawArc(
                color = AppColors.Orange,
                startAngle = -90f,
                sweepAngle = (360f * clampedScore).toFloat(),
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "${(clampedScore * 100).toInt()}%",
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(R.string.match_label),
                color = AppColors.TextMuted,
                fontSize = 9.sp
            )
        }
    }
}

// ── Narrative Card ─────────────────────────────────────────────────────────────

@Composable
private fun NarrativeCard(text: String) {
    DarkCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = AppColors.Mint,
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = stringResource(R.string.coachs_take),
                    color = AppColors.Mint,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Text(
                text = text,
                color = AppColors.TextSecondary,
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
        }
    }
}

// ── Top Gaps Card ──────────────────────────────────────────────────────────────

@Composable
private fun TopGapsCard(gaps: List<String>) {
    DarkCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                text = stringResource(R.string.biggest_gaps),
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold
            )
            gaps.forEach { gap ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(7.dp)
                            .clip(CircleShape)
                            .background(AppColors.Orange)
                    )
                    Text(
                        text = gap,
                        color = AppColors.TextSecondary,
                        fontSize = 13.sp,
                        lineHeight = 18.sp
                    )
                }
            }
        }
    }
}

// ── Metric Comparison Row ──────────────────────────────────────────────────────

@Composable
private fun MetricComparisonRow(comparison: MetricComparison) {
    val statusColor = when (comparison.status) {
        "ahead" -> AppColors.Mint
        "on_par" -> AppColors.Cyan
        else -> AppColors.Orange
    }
    val statusLabel = when (comparison.status) {
        "ahead" -> stringResource(R.string.status_ahead)
        "on_par" -> stringResource(R.string.status_on_par)
        else -> stringResource(R.string.status_gap)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.Card)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(16.dp))
            .padding(14.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Metric name + status
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = comparison.metric,
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = statusLabel,
                    color = statusColor,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            // You vs Elite labels
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(R.string.you), color = AppColors.Cyan, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text(": ${comparison.userLabel}", color = AppColors.TextSecondary, fontSize = 12.sp)
                }
                Text(stringResource(R.string.vs_label), color = AppColors.TextMuted, fontSize = 11.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(R.string.elite_benchmark), color = AppColors.Orange, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text(": ${comparison.athleteLabel}", color = AppColors.TextSecondary, fontSize = 12.sp)
                }
            }

            // Dual bar
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(AppColors.Border)
            ) {
                // User bar (cyan)
                val userWidth = comparison.userScore.coerceIn(0.0, 1.0).toFloat()
                Box(
                    modifier = Modifier
                        .fillMaxWidth(userWidth)
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(AppColors.Cyan)
                )
                // Athlete marker line (orange)
                val athletePos = comparison.athleteScore.coerceIn(0.0, 1.0).toFloat()
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = androidx.compose.ui.unit.Dp(athletePos * 600f)) // approximation
                )
            }

            // Legend
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(modifier = Modifier.size(6.dp).clip(CircleShape).background(AppColors.Cyan))
                    Text(stringResource(R.string.you), color = AppColors.TextMuted, fontSize = 10.sp)
                }
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .width(10.dp)
                            .height(2.dp)
                            .background(AppColors.Orange)
                    )
                    Text(stringResource(R.string.elite_benchmark), color = AppColors.TextMuted, fontSize = 10.sp)
                }
            }
        }
    }
}

// ── Athlete Bio Card ───────────────────────────────────────────────────────────

@Composable
private fun AthleteBioCard(profile: AthleteProfile) {
    DarkCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                text = "${stringResource(R.string.about_label)} ${profile.name}",
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold
            )
            if (profile.bio.isNotBlank()) {
                Text(
                    text = profile.bio,
                    color = AppColors.TextSecondary,
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
            Text(
                text = "${profile.nationality} · ${profile.event}",
                color = AppColors.Mint,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}
