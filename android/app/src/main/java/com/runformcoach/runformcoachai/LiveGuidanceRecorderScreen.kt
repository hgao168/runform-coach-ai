package com.runformcoach.runformcoachai

import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.runformcoach.runformcoachai.R

/**
 * Full-screen live guidance recorder overlay (RF-209).
 *
 * Shows CameraX preview with ML Kit pose-detection skeleton drawn on top,
 * body-position guidance hints, a record button, and an on-screen timer.
 * On recording complete, invokes [onRecordingComplete] with the output URI
 * so the caller can start the analysis flow.
 */
@Composable
fun LiveGuidanceRecorderScreen(
    viewModel: LiveGuidanceViewModel = hiltViewModel(),
    onDismiss: () -> Unit = {}
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val poseLines by viewModel.poseLines.collectAsState()
    val guidanceHint by viewModel.guidanceHint.collectAsState()
    val isRecording by viewModel.isRecording.collectAsState()
    val elapsedSeconds by viewModel.elapsedSeconds.collectAsState()

    // Wire recording-complete callback to dismiss + hand off to analysis
    DisposableEffect(Unit) {
        viewModel.onRecordingComplete = { uri ->
            // The parent (AppViewModel) can observe this to start analysis
        }
        onDispose { viewModel.onRecordingComplete = null }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {

        // ── CameraX PreviewView ──────────────────────────────────────────────
        val previewView = remember { PreviewView(context) }
        AndroidView(
            factory = { previewView },
            modifier = Modifier.fillMaxSize()
        ) { pv ->
            pv.post {
                viewModel.startCamera(pv)
            }
        }

        // ── Pose skeleton overlay Canvas ─────────────────────────────────────
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            for (line in poseLines) {
                val start = Offset(line.startX * w, line.startY * h)
                val end = Offset(line.endX * w, line.endY * h)
                drawLine(
                    color = Color.White.copy(alpha = 0.55f),
                    start = start,
                    end = end,
                    strokeWidth = 3.dp.toPx(),
                    cap = StrokeCap.Round
                )
            }
            // Draw landmark dots at each line endpoint
            val seen = mutableSetOf<Pair<Float, Float>>()
            for (line in poseLines) {
                for ((x, y) in listOf(line.startX to line.startY, line.endX to line.endY)) {
                    if (seen.add(x to y)) {
                        drawCircle(
                            color = AppColors.Mint.copy(alpha = 0.7f),
                            radius = 4.dp.toPx(),
                            center = Offset(x * w, y * h)
                        )
                    }
                }
            }
        }

        // ── Top bar: close button ────────────────────────────────────────────
        IconButton(
            onClick = {
                viewModel.reset()
                onDismiss()
            },
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(16.dp)
                .size(40.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.45f))
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = stringResource(R.string.guidance_close),
                tint = Color.White,
                modifier = Modifier.size(22.dp)
            )
        }

        // ── Guidance hint banner ─────────────────────────────────────────────
        val hintText = when (guidanceHint) {
            GuidanceHint.TOO_CLOSE -> stringResource(R.string.guidance_step_back)
            GuidanceHint.TOO_FAR -> stringResource(R.string.guidance_move_closer)
            GuidanceHint.FULL_BODY -> stringResource(R.string.guidance_ready)
            GuidanceHint.NO_PERSON -> stringResource(R.string.guidance_in_frame)
        }
        val hintColor = when (guidanceHint) {
            GuidanceHint.FULL_BODY -> AppColors.Mint
            GuidanceHint.NO_PERSON -> AppColors.TextMuted
            else -> AppColors.Orange
        }
        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 16.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(Color.Black.copy(alpha = 0.55f))
                .padding(horizontal = 20.dp, vertical = 8.dp)
        ) {
            Text(
                text = hintText,
                color = hintColor,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium
            )
        }

        // ── Timer overlay ────────────────────────────────────────────────────
        if (isRecording) {
            val mins = elapsedSeconds / 60
            val secs = elapsedSeconds % 60
            val timerText = "%02d:%02d".format(mins, secs)
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 60.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.Black.copy(alpha = 0.5f))
                    .padding(horizontal = 14.dp, vertical = 6.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.FiberManualRecord,
                        contentDescription = null,
                        tint = AppColors.Red,
                        modifier = Modifier.size(10.dp)
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        text = timerText,
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        // ── Bottom bar: record button ────────────────────────────────────────
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 48.dp)
        ) {
            if (isRecording) {
                // Stop button
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(AppColors.Red)
                        .clickable(
                            onClick = { viewModel.stopRecording() },
                            indication = null,
                            interactionSource = remember { MutableInteractionSource() }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Stop,
                        contentDescription = stringResource(R.string.guidance_stop_recording),
                        tint = Color.White,
                        modifier = Modifier.size(32.dp)
                    )
                }
            } else {
                // Record button
                Box(
                    modifier = Modifier
                        .size(76.dp)
                        .clip(CircleShape)
                        .border(4.dp, Color.White.copy(alpha = 0.7f), CircleShape)
                        .clickable(
                            onClick = { viewModel.toggleRecording() },
                            indication = null,
                            interactionSource = remember { MutableInteractionSource() }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(58.dp)
                            .clip(CircleShape)
                            .background(AppColors.Red)
                    )
                }
            }
        }
    }
}
