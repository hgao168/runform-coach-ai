package com.runformcoach.runformcoachai

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringResource
import androidx.core.content.FileProvider
import java.io.File

private val videoModes = listOf(
    Triple("side", "Side View", "Cadence, overstride, trunk lean"),
    Triple("rear", "Rear View", "Hip stability, knee tracking"),
    Triple("front", "Front View", "Knee valgus, hip symmetry")
)

@Composable
fun AnalyzeScreen(vm: AppViewModel) {
    val context = LocalContext.current

    val pickVideoLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            vm.selectedVideoUri = it
            vm.analysisState = AnalysisState.Idle
        }
    }

    // Create a temp URI for camera capture
    fun createCaptureUri(): Uri {
        val file = File.createTempFile("recording_", ".mp4", context.cacheDir)
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            .also { vm.captureVideoUri = it }
    }

    val captureVideoLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CaptureVideo()
    ) { saved: Boolean ->
        if (saved) {
            vm.captureVideoUri?.let {
                vm.selectedVideoUri = it
                vm.analysisState = AnalysisState.Idle
            }
        }
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Hero header
        item {
            Column {
                Text(
                    text = "RunForm Injury Prevention Coach",
                    color = Color.White,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Upload or record a video — AI checks your form for injury risks",
                    color = AppColors.TextSecondary,
                    fontSize = 14.sp
                )
            }
        }

        // Video Mode selector
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    SectionTitle("Camera Angle")
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        videoModes.forEach { (key, label, _) ->
                            FilterChip(
                                selected = vm.selectedMode == key,
                                onClick = { vm.selectedMode = key },
                                label = { Text(label, fontSize = 12.sp) },
                                modifier = Modifier.weight(1f),
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = AppColors.Mint.copy(alpha = 0.25f),
                                    selectedLabelColor = AppColors.Mint,
                                    containerColor = AppColors.Card,
                                    labelColor = AppColors.TextSecondary
                                ),
                                border = FilterChipDefaults.filterChipBorder(
                                    enabled = true,
                                    selected = vm.selectedMode == key,
                                    selectedBorderColor = AppColors.Mint.copy(alpha = 0.6f),
                                    borderColor = AppColors.Border
                                )
                            )
                        }
                    }
                    // Mode description
                    videoModes.find { it.first == vm.selectedMode }?.let { (_, _, desc) ->
                        Text(
                            text = desc,
                            color = AppColors.TextMuted,
                            fontSize = 12.sp
                        )
                    }
                }
            }
        }

        // Video area
        item {
            val hasVideo = vm.selectedVideoUri != null
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .clip(RoundedCornerShape(16.dp))
                    .background(AppColors.Ink)
                    .border(
                        width = if (hasVideo) 1.5.dp else 0.5.dp,
                        color = if (hasVideo) AppColors.Mint.copy(alpha = 0.6f) else AppColors.Border,
                        shape = RoundedCornerShape(16.dp)
                    )
                    .clickable { pickVideoLauncher.launch("video/*") },
                contentAlignment = Alignment.Center
            ) {
                if (hasVideo) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = AppColors.Mint,
                            modifier = Modifier.size(40.dp)
                        )
                        Text("Video selected", color = AppColors.Mint, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                        Text("Tap to change", color = AppColors.TextMuted, fontSize = 12.sp)
                    }
                } else {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.PlayArrow,
                            contentDescription = null,
                            tint = AppColors.TextMuted,
                            modifier = Modifier.size(48.dp)
                        )
                        Text("Tap to pick video", color = AppColors.TextMuted, fontSize = 14.sp)
                    }
                }
            }
        }

        // Pick / Record buttons
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = { pickVideoLauncher.launch("video/*") },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = AppColors.Cyan),
                    border = androidx.compose.foundation.BorderStroke(1.dp, AppColors.Cyan.copy(alpha = 0.5f))
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Pick Video")
                }
                OutlinedButton(
                    onClick = { captureVideoLauncher.launch(createCaptureUri()) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = AppColors.Violet),
                    border = androidx.compose.foundation.BorderStroke(1.dp, AppColors.Violet.copy(alpha = 0.5f))
                ) {
                    Icon(Icons.Default.Videocam, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Record")
                }
            }
        }

        // ── RF-206: Video Compression ──────────────────────────────────────
        if (vm.selectedVideoUri != null) {
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = stringResource(R.string.compress_video),
                                color = Color.White,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            Switch(
                                checked = vm.shouldCompress,
                                onCheckedChange = { vm.shouldCompress = it },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = AppColors.Mint,
                                    checkedTrackColor = AppColors.Mint.copy(alpha = 0.4f),
                                    uncheckedThumbColor = AppColors.TextMuted,
                                    uncheckedTrackColor = AppColors.Border
                                )
                            )
                        }

                        if (vm.isCompressing) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = stringResource(R.string.compressing_video),
                                        color = AppColors.Cyan,
                                        fontSize = 13.sp
                                    )
                                    Text(
                                        text = "${(vm.compressionProgress * 100).toInt()}%",
                                        color = AppColors.Mint,
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                LinearProgressIndicator(
                                    progress = { vm.compressionProgress },
                                    modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                                    color = AppColors.Mint,
                                    trackColor = AppColors.Border
                                )
                            }
                        } else if (vm.compressionMessage.isNotEmpty()) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = AppColors.Mint,
                                    modifier = Modifier.size(16.dp)
                                )
                                Text(
                                    text = vm.compressionMessage,
                                    color = AppColors.Mint,
                                    fontSize = 12.sp
                                )
                            }
                        } else if (vm.shouldCompress) {
                            Text(
                                text = stringResource(R.string.compress_video),
                                color = AppColors.TextMuted,
                                fontSize = 12.sp
                            )
                        }

                        if (!vm.isCompressing && vm.shouldCompress) {
                            OutlinedButton(
                                onClick = { vm.compressAndAnalyze() },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = vm.selectedVideoUri != null,
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = AppColors.Cyan),
                                border = androidx.compose.foundation.BorderStroke(1.dp, AppColors.Cyan.copy(alpha = 0.4f))
                            ) {
                                Text(stringResource(R.string.compress_video), fontSize = 13.sp)
                            }
                        }
                    }
                }
            }
        }

        // Analyze button
        item {
            val canAnalyze = vm.selectedVideoUri != null && vm.analysisState !is AnalysisState.Loading
            Button(
                onClick = { vm.analyzeVideo() },
                enabled = canAnalyze,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Mint,
                    contentColor = Color.Black,
                    disabledContainerColor = AppColors.Mint.copy(alpha = 0.3f),
                    disabledContentColor = Color.Black.copy(alpha = 0.5f)
                )
            ) {
                if (vm.analysisState is AnalysisState.Loading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = Color.Black,
                        strokeWidth = 2.dp
                    )
                    Spacer(Modifier.width(10.dp))
                    Text("Analyzing...", fontWeight = FontWeight.Bold)
                } else {
                    Text("Analyze Running Form", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
        }

        // Error state
        if (vm.analysisState is AnalysisState.Error) {
            item {
                val msg = (vm.analysisState as AnalysisState.Error).message
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(AppColors.Red.copy(alpha = 0.15f))
                        .border(1.dp, AppColors.Red.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                        .padding(16.dp)
                ) {
                    Text("Error: $msg", color = AppColors.Red, fontSize = 14.sp)
                }
            }
        }

        // Tips card
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    SectionTitle("Recording Tips")
                    val tips = listOf(
                        "Film on a treadmill or flat, consistent surface",
                        "Use good lighting — avoid backlighting",
                        "Keep whole body in frame, 3-5 seconds minimum",
                        "Side view gives the most analysis metrics"
                    )
                    tips.forEach { tip ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(5.dp)
                                    .background(AppColors.Mint, CircleShape)
                            )
                            Spacer(Modifier.width(10.dp))
                            Text(tip, color = AppColors.TextSecondary, fontSize = 13.sp)
                        }
                    }
                }
            }
        }

        // Result
        if (vm.analysisState is AnalysisState.Success) {
            item {
                val result = (vm.analysisState as AnalysisState.Success).result
                AnalysisResultScreen(
                    result = result,
                    onDismiss = { vm.resetAnalysis() }
                )
            }
        }
    }
}
