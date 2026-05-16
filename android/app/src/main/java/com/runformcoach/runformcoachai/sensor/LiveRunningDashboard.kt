package com.runformcoach.runformcoachai.sensor

import android.Manifest
import android.content.pm.PackageManager
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.runformcoach.runformcoachai.R
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

// ── Dashboard color palette ─────────────────────────────────────────────────

private val DashboardBg = Color(0xFF0A0A0F)
private val DashboardMint = Color(0xFF00F5A0)
private val StatusRunning = Color(0xFF00F5A0)
private val StatusPaused = Color(0xFFFFC107)
private val StatusStopped = Color(0xFFFF5252)
private val CardSurface = Color(0x14FFFFFF)
private val CardBorder = Color(0x18FFFFFF)

// ── LiveRunningDashboardViewModel ──────────────────────────────────────────

/**
 * ViewModel for the live running dashboard (RF-605).
 *
 * Injects [RunSessionManager] via Hilt and exposes derived [StateFlow]
 * properties for cadence, gait metrics, session state, elapsed time,
 * and coach prompt history. All dashboard composables observe these flows.
 *
 * Usage:
 * ```
 * @Composable
 * fun MyScreen(vm: LiveRunningDashboardViewModel = hiltViewModel()) { ... }
 * ```
 */
@HiltViewModel
class LiveRunningDashboardViewModel @Inject constructor(
    private val sessionManager: RunSessionManager
) : ViewModel() {

    // ── Derived metric state ───────────────────────────────────────────────

    private val _cadenceSPM = MutableStateFlow(0.0)
    val cadenceSPM: StateFlow<Double> = _cadenceSPM.asStateFlow()

    private val _verticalOscillationCm = MutableStateFlow(0.0)
    val verticalOscillationCm: StateFlow<Double> = _verticalOscillationCm.asStateFlow()

    private val _groundContactTimeMs = MutableStateFlow(0.0)
    val groundContactTimeMs: StateFlow<Double> = _groundContactTimeMs.asStateFlow()

    private val _trunkLeanDegrees = MutableStateFlow(0.0)
    val trunkLeanDegrees: StateFlow<Double> = _trunkLeanDegrees.asStateFlow()

    /** Passthrough to [RunSessionManager.state]. */
    val sessionState: StateFlow<RunSessionState> = sessionManager.state

    /** Passthrough to [RunSessionManager.elapsedSeconds]. */
    val elapsedSeconds: StateFlow<Double> = sessionManager.elapsedSeconds

    /** Passthrough to [RunSessionManager.promptHistory]. */
    val promptHistory: StateFlow<List<CoachPrompt>> = sessionManager.promptHistory

    // ── Initialization ─────────────────────────────────────────────────────

    init {
        // Hook into the RunSessionManager metrics callback to derive local StateFlows.
        // This decouples the dashboard from the internal lateinit cadenceDetector/gaitAnalyzer.
        sessionManager.onMetricsUpdate = { metrics ->
            _cadenceSPM.value = metrics.cadence?.stepsPerMinute ?: _cadenceSPM.value
            metrics.gait?.let { gait ->
                _verticalOscillationCm.value = gait.verticalOscillationCm
                _groundContactTimeMs.value = gait.groundContactTimeMs
                _trunkLeanDegrees.value = gait.trunkLeanDegrees
            }
        }
    }

    // ── Session control passthrough ────────────────────────────────────────

    fun start() = sessionManager.start()
    fun pause() = sessionManager.pause()
    fun resume() = sessionManager.resume()
    fun stop() = sessionManager.stop()
}

// ── LiveRunningDashboardScreen ─────────────────────────────────────────────

/**
 * Full-screen live running dashboard composable (RF-605).
 *
 * Displays real-time cadence, gait metrics, elapsed timer, session state,
 * and coach prompt history in a dark dashboard layout with mint-green highlights.
 *
 * Requires BODY_SENSORS and FOREGROUND_SERVICE permissions; shows
 * a permission-request UI if either is missing.
 *
 * @param viewModel  Hilt-injected [LiveRunningDashboardViewModel].
 * @param onDismiss  Called when the user closes the dashboard.
 */
@Composable
fun LiveRunningDashboardScreen(
    viewModel: LiveRunningDashboardViewModel = hiltViewModel(),
    onDismiss: () -> Unit = {}
) {
    val context = LocalContext.current

    // ── Collect state ──────────────────────────────────────────────────────
    val cadence by viewModel.cadenceSPM.collectAsState()
    val verticalOsc by viewModel.verticalOscillationCm.collectAsState()
    val gct by viewModel.groundContactTimeMs.collectAsState()
    val trunkLean by viewModel.trunkLeanDegrees.collectAsState()
    val sessionState by viewModel.sessionState.collectAsState()
    val elapsed by viewModel.elapsedSeconds.collectAsState()
    val prompts by viewModel.promptHistory.collectAsState()

    // ── Permission checks ──────────────────────────────────────────────────
    val hasBodySensors = ContextCompat.checkSelfPermission(
        context, Manifest.permission.BODY_SENSORS
    ) == PackageManager.PERMISSION_GRANTED

    val hasForegroundService = ContextCompat.checkSelfPermission(
        context, Manifest.permission.FOREGROUND_SERVICE
    ) == PackageManager.PERMISSION_GRANTED

    val permissionsGranted = hasBodySensors && hasForegroundService

    // ── Layout ─────────────────────────────────────────────────────────────
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DashboardBg)
    ) {
        if (!permissionsGranted) {
            PermissionRequestUi(onDismiss = onDismiss)
        } else {
            DashboardContent(
                cadence = cadence,
                verticalOsc = verticalOsc,
                gct = gct,
                trunkLean = trunkLean,
                sessionState = sessionState,
                elapsed = elapsed,
                prompts = prompts,
                onStart = viewModel::start,
                onPause = viewModel::pause,
                onResume = viewModel::resume,
                onStop = viewModel::stop,
                onDismiss = onDismiss
            )
        }
    }
}

// ── Permission Request UI ─────────────────────────────────────────────────

/**
 * Shown when BODY_SENSORS or FOREGROUND_SERVICE permissions are not granted.
 */
@Composable
private fun PermissionRequestUi(onDismiss: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = stringResource(R.string.dashboard_permission_body_sensors),
            color = Color.White,
            fontSize = 16.sp,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.dashboard_permission_foreground),
            color = Color(0xA0FFFFFF),
            fontSize = 13.sp,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onDismiss,
            colors = ButtonDefaults.buttonColors(containerColor = DashboardMint)
        ) {
            Text(
                text = stringResource(R.string.dashboard_grant_permission),
                color = Color.Black,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

// ── Dashboard Content ─────────────────────────────────────────────────────

@Composable
private fun DashboardContent(
    cadence: Double,
    verticalOsc: Double,
    gct: Double,
    trunkLean: Double,
    sessionState: RunSessionState,
    elapsed: Double,
    prompts: List<CoachPrompt>,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp)
    ) {
        // ── Top bar: dismiss + status ──────────────────────────────────────
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Status indicator: dot + label
            StatusBadge(sessionState)

            // Close button
            IconButton(onClick = {
                if (sessionState == RunSessionState.running || sessionState == RunSessionState.paused) {
                    onStop()
                }
                onDismiss()
            }) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = stringResource(R.string.close),
                    tint = Color(0xA0FFFFFF),
                    modifier = Modifier.size(24.dp)
                )
            }
        }

        Spacer(Modifier.height(16.dp))

        // ── Timer ──────────────────────────────────────────────────────────
        val mins = (elapsed / 60).toInt()
        val secs = (elapsed % 60).toInt()
        Text(
            text = stringResource(R.string.dashboard_elapsed_format, mins, secs),
            color = Color.White,
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(8.dp))

        // ── Control buttons ────────────────────────────────────────────────
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            when (sessionState) {
                RunSessionState.idle, RunSessionState.ready, RunSessionState.stopped -> {
                    ControlButton(
                        label = stringResource(R.string.dashboard_start),
                        color = DashboardMint,
                        onClick = onStart
                    )
                }
                RunSessionState.running -> {
                    ControlButton(
                        icon = Icons.Default.Pause,
                        label = stringResource(R.string.dashboard_pause),
                        color = StatusPaused,
                        onClick = onPause
                    )
                    Spacer(Modifier.width(16.dp))
                    ControlButton(
                        icon = Icons.Default.Stop,
                        label = stringResource(R.string.dashboard_stop),
                        color = StatusStopped,
                        onClick = onStop
                    )
                }
                RunSessionState.paused -> {
                    ControlButton(
                        icon = Icons.Default.PlayArrow,
                        label = stringResource(R.string.dashboard_resume),
                        color = DashboardMint,
                        onClick = onResume
                    )
                    Spacer(Modifier.width(16.dp))
                    ControlButton(
                        icon = Icons.Default.Stop,
                        label = stringResource(R.string.dashboard_stop),
                        color = StatusStopped,
                        onClick = onStop
                    )
                }
            }
        }

        Spacer(Modifier.height(24.dp))

        // ── Cadence (large, prominent) ─────────────────────────────────────
        Text(
            text = stringResource(R.string.dashboard_cadence).uppercase(),
            color = Color(0x80FFFFFF),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = stringResource(R.string.dashboard_spm, cadence),
            color = DashboardMint,
            fontSize = 64.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(28.dp))

        // ── Metric cards row ───────────────────────────────────────────────
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            MetricCard(
                label = stringResource(R.string.dashboard_vertical_osc),
                value = stringResource(R.string.dashboard_cm, verticalOsc),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                label = stringResource(R.string.dashboard_ground_contact),
                value = stringResource(R.string.dashboard_ms, gct),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                label = stringResource(R.string.dashboard_trunk_lean),
                value = stringResource(R.string.dashboard_deg, trunkLean),
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(28.dp))

        // ── Coach prompt history ───────────────────────────────────────────
        Text(
            text = stringResource(R.string.dashboard_prompt_history).uppercase(),
            color = Color(0x80FFFFFF),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp
        )

        Spacer(Modifier.height(8.dp))

        if (prompts.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = stringResource(R.string.dashboard_no_prompts_yet),
                    color = Color(0x40FFFFFF),
                    fontSize = 14.sp
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                items(
                    items = prompts.reversed(),
                    key = { "prompt_${it.hashCode()}_${prompts.indexOf(it)}" }
                ) { prompt ->
                    PromptRow(prompt)
                }
            }
        }
    }
}

// ── Status Badge ──────────────────────────────────────────────────────────

@Composable
private fun StatusBadge(state: RunSessionState) {
    val (dotColor, labelRes) = when (state) {
        RunSessionState.running -> StatusRunning to R.string.dashboard_running
        RunSessionState.paused -> StatusPaused to R.string.dashboard_paused_label
        RunSessionState.stopped, RunSessionState.idle, RunSessionState.ready ->
            StatusStopped to R.string.dashboard_stopped_label
    }

    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(dotColor)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = stringResource(labelRes),
            color = dotColor,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

// ── Control Button ────────────────────────────────────────────────────────

@Composable
private fun ControlButton(
    label: String,
    color: Color,
    onClick: () -> Unit,
    icon: androidx.compose.ui.graphics.vector.ImageVector? = null
) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = color.copy(alpha = 0.15f),
            contentColor = color
        ),
        shape = RoundedCornerShape(12.dp),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp)
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(6.dp))
        }
        Text(
            text = label,
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp
        )
    }
}

// ── Metric Card ───────────────────────────────────────────────────────────

@Composable
private fun MetricCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(CardSurface)
            .padding(12.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = label,
                color = Color(0x80FFFFFF),
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                letterSpacing = 0.5.sp,
                textAlign = TextAlign.Center,
                maxLines = 1
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = value,
                color = DashboardMint,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center,
                maxLines = 1
            )
        }
    }
}

// ── Prompt Row ────────────────────────────────────────────────────────────

@Composable
private fun PromptRow(prompt: CoachPrompt) {
    val categoryColor = when (prompt.category) {
        CoachCategory.cadence -> DashboardMint
        CoachCategory.verticalOscillation -> Color(0xFF40BFFF)
        CoachCategory.groundContactTime -> Color(0xFFFFB347)
        CoachCategory.trunkLean -> Color(0xFFD47FFF)
        CoachCategory.general -> Color(0xA0FFFFFF)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(CardSurface)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .width(3.dp)
                .height(28.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(categoryColor)
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = prompt.text,
            color = Color(0xE0FFFFFF),
            fontSize = 13.sp,
            lineHeight = 18.sp,
            modifier = Modifier.weight(1f)
        )
    }
}
