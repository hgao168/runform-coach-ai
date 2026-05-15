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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.VideoFile
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel

/**
 * Full Compare screen with two tabs: Elite Athletes and Custom Compare.
 * Replaces the sprint-1 placeholder.
 */
@Composable
fun CompareScreen(
    vm: AppViewModel,
    compareVm: CompareViewModel = hiltViewModel()
) {
    var selectedTab by remember { mutableStateOf(0) } // 0 = elite, 1 = custom
    val athleteListState by compareVm.athleteListState.collectAsState()
    val historyItems by compareVm.historyItems.collectAsState()
    val compareResultState by compareVm.compareResultState.collectAsState()
    val selectedAthleteName by compareVm.selectedAthleteName.collectAsState()
    val selectedHistoryA by compareVm.selectedHistoryA.collectAsState()
    val selectedHistoryB by compareVm.selectedHistoryB.collectAsState()
    val customCompareResultState by compareVm.customCompareResultState.collectAsState()
    val hasAnalysis = vm.history.isNotEmpty()

    // Show result overlay when comparison completes
    val showResult = compareResultState is CompareResultState.Success
    val showCustomResult = customCompareResultState is CompareResultState.Success

    if (showResult && compareResultState is CompareResultState.Success) {
        CompareResultScreen(
            result = (compareResultState as CompareResultState.Success).result,
            athleteName = selectedAthleteName ?: "",
            onClose = { compareVm.resetCompare() }
        )
        return
    }

    if (showCustomResult && customCompareResultState is CompareResultState.Success) {
        CompareResultScreen(
            result = (customCompareResultState as CompareResultState.Success).result,
            athleteName = "Custom Compare",
            onClose = { compareVm.resetCustomCompare() }
        )
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Hero ───────────────────────────────────────────────────────────────
        item {
            Column {
                Text(
                    text = stringResource(R.string.compare_with_elite),
                    color = Color.White,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = stringResource(R.string.compare_subtitle),
                    color = AppColors.TextSecondary,
                    fontSize = 14.sp
                )
            }
        }

        // ── Tab switcher ───────────────────────────────────────────────────────
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                TabChip(
                    text = stringResource(R.string.elite_athletes_tab),
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    modifier = Modifier.weight(1f)
                )
                TabChip(
                    text = stringResource(R.string.custom_compare_tab),
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // ── Tab content ────────────────────────────────────────────────────────
        if (selectedTab == 0) {
            eliteTabContent(athleteListState, compareVm, vm, hasAnalysis)
        } else {
            customTabContent(historyItems, selectedHistoryA, selectedHistoryB, compareVm, vm)
        }
    }
}

// ── Elite athletes tab ─────────────────────────────────────────────────────────

private fun LazyColumnScope.eliteTabContent(
    state: AthleteListState,
    compareVm: CompareViewModel,
    vm: AppViewModel,
    hasAnalysis: Boolean
) {
    when (state) {
        is AthleteListState.Loading -> {
            item {
                Box(
                    modifier = Modifier.fillMaxWidth().height(200.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = AppColors.Mint, modifier = Modifier.size(40.dp))
                }
            }
        }

        is AthleteListState.Error -> {
            item {
                ErrorCard(
                    title = stringResource(R.string.couldnt_load_athletes),
                    message = state.message,
                    onRetry = { compareVm.loadAthletes() }
                )
            }
        }

        is AthleteListState.Success -> {
            if (!hasAnalysis) {
                item {
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.VideoFile,
                                contentDescription = null,
                                tint = AppColors.TextMuted,
                                modifier = Modifier.size(48.dp)
                            )
                            Text(
                                text = stringResource(R.string.no_analyses_yet),
                                color = AppColors.TextSecondary,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = stringResource(R.string.go_to_analyze),
                                color = AppColors.TextMuted,
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }

            item {
                SectionTitle(stringResource(R.string.pick_an_athlete))
            }

            items(state.athletes) { athlete ->
                AthleteRowView(
                    athlete = athlete,
                    onClick = {
                        // Use latest analysis from AppViewModel history
                        val latest = vm.history.firstOrNull()
                        if (latest != null) {
                            compareVm.compareWithAthlete(athlete, latest.result)
                        }
                    }
                )
            }
        }
    }

    item { Spacer(Modifier.height(32.dp)) }
}

// ── Custom compare tab ─────────────────────────────────────────────────────────

private fun LazyColumnScope.customTabContent(
    historyItems: List<AnalysisHistoryItem>,
    selectedA: AnalysisHistoryItem?,
    selectedB: AnalysisHistoryItem?,
    compareVm: CompareViewModel,
    vm: AppViewModel
) {
    item {
        Text(
            text = stringResource(R.string.select_two_analyses_desc),
            color = AppColors.TextSecondary,
            fontSize = 14.sp,
            lineHeight = 20.sp
        )
    }

    if (historyItems.isEmpty()) {
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.VideoFile,
                        contentDescription = null,
                        tint = AppColors.TextMuted,
                        modifier = Modifier.size(48.dp)
                    )
                    Text(
                        text = stringResource(R.string.no_analyses_yet),
                        color = AppColors.TextSecondary,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = stringResource(R.string.go_to_analyze),
                        color = AppColors.TextMuted,
                        fontSize = 13.sp
                    )
                }
            }
        }
    }

    // Show selection status
    item {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            SelectionSlot(
                label = "A",
                item = selectedA,
                modifier = Modifier.weight(1f)
            )
            SelectionSlot(
                label = "B",
                item = selectedB,
                modifier = Modifier.weight(1f)
            )
        }
    }

    // Run comparison button
    if (selectedA != null && selectedB != null) {
        item {
            androidx.compose.material3.Button(
                onClick = { compareVm.runCustomCompare() },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                    containerColor = AppColors.Mint,
                    contentColor = Color.Black
                )
            ) {
                Text(stringResource(R.string.compare_selected), fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }

    // History list for selection
    if (historyItems.isNotEmpty()) {
        item {
            Spacer(Modifier.height(4.dp))
            SectionTitle(stringResource(R.string.your_analyses))
        }

        items(historyItems) { item ->
            val isSelected = item.id == selectedA?.id || item.id == selectedB?.id
            val label = when {
                item.id == selectedA?.id -> "A"
                item.id == selectedB?.id -> "B"
                else -> null
            }
            CustomCompareHistoryRow(
                item = item,
                isSelected = isSelected,
                selectionLabel = label,
                onClick = { compareVm.selectHistoryItem(item) }
            )
        }
    }

    item { Spacer(Modifier.height(32.dp)) }
}

// ── Shared composables ────────────────────────────────────────────────────────

@Composable
fun AthleteRowView(
    athlete: AthleteListItem,
    onClick: () -> Unit
) {
    val initials = athlete.name
        .split(" ")
        .mapNotNull { it.firstOrNull()?.toString() }
        .take(2)
        .joinToString("")

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.Ink)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Avatar with initials
        Box(
            modifier = Modifier
                .size(50.dp)
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(
                        colors = listOf(AppColors.Mint, AppColors.Cyan)
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = initials,
                color = Color.Black,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = athlete.name,
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = athlete.event,
                color = AppColors.Mint,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = athlete.achievement,
                color = AppColors.TextSecondary,
                fontSize = 12.sp,
                lineHeight = 16.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.TextMuted,
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun TabChip(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) AppColors.Mint.copy(alpha = 0.15f) else AppColors.Card)
            .border(
                width = if (selected) 1.5.dp else 0.5.dp,
                color = if (selected) AppColors.Mint.copy(alpha = 0.6f) else AppColors.Border,
                shape = RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = if (selected) AppColors.Mint else AppColors.TextSecondary,
            fontSize = 14.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium
        )
    }
}

@Composable
private fun ErrorCard(title: String, message: String, onRetry: () -> Unit) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = Icons.Default.VideoFile,
                contentDescription = null,
                tint = AppColors.Orange,
                modifier = Modifier.size(40.dp)
            )
            Text(title, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(message, color = AppColors.TextSecondary, fontSize = 13.sp)
            TextButton(onClick = onRetry) {
                Text(stringResource(R.string.retry), color = AppColors.Mint)
            }
        }
    }
}

@Composable
private fun SelectionSlot(
    label: String,
    item: AnalysisHistoryItem?,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (item != null) AppColors.Mint.copy(alpha = 0.1f) else AppColors.Card)
            .border(
                width = if (item != null) 1.5.dp else 0.5.dp,
                color = if (item != null) AppColors.Mint.copy(alpha = 0.5f) else AppColors.Border,
                shape = RoundedCornerShape(12.dp)
            )
            .padding(12.dp)
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(label, color = AppColors.Mint, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            if (item != null) {
                Text(
                    text = item.result.summary,
                    color = Color.White,
                    fontSize = 12.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = "${(item.result.confidence * 100).toInt()}%",
                    color = AppColors.Mint,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
            } else {
                Text(
                    text = stringResource(R.string.select_analysis),
                    color = AppColors.TextMuted,
                    fontSize = 12.sp
                )
            }
        }
    }
}

@Composable
private fun CustomCompareHistoryRow(
    item: AnalysisHistoryItem,
    isSelected: Boolean,
    selectionLabel: String?,
    onClick: () -> Unit
) {
    val dateStr = remember(item.createdAt) {
        java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.getDefault())
            .format(java.util.Date(item.createdAt))
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isSelected) AppColors.Mint.copy(alpha = 0.1f) else AppColors.Ink)
            .border(
                width = if (isSelected) 1.5.dp else 0.5.dp,
                color = if (isSelected) AppColors.Mint.copy(alpha = 0.5f) else AppColors.Border,
                shape = RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onClick)
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (selectionLabel != null) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(AppColors.Mint),
                contentAlignment = Alignment.Center
            ) {
                Text(selectionLabel, color = Color.Black, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            }
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(dateStr, color = AppColors.TextSecondary, fontSize = 12.sp)
            Text(
                text = item.result.summary,
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        Text(
            text = "${(item.result.confidence * 100).toInt()}%",
            color = AppColors.Mint,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
