package com.runformcoach.runformcoachai

import androidx.compose.foundation.Canvas
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
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

// ── Replay Color Palette ──────────────────────────────────────────────────────

private val ReplayBg = Color(0xFF0A0A0F)
private val ReplayMint = Color(0xFF00F5A0)
private val ReplayCyan = Color(0xFF1AABFF)
private val ReplayOrange = Color(0xFFFF9E38)
private val ReplayViolet = Color(0xFF7866FF)
private val ReplayRed = Color(0xFFFF5252)
private val ReplayCardSurface = Color(0x14FFFFFF)
private val ReplayCardBorder = Color(0x18FFFFFF)
private val ReplayTextSecondary = Color(0xA0FFFFFF)
private val ReplayTextMuted = Color(0x60FFFFFF)

// ── Metric Colors (matching existing AppColors convention) ────────────────────

private val CadenceColor = ReplayCyan
private val AmplitudeColor = ReplayMint
private val GCTColor = ReplayOrange
private val TrunkLeanColor = ReplayViolet

// ── Session Replay Entry Point ────────────────────────────────────────────────

/**
 * Top-level composable for RF-1000 RunSession History & Replay.
 *
 * Two modes:
 * 1. **List mode** — shows historical sessions fetched from GET /sessions
 * 2. **Replay mode** — shows interactive replay for a selected session
 *
 * @param viewModel  Hilt-injected [RunSessionReplayViewModel].
 * @param onDismiss  Called when the user exits the screen.
 */
@Composable
fun RunSessionReplayScreen(
    viewModel: RunSessionReplayViewModel = hiltViewModel(),
    onDismiss: () -> Unit = {}
) {
    val listState by viewModel.listState.collectAsState()
    val detailState by viewModel.detailState.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ReplayBg)
    ) {
        when {
            // Replay mode is active when detail is loading or loaded
            detailState is RunSessionDetailState.Loading ||
            detailState is RunSessionDetailState.Success -> {
                RunSessionReplayContent(
                    viewModel = viewModel,
                    onBack = { viewModel.dismissDetail() },
                    onDismiss = onDismiss
                )
            }
            // List mode
            else -> {
                SessionListContent(
                    listState = listState,
                    onSessionTap = { sessionId -> viewModel.selectSession(sessionId) },
                    onRefresh = { viewModel.loadSessionList() },
                    onDismiss = onDismiss
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Session List Mode ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun SessionListContent(
    listState: RunSessionListState,
    onSessionTap: (String) -> Unit,
    onRefresh: () -> Unit,
    onDismiss: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        // ── Top bar ────────────────────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.replay_session_history),
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onRefresh) {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = stringResource(R.string.refresh),
                        tint = ReplayTextSecondary
                    )
                }
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = stringResource(R.string.close),
                        tint = ReplayTextSecondary
                    )
                }
            }
        }

        // ── Content ────────────────────────────────────────────────────────
        when (listState) {
            is RunSessionListState.Loading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = stringResource(R.string.replay_loading_sessions),
                        color = ReplayTextSecondary,
                        fontSize = 16.sp
                    )
                }
            }
            is RunSessionListState.Error -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = listState.message,
                            color = ReplayRed,
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center
                        )
                        Text(
                            text = stringResource(R.string.replay_tap_to_retry),
                            color = ReplayMint,
                            fontSize = 14.sp,
                            modifier = Modifier.clickable { onRefresh() }
                        )
                    }
                }
            }
            is RunSessionListState.Success -> {
                if (listState.sessions.isEmpty()) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.DirectionsRun,
                                contentDescription = null,
                                tint = ReplayTextMuted,
                                modifier = Modifier.size(64.dp)
                            )
                            Text(
                                text = stringResource(R.string.replay_no_sessions),
                                color = ReplayTextSecondary,
                                fontSize = 17.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = stringResource(R.string.replay_no_sessions_hint),
                                color = ReplayTextMuted,
                                fontSize = 14.sp
                            )
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(listState.sessions, key = { it.id }) { session ->
                            SessionSummaryCard(session = session, onTap = { onSessionTap(session.id) })
                        }
                    }
                }
            }
        }
    }
}

// ── Session Summary Card ──────────────────────────────────────────────────────

@Composable
private fun SessionSummaryCard(
    session: RunSessionSummary,
    onTap: () -> Unit
) {
    val dateStr = remember(session.createdAt) {
        SimpleDateFormat("MMM d, yyyy  HH:mm", Locale.getDefault())
            .format(Date(session.createdAt))
    }
    val durationMin = (session.durationSeconds / 60.0).roundToInt()
    val distKm = session.distanceKm

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ReplayCardSurface)
            .border(0.5.dp, ReplayCardBorder, RoundedCornerShape(16.dp))
            .clickable { onTap() }
            .padding(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Date + duration header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = dateStr,
                    color = ReplayTextSecondary,
                    fontSize = 12.sp
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    // Duration badge
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(ReplayMint.copy(alpha = 0.15f))
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.replay_duration_min, durationMin),
                            color = ReplayMint,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            fontFamily = FontFamily.Monospace
                        )
                    }
                }
            }

            // Distance
            if (distKm > 0) {
                Text(
                    text = stringResource(R.string.replay_distance_km, distKm),
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            // Metric row — 3 mini cards
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                MiniMetricBadge(
                    label = stringResource(R.string.replay_cadence_short),
                    value = stringResource(id = R.string.replay_spm_format, session.avgCadenceSPM),
                    color = CadenceColor,
                    modifier = Modifier.weight(1f)
                )
                MiniMetricBadge(
                    label = stringResource(R.string.replay_amplitude_short),
                    value = stringResource(id = R.string.replay_cm_format, session.avgAmplitudeCm),
                    color = AmplitudeColor,
                    modifier = Modifier.weight(1f)
                )
                MiniMetricBadge(
                    label = stringResource(R.string.replay_gct_short),
                    value = stringResource(id = R.string.replay_ms_format, session.avgGCTMs),
                    color = GCTColor,
                    modifier = Modifier.weight(1f)
                )
            }

            // Prompt count + tap hint
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (session.promptCount > 0) {
                    Text(
                        text = stringResource(R.string.replay_prompt_count, session.promptCount),
                        color = ReplayTextMuted,
                        fontSize = 11.sp
                    )
                } else {
                    Spacer(Modifier.width(1.dp))
                }
                Text(
                    text = stringResource(R.string.replay_tap_to_view),
                    color = ReplayMint,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

@Composable
private fun MiniMetricBadge(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(color.copy(alpha = 0.08f))
            .border(0.5.dp, color.copy(alpha = 0.25f), RoundedCornerShape(10.dp))
            .padding(horizontal = 10.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            color = ReplayTextMuted,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.5.sp
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = value,
            color = color,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Session Replay Mode ───────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun RunSessionReplayContent(
    viewModel: RunSessionReplayViewModel,
    onBack: () -> Unit,
    onDismiss: () -> Unit
) {
    val detailState by viewModel.detailState.collectAsState()
    val playbackState by viewModel.playbackState.collectAsState()
    val currentIndex by viewModel.currentDataPointIndex.collectAsState()

    Column(modifier = Modifier.fillMaxSize()) {
        // ── Top bar ────────────────────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = stringResource(R.string.replay_back_to_list),
                    tint = ReplayTextSecondary
                )
            }
            Text(
                text = stringResource(R.string.replay_title),
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
            IconButton(onClick = onDismiss) {
                Icon(
                    imageVector = Icons.Default.Stop,
                    contentDescription = stringResource(R.string.close),
                    tint = ReplayTextSecondary,
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        when (val state = detailState) {
            is RunSessionDetailState.Loading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = stringResource(R.string.replay_loading_detail),
                        color = ReplayTextSecondary,
                        fontSize = 16.sp
                    )
                }
            }
            is RunSessionDetailState.Error -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = state.message,
                        color = ReplayRed,
                        fontSize = 14.sp,
                        textAlign = TextAlign.Center
                    )
                }
            }
            is RunSessionDetailState.Success -> {
                val session = state.session
                val dataPoints = remember(session) { session.dataPoints }
                val dp = dataPoints.getOrNull(currentIndex)

                ReplayContent(
                    session = session,
                    currentDataPoint = dp,
                    currentIndex = currentIndex,
                    totalPoints = dataPoints.size,
                    playbackState = playbackState,
                    onPlay = viewModel::play,
                    onPause = viewModel::pause,
                    onStop = viewModel::stopReplay,
                    onSeek = viewModel::seekTo
                )
            }
            else -> {}
        }
    }
}

// ── Replay Main Content ───────────────────────────────────────────────────────

@Composable
private fun ReplayContent(
    session: RunSessionDetail,
    currentDataPoint: ReplayDataPoint?,
    currentIndex: Int,
    totalPoints: Int,
    playbackState: ReplayPlaybackState,
    onPlay: () -> Unit,
    onPause: () -> Unit,
    onStop: () -> Unit,
    onSeek: (Int) -> Unit
) {
    val dataPoints = remember(session) { session.dataPoints }
    val elapsedSec = currentDataPoint?.elapsedSeconds ?: 0.0
    val mins = (elapsedSec / 60).toInt()
    val secs = (elapsedSec % 60).toInt()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // ── (1) Key Stat Cards Row ─────────────────────────────────────────
        item(key = "stats") {
            KeyStatCards(session = session)
        }

        // ── (2) Map Trace (Path) ──────────────────────────────────────────
        if (session.pathCoordinates.size >= 2) {
            item(key = "map") {
                MapTraceCard(
                    path = session.pathCoordinates,
                    currentIndex = currentIndex,
                    totalPoints = session.pathCoordinates.size
                )
            }
        }

        // ── (3) Playback Controls + Timer ──────────────────────────────────
        item(key = "controls") {
            PlaybackControls(
                elapsedMins = mins,
                elapsedSecs = secs,
                totalDurationSec = session.durationSeconds,
                currentIndex = currentIndex,
                totalPoints = totalPoints,
                playbackState = playbackState,
                onPlay = onPlay,
                onPause = onPause,
                onStop = onStop,
                onSeek = onSeek
            )
        }

        // ── (4) Current Metric Display ────────────────────────────────────
        item(key = "current_metrics") {
            if (currentDataPoint != null) {
                CurrentMetricCards(dataPoint = currentDataPoint)
            }
        }

        // ── (5) Timeline Chart ─────────────────────────────────────────────
        if (dataPoints.size >= 2) {
            item(key = "timeline") {
                TimelineChartCard(
                    dataPoints = dataPoints,
                    currentIndex = currentIndex,
                    coachPrompts = session.coachPrompts
                )
            }
        }

        // ── (6) Coach Prompt History ───────────────────────────────────────
        if (session.coachPrompts.isNotEmpty()) {
            item(key = "prompts") {
                CoachPromptList(
                    prompts = session.coachPrompts,
                    currentElapsed = elapsedSec
                )
            }
        }

        // Bottom spacer for nav bar clearance
        item(key = "spacer") {
            Spacer(Modifier.height(16.dp))
        }
    }
}

// ── (A) Key Stat Cards ────────────────────────────────────────────────────────

@Composable
private fun KeyStatCards(session: RunSessionDetail) {
    val durationMin = (session.durationSeconds / 60.0).roundToInt()

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        StatCard(
            label = stringResource(R.string.replay_duration_label),
            value = stringResource(R.string.replay_min_label, durationMin),
            color = ReplayMint,
            modifier = Modifier.weight(1f)
        )
        StatCard(
            label = stringResource(R.string.replay_distance_label),
            value = stringResource(R.string.replay_km_label, session.distanceKm),
            color = ReplayCyan,
            modifier = Modifier.weight(1f)
        )
        StatCard(
            label = stringResource(R.string.replay_avg_cadence_label),
            value = stringResource(id = R.string.replay_spm_format, session.avgCadenceSPM),
            color = CadenceColor,
            modifier = Modifier.weight(1f)
        )
        StatCard(
            label = stringResource(R.string.replay_avg_amplitude_label),
            value = stringResource(id = R.string.replay_cm_format, session.avgAmplitudeCm),
            color = AmplitudeColor,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.08f))
            .border(0.5.dp, color.copy(alpha = 0.25f), RoundedCornerShape(12.dp))
            .padding(horizontal = 8.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            color = ReplayTextMuted,
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.5.sp,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = value,
            color = color,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            maxLines = 1
        )
    }
}

// ── (B) Map Trace Card ────────────────────────────────────────────────────────

@Composable
private fun MapTraceCard(
    path: List<PathCoordinate>,
    currentIndex: Int,
    totalPoints: Int
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ReplayCardSurface)
            .border(0.5.dp, ReplayCardBorder, RoundedCornerShape(16.dp))
            .padding(12.dp)
    ) {
        Column {
            Text(
                text = stringResource(R.string.replay_route_map).uppercase(),
                color = ReplayTextMuted,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.2.sp,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            val progress = if (totalPoints > 1) currentIndex.toFloat() / (totalPoints - 1) else 0f

            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
            ) {
                if (path.size < 2) return@Canvas

                val padding = 20f
                val chartW = size.width - padding * 2
                val chartH = size.height - padding * 2

                // Compute bounding box
                val minLat = path.minOf { it.lat }
                val maxLat = path.maxOf { it.lat }
                val minLng = path.minOf { it.lng }
                val maxLng = path.maxOf { it.lng }
                val latRange = (maxLat - minLat).let { if (it < 0.0001) 0.001 else it }
                val lngRange = (maxLng - minLng).let { if (it < 0.0001) 0.001 else it }

                fun coordToPixel(c: PathCoordinate): Offset {
                    val x = padding + ((c.lng - minLng) / lngRange).toFloat() * chartW
                    // Invert Y because lat increases upward
                    val y = padding + ((maxLat - c.lat) / latRange).toFloat() * chartH
                    return Offset(x, y)
                }

                // Draw path trace
                val tracePath = Path()
                path.forEachIndexed { i, coord ->
                    val pt = coordToPixel(coord)
                    if (i == 0) tracePath.moveTo(pt.x, pt.y)
                    else tracePath.lineTo(pt.x, pt.y)
                }
                drawPath(
                    path = tracePath,
                    color = ReplayMint.copy(alpha = 0.5f),
                    style = Stroke(width = 3f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )

                // Draw current position indicator
                if (currentIndex in path.indices) {
                    val currentPt = coordToPixel(path[currentIndex])
                    drawCircle(
                        color = ReplayMint,
                        radius = 7f,
                        center = currentPt
                    )
                    drawCircle(
                        color = Color.White,
                        radius = 3f,
                        center = currentPt
                    )
                }

                // Draw start marker
                val startPt = coordToPixel(path.first())
                drawCircle(
                    color = ReplayCyan,
                    radius = 5f,
                    center = startPt
                )

                // Draw end marker
                val endPt = coordToPixel(path.last())
                drawCircle(
                    color = ReplayRed,
                    radius = 5f,
                    center = endPt
                )
            }

            // Legend
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                MapLegendDot(color = ReplayCyan, label = stringResource(R.string.replay_start))
                Spacer(Modifier.width(16.dp))
                MapLegendDot(color = ReplayRed, label = stringResource(R.string.replay_end))
                Spacer(Modifier.width(16.dp))
                MapLegendDot(color = ReplayMint, label = stringResource(R.string.replay_you_are_here))
            }
        }
    }
}

@Composable
private fun MapLegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(Modifier.width(4.dp))
        Text(
            text = label,
            color = ReplayTextMuted,
            fontSize = 10.sp
        )
    }
}

// ── (C) Playback Controls ─────────────────────────────────────────────────────

@Composable
private fun PlaybackControls(
    elapsedMins: Int,
    elapsedSecs: Int,
    totalDurationSec: Double,
    currentIndex: Int,
    totalPoints: Int,
    playbackState: ReplayPlaybackState,
    onPlay: () -> Unit,
    onPause: () -> Unit,
    onStop: () -> Unit,
    onSeek: (Int) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ReplayCardSurface)
            .border(0.5.dp, ReplayCardBorder, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Column {
            // Timer display
            val totalMins = (totalDurationSec / 60).toInt()
            val totalSecs = (totalDurationSec % 60).toInt()
            Text(
                text = stringResource(
                    R.string.replay_timer_format,
                    elapsedMins, elapsedSecs, totalMins, totalSecs
                ),
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(8.dp))

            // Slider
            if (totalPoints > 1) {
                Slider(
                    value = currentIndex.toFloat(),
                    onValueChange = { onSeek(it.roundToInt()) },
                    valueRange = 0f..(totalPoints - 1).toFloat(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = SliderDefaults.colors(
                        thumbColor = ReplayMint,
                        activeTrackColor = ReplayMint,
                        inactiveTrackColor = ReplayMint.copy(alpha = 0.2f)
                    )
                )
            }

            Spacer(Modifier.height(4.dp))

            // Control buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Stop button
                IconButton(onClick = onStop) {
                    Icon(
                        imageVector = Icons.Default.Stop,
                        contentDescription = stringResource(R.string.replay_stop),
                        tint = ReplayRed,
                        modifier = Modifier.size(32.dp)
                    )
                }

                Spacer(Modifier.width(24.dp))

                // Play/Pause button
                when (playbackState) {
                    ReplayPlaybackState.PLAYING -> {
                        IconButton(onClick = onPause) {
                            Icon(
                                imageVector = Icons.Default.Pause,
                                contentDescription = stringResource(R.string.replay_pause),
                                tint = ReplayMint,
                                modifier = Modifier.size(40.dp)
                            )
                        }
                    }
                    else -> {
                        IconButton(onClick = onPlay) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = stringResource(R.string.replay_play),
                                tint = ReplayMint,
                                modifier = Modifier.size(40.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

// ── (D) Current Metric Cards ──────────────────────────────────────────────────

@Composable
private fun CurrentMetricCards(dataPoint: ReplayDataPoint) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        LiveMetricCard(
            label = stringResource(R.string.replay_cadence_short),
            value = stringResource(id = R.string.replay_spm_format, dataPoint.cadenceSPM),
            color = CadenceColor,
            modifier = Modifier.weight(1f)
        )
        LiveMetricCard(
            label = stringResource(R.string.replay_amplitude_short),
            value = stringResource(id = R.string.replay_cm_format, dataPoint.amplitudeCm),
            color = AmplitudeColor,
            modifier = Modifier.weight(1f)
        )
        LiveMetricCard(
            label = stringResource(R.string.replay_gct_short),
            value = stringResource(id = R.string.replay_ms_format, dataPoint.gctMs),
            color = GCTColor,
            modifier = Modifier.weight(1f)
        )
        LiveMetricCard(
            label = stringResource(R.string.replay_trunk_lean_short),
            value = stringResource(id = R.string.replay_deg_format, dataPoint.trunkLeanDeg),
            color = TrunkLeanColor,
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun LiveMetricCard(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.10f))
            .border(0.5.dp, color.copy(alpha = 0.30f), RoundedCornerShape(12.dp))
            .padding(horizontal = 6.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            color = ReplayTextMuted,
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.5.sp
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = value,
            color = color,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace
        )
    }
}

// ── (E) Timeline Chart ────────────────────────────────────────────────────────

@Composable
private fun TimelineChartCard(
    dataPoints: List<ReplayDataPoint>,
    currentIndex: Int,
    coachPrompts: List<SessionCoachPrompt>
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ReplayCardSurface)
            .border(0.5.dp, ReplayCardBorder, RoundedCornerShape(16.dp))
            .padding(12.dp)
    ) {
        Column {
            Text(
                text = stringResource(R.string.replay_timeline_chart).uppercase(),
                color = ReplayTextMuted,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.2.sp,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            // Legend
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                ChartLegendDot(color = CadenceColor, label = stringResource(R.string.replay_cadence_short))
                ChartLegendDot(color = AmplitudeColor, label = stringResource(R.string.replay_amplitude_short))
                ChartLegendDot(color = GCTColor, label = stringResource(R.string.replay_gct_short))
            }

            Spacer(Modifier.height(6.dp))

            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
            ) {
                if (dataPoints.size < 2) return@Canvas

                val paddingLeft = 40f
                val paddingRight = 16f
                val paddingTop = 12f
                val paddingBottom = 24f
                val chartW = size.width - paddingLeft - paddingRight
                val chartH = size.height - paddingTop - paddingBottom

                // Compute global ranges
                val allCadence = dataPoints.map { it.cadenceSPM }
                val allAmplitude = dataPoints.map { it.amplitudeCm }
                val allGCT = dataPoints.map { it.gctMs }

                val cadenceMin = allCadence.minOrNull() ?: 0.0
                val cadenceMax = allCadence.maxOrNull() ?: 200.0
                val amplitudeMin = allAmplitude.minOrNull() ?: 0.0
                val amplitudeMax = allAmplitude.maxOrNull() ?: 15.0
                val gctMin = allGCT.minOrNull() ?: 0.0
                val gctMax = allGCT.maxOrNull() ?: 350.0

                fun normalizeToCadenceRange(value: Double): Float {
                    val range = (cadenceMax - cadenceMin).let { if (it < 1) 1.0 else it }
                    return paddingTop + chartH * (1f - ((value - cadenceMin) / range)).toFloat()
                }
                fun normalizeToAmplitudeRange(value: Double): Float {
                    val range = (amplitudeMax - amplitudeMin).let { if (it < 0.1) 0.1 else it }
                    return paddingTop + chartH * (1f - ((value - amplitudeMin) / range)).toFloat()
                }
                fun normalizeToGCTRange(value: Double): Float {
                    val range = (gctMax - gctMin).let { if (it < 1) 1.0 else it }
                    return paddingTop + chartH * (1f - ((value - gctMin) / range)).toFloat()
                }

                val stepX = if (dataPoints.size > 1) chartW / (dataPoints.size - 1) else 0f

                // Draw grid lines
                val gridPaint = android.graphics.Paint().apply {
                    color = android.graphics.Color.parseColor("#20FFFFFF")
                    strokeWidth = 1f
                }
                for (i in 0..4) {
                    val y = paddingTop + (chartH * i / 4f)
                    drawContext.canvas.nativeCanvas.drawLine(
                        paddingLeft, y, paddingLeft + chartW, y, gridPaint
                    )
                }

                // Cadence line
                val cadencePath = Path()
                dataPoints.forEachIndexed { i, dp ->
                    val x = paddingLeft + stepX * i
                    val y = normalizeToCadenceRange(dp.cadenceSPM)
                    if (i == 0) cadencePath.moveTo(x, y) else cadencePath.lineTo(x, y)
                }
                drawPath(
                    path = cadencePath,
                    color = CadenceColor.copy(alpha = 0.7f),
                    style = Stroke(width = 2f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )

                // Amplitude line
                val amplitudePath = Path()
                dataPoints.forEachIndexed { i, dp ->
                    val x = paddingLeft + stepX * i
                    val y = normalizeToAmplitudeRange(dp.amplitudeCm)
                    if (i == 0) amplitudePath.moveTo(x, y) else amplitudePath.lineTo(x, y)
                }
                drawPath(
                    path = amplitudePath,
                    color = AmplitudeColor.copy(alpha = 0.7f),
                    style = Stroke(width = 2f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )

                // GCT line
                val gctPath = Path()
                dataPoints.forEachIndexed { i, dp ->
                    val x = paddingLeft + stepX * i
                    val y = normalizeToGCTRange(dp.gctMs)
                    if (i == 0) gctPath.moveTo(x, y) else gctPath.lineTo(x, y)
                }
                drawPath(
                    path = gctPath,
                    color = GCTColor.copy(alpha = 0.7f),
                    style = Stroke(
                        width = 2f,
                        cap = StrokeCap.Round,
                        join = StrokeJoin.Round,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 4f), 0f)
                    )
                )

                // Draw current time cursor
                if (currentIndex in dataPoints.indices) {
                    val cursorX = paddingLeft + stepX * currentIndex
                    drawLine(
                        color = Color.White.copy(alpha = 0.6f),
                        start = Offset(cursorX, paddingTop),
                        end = Offset(cursorX, paddingTop + chartH),
                        strokeWidth = 2f,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 4f), 0f)
                    )
                }

                // Draw coach prompt markers on timeline
                val promptPaint = android.graphics.Paint().apply {
                    color = android.graphics.Color.parseColor("#FFFF9E38")
                    textSize = 14f
                    isAntiAlias = true
                }
                val totalSec = dataPoints.lastOrNull()?.elapsedSeconds ?: 0.0
                coachPrompts.forEach { prompt ->
                    if (totalSec > 0) {
                        val frac = (prompt.elapsedSeconds / totalSec).toFloat().coerceIn(0f, 1f)
                        val px = paddingLeft + frac * chartW
                        drawCircle(
                            color = ReplayOrange,
                            radius = 4f,
                            center = Offset(px, paddingTop + chartH - 6f)
                        )
                        // Small label
                        drawContext.canvas.nativeCanvas.drawText(
                            "💬",
                            px - 8f,
                            paddingTop + chartH - 10f,
                            promptPaint
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChartLegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(color)
        )
        Spacer(Modifier.width(4.dp))
        Text(
            text = label,
            color = ReplayTextSecondary,
            fontSize = 10.sp
        )
    }
}

// ── (F) Coach Prompt List ─────────────────────────────────────────────────────

@Composable
private fun CoachPromptList(
    prompts: List<SessionCoachPrompt>,
    currentElapsed: Double
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ReplayCardSurface)
            .border(0.5.dp, ReplayCardBorder, RoundedCornerShape(16.dp))
            .padding(12.dp)
    ) {
        Column {
            Text(
                text = stringResource(R.string.replay_coach_prompts).uppercase(),
                color = ReplayTextMuted,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.2.sp,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            prompts.forEach { prompt ->
                val isPast = prompt.elapsedSeconds <= currentElapsed
                val alpha = if (isPast) 1f else 0.4f
                val elapsedTotal = prompt.elapsedSeconds.toInt()
                val promptMin = elapsedTotal / 60
                val promptSec = elapsedTotal % 60

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    // Time badge
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(
                                if (isPast) ReplayOrange.copy(alpha = 0.15f)
                                else ReplayTextMuted.copy(alpha = 0.1f)
                            )
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.replay_time_min_sec, promptMin, promptSec),
                            color = if (isPast) ReplayOrange.copy(alpha = alpha) else ReplayTextMuted,
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = prompt.text,
                        color = Color.White.copy(alpha = alpha),
                        fontSize = 13.sp,
                        lineHeight = 18.sp,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}
