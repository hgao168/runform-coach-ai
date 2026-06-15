package com.runformcoach.runformcoachai

import androidx.compose.animation.animateColorAsState
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
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.runformcoach.runformcoachai.data.SavedPlanEntity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Saved plans list screen displayed within the Plan tab.
 *
 * Shows all plans persisted in Room via [PlanDao], with swipe-to-delete,
 * tap-to-view-detail, and an empty-state guide.
 */
@Composable
fun SavedPlansScreen(
    vm: AppViewModel,
    onBack: () -> Unit,
    onOpenPlan: (SavedPlanEntity) -> Unit
) {
    val plans = vm.savedPlans
    var deleteTarget by remember { mutableStateOf<SavedPlanEntity?>(null) }

    Column(modifier = Modifier.fillMaxSize()) {
        // ── Header ──────────────────────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = stringResource(R.string.back),
                    tint = AppColors.TextSecondary
                )
            }
            Text(
                stringResource(R.string.saved_plans),
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
        }

        if (plans.isEmpty()) {
            // ── Empty state ──────────────────────────────────────────────────
            EmptySavedPlansState()
        } else {
            // ── Plan list ────────────────────────────────────────────────────
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(plans, key = { it.id }) { entity ->
                    val dismissState = rememberSwipeToDismissBoxState(
                        confirmValueChange = {
                            if (it == SwipeToDismissBoxValue.EndToStart) {
                                deleteTarget = entity
                                false // don't dismiss yet — show confirmation
                            } else false
                        }
                    )
                    SwipeToDismissBox(
                        state = dismissState,
                        modifier = Modifier.fillMaxWidth(),
                        backgroundContent = {
                            val bgColor by animateColorAsState(
                                when (dismissState.targetValue) {
                                    SwipeToDismissBoxValue.EndToStart -> AppColors.Red.copy(alpha = 0.3f)
                                    else -> Color.Transparent
                                },
                                label = "swipe-bg"
                            )
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(bgColor)
                                    .padding(horizontal = 20.dp),
                                contentAlignment = Alignment.CenterEnd
                            ) {
                                Icon(
                                    Icons.Default.Delete,
                                    contentDescription = stringResource(R.string.delete_plan),
                                    tint = AppColors.Red
                                )
                            }
                        },
                        enableDismissFromStartToEnd = false,
                        enableDismissFromEndToStart = true
                    ) {
                        SavedPlanCard(
                            entity = entity,
                            onClick = { onOpenPlan(entity) }
                        )
                    }
                }

                // Bottom spacer for nav bar clearance
                item { Spacer(Modifier.height(80.dp)) }
            }
        }
    }

    // ── Delete confirmation dialog ────────────────────────────────────────
    deleteTarget?.let { entity ->
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            containerColor = AppColors.Ink,
            title = {
                Text(
                    stringResource(R.string.delete_plan),
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Text(
                    stringResource(R.string.delete_plan_confirm),
                    color = AppColors.TextSecondary
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteSavedPlan(entity)
                    deleteTarget = null
                }) {
                    Text(stringResource(R.string.delete_all), color = AppColors.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { deleteTarget = null }) {
                    Text(stringResource(R.string.cancel), color = AppColors.TextSecondary)
                }
            }
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun EmptySavedPlansState() {
    Box(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Default.DirectionsRun,
                contentDescription = null,
                tint = AppColors.TextMuted,
                modifier = Modifier.size(56.dp)
            )
            Spacer(Modifier.height(16.dp))
            Text(
                stringResource(R.string.no_saved_plans),
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.height(8.dp))
            Text(
                stringResource(R.string.go_to_plan_to_save),
                color = AppColors.TextSecondary,
                fontSize = 14.sp
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN CARD
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun SavedPlanCard(
    entity: SavedPlanEntity,
    onClick: () -> Unit
) {
    val planSummary = remember(entity) { planSummary(entity) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.Ink)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(14.dp))
            .clickable { onClick() }
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // ── Type badge ──────────────────────────────────────────────────────
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(planSummary.color.copy(alpha = 0.18f))
                .border(1.dp, planSummary.color.copy(alpha = 0.4f), RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                planSummary.typeLabel.take(1).uppercase(),
                color = planSummary.color,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
        }

        // ── Info ────────────────────────────────────────────────────────────
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                planSummary.typeLabel,
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                planSummary.weekInfo?.let {
                    Text(it, color = AppColors.Mint, fontSize = 12.sp)
                }
                Text(
                    stringResource(R.string.saved_plan_date, planSummary.dateStr),
                    color = AppColors.TextSecondary,
                    fontSize = 12.sp
                )
            }
            planSummary.raceInfo?.let {
                Text(it, color = AppColors.TextMuted, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }

        // ── Chevron ─────────────────────────────────────────────────────────
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = AppColors.TextMuted,
            modifier = Modifier.size(20.dp)
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLAN SUMMARY HELPER
// ═══════════════════════════════════════════════════════════════════════════════

private data class PlanSummary(
    val typeLabel: String,
    val color: Color,
    val weekInfo: String?,
    val raceInfo: String?,
    val dateStr: String
)

private fun planSummary(entity: SavedPlanEntity): PlanSummary {
    val gson = Gson()
    val dateStr = runCatching {
        val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        fmt.format(Date(entity.createdAt))
    }.getOrDefault("—")

    val (typeLabel, color) = when (entity.planType) {
        "weekly" -> "Weekly Plan" to AppColors.Mint
        "marathon" -> "Marathon Plan" to AppColors.Cyan
        "race" -> "Race Plan" to AppColors.Violet
        else -> entity.planType to AppColors.TextSecondary
    }

    var weekInfo: String? = null
    var raceInfo: String? = null

    runCatching {
        val plan: TrainingPlanResponse = gson.fromJson(entity.planJson, TrainingPlanResponse::class.java)
        when (entity.planType) {
            "marathon" -> {
                plan.marathonPlan?.let { mp ->
                    weekInfo = "${mp.totalWeeks} weeks"
                    raceInfo = mp.race
                }
            }
            "race" -> {
                plan.racePlan?.let { rp ->
                    weekInfo = "${rp.totalWeeks} weeks"
                    raceInfo = rp.target
                }
            }
            "weekly" -> {
                weekInfo = if (plan.workouts.isNotEmpty())
                    "${plan.workouts.size} workouts"
                else
                    "${plan.runningDays} run days"
            }
        }
    }

    return PlanSummary(
        typeLabel = typeLabel,
        color = color,
        weekInfo = weekInfo,
        raceInfo = raceInfo,
        dateStr = dateStr
    )
}
