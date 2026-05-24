package com.runformcoach.runformcoachai

import android.content.Intent
import android.net.Uri
import android.view.ViewGroup
import android.widget.Toast
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale

@Composable
fun AnalysisResultScreen(
    result: AnalysisResponse,
    onDismiss: (() -> Unit)? = null,
    feedbackViewModel: FeedbackViewModel? = null,
    analysisId: String? = null
) {
    val context = LocalContext.current
    val isChinese = Locale.getDefault().language == "zh"

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── RF-207 / RF-1001: Share buttons ────────────────────────────────
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Share text (existing)
            IconButton(onClick = {
                val scorePercent = (result.confidence * 100).toInt()
                val summary = result.summary
                val subject = context.getString(R.string.share_analysis_subject, scorePercent)
                val body = context.getString(R.string.share_analysis_body, scorePercent, summary)
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    putExtra(Intent.EXTRA_TEXT, body)
                }
                context.startActivity(Intent.createChooser(shareIntent, context.getString(R.string.share)))
            }) {
                Icon(
                    imageVector = Icons.Default.Share,
                    contentDescription = stringResource(R.string.share),
                    tint = AppColors.Mint,
                    modifier = Modifier.size(22.dp)
                )
            }
            // Share archaeology template (P1: Marketing alignment)
            IconButton(onClick = {
                val issueCount = result.issues.size
                val subject = context.getString(R.string.share_archaeology_subject, issueCount)
                val body = context.getString(R.string.share_archaeology_body, issueCount)
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    putExtra(Intent.EXTRA_TEXT, body)
                }
                context.startActivity(Intent.createChooser(shareIntent, context.getString(R.string.share)))
            }) {
                Icon(
                    imageVector = Icons.Default.Share,
                    contentDescription = "Share archaeology",
                    tint = AppColors.Orange,
                    modifier = Modifier.size(22.dp)
                )
            }
            // Share as image card (RF-1001)
            IconButton(onClick = {
                Toast.makeText(context, context.getString(R.string.share_card_saving), Toast.LENGTH_SHORT).show()
                CoroutineScope(Dispatchers.IO).launch {
                    val bitmap = ShareCardRenderer.renderAnalysisCard(context, result)
                    val uri = ShareCardRenderer.saveToGallery(context, bitmap, "runform_analysis")
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
                    modifier = Modifier.size(22.dp)
                )
            }
        }

        // ── Score card ────────────────────────────────────────────────────────
        GlassCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                ConfidenceRing(confidence = result.confidence, modifier = Modifier.size(90.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(stringResource(R.string.overall_score), color = AppColors.TextMuted, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Text("${(result.confidence * 100).toInt()}%", color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(6.dp))
                    Text(result.summary, color = AppColors.TextSecondary, fontSize = 13.sp, lineHeight = 18.sp)
                }
            }
        }

        // ── Video quality ─────────────────────────────────────────────────────
        result.videoQualityScore?.let { qualityScore ->
            DarkCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(stringResource(R.string.video_quality), color = AppColors.TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        Text("${(qualityScore * 100).toInt()}%", color = qualityBarColor(qualityScore), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                    MetricBar(progress = qualityScore.toFloat(), color = qualityBarColor(qualityScore))
                    result.qualityNotes.forEach { note ->
                        Text("• $note", color = AppColors.TextMuted, fontSize = 12.sp)
                    }
                }
            }
        }

        // ── Movement Metrics ──────────────────────────────────────────────────
        if (result.metrics.isNotEmpty()) {
            SectionTitle(stringResource(R.string.movement_metrics_title))
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    result.metrics.forEach { metric -> MetricRow(metric) }
                }
            }
        }

        // ── Strength Focus ────────────────────────────────────────────────────
        if (result.issues.isNotEmpty()) {
            SectionTitle(stringResource(R.string.strength_focus_title))
            result.issues.forEach { issue ->
                IssueCard(issue = issue, isChinese = isChinese, context = context)
            }
        }

        // ── Feedback section (RF-203) ─────────────────────────────────────────
        if (feedbackViewModel != null && analysisId != null) {
            FeedbackSection(
                viewModel = feedbackViewModel,
                analysisId = analysisId
            )
        }

        // ── AdMob Banner (RF-962) ───────────────────────────────────────────
        BannerAdView(modifier = Modifier.fillMaxWidth())

        // ── Dismiss ───────────────────────────────────────────────────────────
        onDismiss?.let {
            Button(
                onClick = it,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = AppColors.Card, contentColor = AppColors.TextSecondary)
            ) { Text(stringResource(R.string.analyze_new_video)) }
        }
    }
}

// ── Feedback composable (RF-203) ───────────────────────────────────────────────

@Composable
private fun FeedbackSection(
    viewModel: FeedbackViewModel,
    analysisId: String
) {
    val rating by viewModel.rating.collectAsState()
    val comment by viewModel.comment.collectAsState()
    val submissionState by viewModel.submissionState.collectAsState()

    val isSubmitted = submissionState is FeedbackSubmissionState.Submitted ||
            submissionState is FeedbackSubmissionState.SavedOffline

    SectionTitle(stringResource(R.string.tester_feedback))
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // Title row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    stringResource(R.string.feedback_subtitle),
                    color = AppColors.TextMuted,
                    fontSize = 12.sp
                )
                if (isSubmitted) {
                    Text(
                        "✓ Submitted",
                        color = AppColors.Mint,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // 5-star rating row
            StarRatingRow(
                rating = rating,
                enabled = !isSubmitted,
                onRatingChanged = { viewModel.setRating(it) }
            )

            // Optional comment field
            OutlinedTextField(
                value = comment,
                onValueChange = { viewModel.setComment(it) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSubmitted,
                placeholder = {
                    Text(
                        stringResource(R.string.feedback_comment_hint),
                        color = AppColors.TextMuted,
                        fontSize = 13.sp
                    )
                },
                textStyle = androidx.compose.ui.text.TextStyle(
                    color = Color.White,
                    fontSize = 13.sp
                ),
                minLines = 2,
                maxLines = 4,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AppColors.Border,
                    unfocusedBorderColor = AppColors.Border,
                    disabledBorderColor = AppColors.Border.copy(alpha = 0.4f),
                    focusedContainerColor = AppColors.Navy,
                    unfocusedContainerColor = AppColors.Navy,
                    disabledContainerColor = AppColors.Navy.copy(alpha = 0.5f),
                    disabledTextColor = AppColors.TextMuted,
                    cursorColor = AppColors.Mint
                ),
                shape = RoundedCornerShape(12.dp)
            )

            // Submission status message
            when (val state = submissionState) {
                is FeedbackSubmissionState.Submitting -> {
                    Text(
                        "Submitting…",
                        color = AppColors.Cyan,
                        fontSize = 12.sp
                    )
                }
                is FeedbackSubmissionState.Submitted -> {
                    Text(
                        if (state.offlineSaved) "Saved offline — will sync later" else "Feedback received. Thank you!",
                        color = AppColors.Mint,
                        fontSize = 12.sp
                    )
                }
                is FeedbackSubmissionState.SavedOffline -> {
                    Text(
                        state.message,
                        color = AppColors.Orange,
                        fontSize = 12.sp
                    )
                }
                is FeedbackSubmissionState.Error -> {
                    Text(
                        state.message,
                        color = AppColors.Red,
                        fontSize = 12.sp
                    )
                }
                else -> {}
            }

            // Submit button
            if (!isSubmitted) {
                Button(
                    onClick = { viewModel.submitFeedback(analysisId) },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = rating > 0 && submissionState !is FeedbackSubmissionState.Submitting,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = AppColors.Mint,
                        contentColor = Color.Black,
                        disabledContainerColor = AppColors.Card,
                        disabledContentColor = AppColors.TextMuted
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(
                        stringResource(R.string.feedback_save),
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun StarRatingRow(
    rating: Int,
    enabled: Boolean,
    onRatingChanged: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (star in 1..5) {
            val isFilled = star <= rating
            Icon(
                imageVector = if (isFilled) Icons.Default.Star else Icons.Default.StarBorder,
                contentDescription = "$star star${if (star > 1) "s" else ""}",
                modifier = Modifier
                    .size(36.dp)
                    .padding(2.dp)
                    .let { if (enabled) it.clickable { onRatingChanged(star) } else it },
                tint = if (isFilled) AppColors.Yellow else AppColors.TextMuted
            )
        }
    }
}

// ── Reusable composables ───────────────────────────────────────────────────────

@Composable
private fun ConfidenceRing(confidence: Double, modifier: Modifier = Modifier) {
    val mintColor = AppColors.Mint
    val bgColor = AppColors.Border
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val strokeWidth = size.minDimension * 0.10f
            val inset = strokeWidth / 2f
            val arcSize = Size(size.width - strokeWidth, size.height - strokeWidth)
            val topLeft = Offset(inset, inset)
            drawArc(color = bgColor, startAngle = -90f, sweepAngle = 360f, useCenter = false, topLeft = topLeft, size = arcSize, style = Stroke(width = strokeWidth, cap = StrokeCap.Round))
            drawArc(color = mintColor, startAngle = -90f, sweepAngle = (360f * confidence.coerceIn(0.0, 1.0)).toFloat(), useCenter = false, topLeft = topLeft, size = arcSize, style = Stroke(width = strokeWidth, cap = StrokeCap.Round))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("${(confidence * 100).toInt()}", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text("%", color = AppColors.TextMuted, fontSize = 10.sp)
        }
    }
}

@Composable
private fun MetricRow(metric: Metric) {
    // P0: Color based on abnormality — normal=green (#00f5a0), abnormal=red (#ff4444)
    val isAbnormal = metric.status.lowercase() in listOf("critical", "poor", "needs work")
    val metricColor = if (isAbnormal) AppColors.Red else AppColors.Mint
    
    // P1: Injury risk hint mapping
    val injuryHint = injuryRiskHint(metric.name, metric.status)
    
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text(metric.name, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Medium)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("${(metric.score * 100).toInt()}%", color = metricColor, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                StatusBadge(metric.status)
            }
        }
        MetricBar(progress = metric.score.toFloat(), color = metricColor)
        Text(metric.explanation, color = AppColors.TextMuted, fontSize = 12.sp, lineHeight = 16.sp)
        // P1: Injury risk hint below explanation
        if (injuryHint != null) {
            Text(injuryHint, color = if (isAbnormal) AppColors.Red.copy(alpha = 0.7f) else AppColors.Mint.copy(alpha = 0.7f), fontSize = 11.sp, lineHeight = 14.sp)
        }
    }
}

/**
 * Map metric name + status to an injury risk hint string.
 * Returns null if no relevant hint.
 */
private fun injuryRiskHint(metricName: String, status: String): String? {
    if (status.lowercase() in listOf("good", "excellent")) return null
    val nameLower = metricName.lowercase()
    return when {
        nameLower.contains("cadence") || nameLower.contains("步频") -> "⚠ " + stringResource(R.string.injury_risk_cadence_low)
        nameLower.contains("overstride") || nameLower.contains("stride") || nameLower.contains("步幅") || nameLower.contains("跨步") -> "⚠ " + stringResource(R.string.injury_risk_overstride)
        nameLower.contains("trunk") || nameLower.contains("lean") || nameLower.contains("躯干") || nameLower.contains("倾") -> "⚠ " + stringResource(R.string.injury_risk_trunk_lean)
        nameLower.contains("hip") || nameLower.contains("drop") || nameLower.contains("髋") -> "⚠ " + stringResource(R.string.injury_risk_hip_drop)
        nameLower.contains("knee") || nameLower.contains("valgus") || nameLower.contains("膝") -> "⚠ " + stringResource(R.string.injury_risk_knee_valgus)
        nameLower.contains("gct") || nameLower.contains("ground contact") || nameLower.contains("触地") -> "⚠ " + stringResource(R.string.injury_risk_gct_long)
        nameLower.contains("oscillation") || nameLower.contains("amplitude") || nameLower.contains("振幅") -> "⚠ " + stringResource(R.string.injury_risk_amplitude_high)
        else -> null
    }
}

@Composable
internal fun MetricBar(progress: Float, color: Color, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(AppColors.Border)) {
        Box(modifier = Modifier.fillMaxWidth(progress.coerceIn(0f, 1f)).height(4.dp).clip(RoundedCornerShape(2.dp)).background(color))
    }
}

@Composable
internal fun StatusBadge(status: String) {
    val (bg, fg) = when (status.lowercase()) {
        "good", "excellent" -> AppColors.Mint.copy(alpha = 0.2f) to AppColors.Mint
        "needs work", "fair" -> AppColors.Orange.copy(alpha = 0.2f) to AppColors.Orange
        "critical", "poor" -> AppColors.Red.copy(alpha = 0.2f) to AppColors.Red
        else -> AppColors.Cyan.copy(alpha = 0.2f) to AppColors.Cyan
    }
    Box(modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(bg).padding(horizontal = 8.dp, vertical = 2.dp)) {
        Text(status, color = fg, fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun IssueCard(issue: Issue, isChinese: Boolean, context: android.content.Context) {
    val severityColor = when (issue.severity.lowercase()) {
        "high", "critical" -> AppColors.Red
        "medium" -> AppColors.Orange
        else -> AppColors.Cyan
    }
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(issue.title, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Spacer(Modifier.width(8.dp))
                Box(modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(severityColor.copy(alpha = 0.2f)).padding(horizontal = 8.dp, vertical = 3.dp)) {
                    Text(issue.severity, color = severityColor, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            Text(issue.explanation, color = AppColors.TextSecondary, fontSize = 13.sp, lineHeight = 18.sp)
            if (issue.recommendedExercises.isNotEmpty()) {
                SectionTitle(stringResource(R.string.exercises))
                issue.recommendedExercises.forEach { ex ->
                    ExerciseCard(exercise = ex, isChinese = isChinese, context = context)
                }
            }
        }
    }
}

@Composable
private fun ExerciseCard(exercise: Exercise, isChinese: Boolean, context: android.content.Context) {
    val url = if (isChinese) {
        "https://search.bilibili.com/all?keyword=${Uri.encode(exercise.name + " 跑步训练")}"
    } else {
        "https://www.youtube.com/results?search_query=${Uri.encode(exercise.name + " running exercise")}"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.Navy)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(10.dp))
            .clickable { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
            .padding(12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(exercise.name, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Text("${exercise.sets} sets × ${exercise.reps} — ${exercise.frequencyPerWeek}x/week", color = AppColors.TextMuted, fontSize = 12.sp)
        }
        Icon(imageVector = Icons.Default.OpenInNew, contentDescription = "Watch", tint = AppColors.Cyan, modifier = Modifier.padding(start = 8.dp).size(16.dp))
    }
}

private fun qualityBarColor(score: Double): Color = when {
    score >= 0.7 -> AppColors.Mint
    score >= 0.4 -> AppColors.Orange
    else -> AppColors.Red
}

// ── AdMob Banner Ad (RF-962) ──────────────────────────────────────────────────

/**
 * Test ad unit ID for debug builds.
 * TODO: Replace production ad unit ID placeholder before release.
 * See: https://developers.google.com/admob/android/test-ads
 */
private const val BANNER_AD_UNIT_ID_TEST = "ca-app-pub-3940256099942544/6300978111"
// TODO: Replace with production ad unit ID before release
private const val BANNER_AD_UNIT_ID_PRODUCTION = "ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx"

/**
 * A simple Banner Ad wrapped for Jetpack Compose using AndroidView.
 * Uses a fixed AdSize.BANNER (320x50 dp).
 */
@Composable
private fun BannerAdView(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val adView = remember(context) {
        AdView(context).apply {
            setAdSize(AdSize.BANNER)
            adUnitId = if (com.runformcoach.runformcoachai.BuildConfig.DEBUG) BANNER_AD_UNIT_ID_TEST else BANNER_AD_UNIT_ID_PRODUCTION
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
    }

    AndroidView(
        factory = {
            adView.loadAd(AdRequest.Builder().build())
            adView
        },
        modifier = modifier
    )
}
