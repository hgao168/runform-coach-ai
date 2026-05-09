package com.runformcoach.runformcoachai

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun HistoryScreen(vm: AppViewModel) {
    var showClearDialog by remember { mutableStateOf(false) }
    var expandedId by remember { mutableStateOf<String?>(null) }

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
                    Text("No analyses yet", color = AppColors.TextSecondary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    Text("Go to Analyze to get started", color = AppColors.TextMuted, fontSize = 14.sp)
                }
            }
        } else {
            LazyColumn(
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

            // Issue pills
            if (item.result.issues.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
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
            }

            // Expanded result
            if (expanded) {
                AnalysisResultScreen(result = item.result)
            }
        }
    }
}
