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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Compare
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Elite athlete comparison screen — placeholder for Sprint 2 full implementation.
 *
 * Displays a list of elite runner profiles and allows the user to compare
 * their latest form analysis against elite biomechanical benchmarks.
 */
data class EliteAthlete(
    val name: String,
    val discipline: String,
    val benchmarkDescription: String
)

private val eliteAthletes = listOf(
    EliteAthlete("Kipchoge", "Marathon", "World-record marathon efficiency"),
    EliteAthlete("Kipruto", "Half Marathon", "Elite half-marathon cadence and form"),
    EliteAthlete("Kipyegon", "1500m", "Olympic gold 1500m running economy"),
    EliteAthlete("Bekele", "10K", "Legendary 5K/10K form and endurance"),
    EliteAthlete("Hassan", "All-round", "Versatile distance running technique")
)

@Composable
fun CompareScreen(vm: AppViewModel) {
    val context = LocalContext.current
    var selectedAthlete by remember { mutableStateOf<EliteAthlete?>(null) }
    var isLoading by remember { mutableStateOf(false) }
    var comparisonResult by remember { mutableStateOf<String?>(null) }

    val hasAnalysis = vm.history.isNotEmpty()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Hero
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

        // Prerequisite check
        if (!hasAnalysis) {
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Compare,
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

        // Athlete list
        if (hasAnalysis) {
            item {
                SectionTitle(stringResource(R.string.pick_video)) // reuse for athlete picker
            }

            items(eliteAthletes) { athlete ->
                val isSelected = selectedAthlete == athlete
                AthleteCard(
                    athlete = athlete,
                    selected = isSelected,
                    loading = isLoading && isSelected,
                    onClick = {
                        selectedAthlete = athlete
                        isLoading = true
                        // Simulate comparison (placeholder for real API call)
                        comparisonResult = "Comparing your form with ${athlete.name}...\n\n" +
                            "Placeholder — full comparison engine coming in Sprint 2."
                        isLoading = false
                    }
                )
            }
        }

        // Comparison result placeholder
        comparisonResult?.let { result ->
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        SectionTitle(stringResource(R.string.coachs_take))
                        Text(result, color = AppColors.TextSecondary, fontSize = 13.sp, lineHeight = 18.sp)
                    }
                }
            }
        }

        // Bottom spacer
        item { Spacer(Modifier.height(32.dp)) }
    }
}

@Composable
private fun AthleteCard(
    athlete: EliteAthlete,
    selected: Boolean,
    loading: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (selected) AppColors.Mint.copy(alpha = 0.1f) else AppColors.Ink)
            .border(
                width = if (selected) 1.5.dp else 0.5.dp,
                color = if (selected) AppColors.Mint.copy(alpha = 0.6f) else AppColors.Border,
                shape = RoundedCornerShape(14.dp)
            )
            .clickable(enabled = !loading, onClick = onClick)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Avatar placeholder
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(AppColors.Card)
                .border(1.dp, AppColors.Border, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Person,
                contentDescription = null,
                tint = AppColors.Mint,
                modifier = Modifier.size(24.dp)
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(athlete.name, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text(athlete.discipline, color = AppColors.TextMuted, fontSize = 12.sp)
            Text(athlete.benchmarkDescription, color = AppColors.TextSecondary, fontSize = 12.sp, lineHeight = 16.sp)
        }

        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                color = AppColors.Mint,
                strokeWidth = 2.dp
            )
        }
    }
}
