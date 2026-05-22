package com.runformcoach.runformcoachai

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Compare History Screen — browse past analysis records and compare them
 * against elite athletes. Entered from HistoryScreen.
 */
@Composable
fun CompareHistoryScreen(
    vm: AppViewModel,
    compareVm: CompareViewModel = hiltViewModel(),
    onClose: () -> Unit
) {
    val athleteListState by compareVm.athleteListState.collectAsState()
    val compareResultState by compareVm.compareResultState.collectAsState()
    val selectedAthleteName by compareVm.selectedAthleteName.collectAsState()
    val historyItems = vm.history

    // Show result overlay
    val showResult = compareResultState is CompareResultState.Success
    val isLoading = compareResultState is CompareResultState.Loading
    val error = (compareResultState as? CompareResultState.Error)?.message

    if (showResult && compareResultState is CompareResultState.Success) {
        CompareResultScreen(
            result = (compareResultState as CompareResultState.Success).result,
            athleteName = selectedAthleteName ?: "",
            onClose = { compareVm.resetCompare(); onClose() }
        )
        return
    }

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
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.close), tint = AppColors.Mint)
            }
            Text(
                text = stringResource(R.string.compare_with_elite),
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.width(48.dp))
        }

        if (historyItems.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = null,
                        tint = AppColors.TextMuted,
                        modifier = Modifier.size(64.dp)
                    )
                    Text(stringResource(R.string.no_analyses_yet), color = AppColors.TextSecondary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    Text(stringResource(R.string.go_to_analyze), color = AppColors.TextMuted, fontSize = 14.sp)
                }
            }
            return
        }

        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    CircularProgressIndicator(color = AppColors.Mint, modifier = Modifier.size(44.dp))
                    Text(stringResource(R.string.comparing_your_form), color = AppColors.TextSecondary, fontSize = 14.sp)
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
                        imageVector = Icons.Default.Person,
                        contentDescription = null,
                        tint = AppColors.Orange,
                        modifier = Modifier.size(40.dp)
                    )
                    Text(stringResource(R.string.comparison_failed), color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    Text(error, color = AppColors.TextSecondary, fontSize = 13.sp)
                    TextButton(onClick = { compareVm.resetCompare() }) {
                        Text(stringResource(R.string.retry), color = AppColors.Mint)
                    }
                }
            }
            return
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Description
            item {
                Text(
                    text = stringResource(R.string.compare_history_desc),
                    color = AppColors.TextSecondary,
                    fontSize = 14.sp,
                    lineHeight = 20.sp
                )
            }

            // History items
            item { SectionTitle(stringResource(R.string.select_analysis_for_compare)) }

            items(historyItems) { item ->
                HistoryCompareCard(
                    item = item,
                    athletesState = athleteListState,
                    onClick = {
                        // Pick first available athlete or let user choose
                        val athletes = (athleteListState as? AthleteListState.Success)?.athletes
                        if (!athletes.isNullOrEmpty()) {
                            compareVm.compareWithAthleteFromHistory(athletes.first(), item)
                        }
                    }
                )
            }

            // Pick athlete section
            if (athleteListState is AthleteListState.Success) {
                item {
                    Spacer(Modifier.height(8.dp))
                    SectionTitle(stringResource(R.string.pick_an_athlete))
                }
                val athletes = (athleteListState as AthleteListState.Success).athletes
                items(athletes) { athlete ->
                    AthleteRowView(
                        athlete = athlete,
                        onClick = {
                            val latest = historyItems.firstOrNull()
                            if (latest != null) {
                                compareVm.compareWithAthleteFromHistory(athlete, latest)
                            }
                        }
                    )
                }
            }

            item { Spacer(Modifier.height(32.dp)) }
        }
    }
}

@Composable
private fun HistoryCompareCard(
    item: AnalysisHistoryItem,
    athletesState: AthleteListState,
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

    val hasAthletes = athletesState is AthleteListState.Success

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.Ink)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(14.dp))
            .then(
                if (hasAthletes) Modifier.clickable(onClick = onClick)
                else Modifier
            )
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(dateStr, color = AppColors.TextSecondary, fontSize = 11.sp)
            Text(
                text = item.result.summary,
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(ringColor.copy(alpha = 0.2f))
                .border(1.dp, ringColor.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                .padding(horizontal = 10.dp, vertical = 6.dp)
        ) {
            Text("$confidencePct%", color = ringColor, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }

        if (hasAthletes) {
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = AppColors.TextMuted,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}
