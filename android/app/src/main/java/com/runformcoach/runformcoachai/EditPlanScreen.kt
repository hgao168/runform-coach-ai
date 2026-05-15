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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.runformcoach.runformcoachai.data.PlanDao
import com.runformcoach.runformcoachai.data.SavedPlanEntity
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

// ═══════════════════════════════════════════════════════════════════════════════
// VIEW MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/** Available training workout types for the edit form dropdown. */
private val WORKOUT_TYPES = listOf(
    "Easy Run",
    "Intervals",
    "LSD / Long Run",
    "Pace Run / Tempo",
    "Recovery",
    "Strength",
    "Cross-Training"
)

/** Map display names back to canonical category values stored in PlannedWorkout.category. */
private val WORKOUT_TYPE_TO_CATEGORY = mapOf(
    "Easy Run" to "Easy Run",
    "Intervals" to "Intervals",
    "LSD / Long Run" to "Long Run",
    "Pace Run / Tempo" to "Tempo Run",
    "Recovery" to "Recovery",
    "Strength" to "Strength & Mobility",
    "Cross-Training" to "Cross-Training"
)

private val CATEGORY_TO_WORKOUT_TYPE = mapOf(
    "Easy Run" to "Easy Run",
    "easy run" to "Easy Run",
    "easy" to "Easy Run",
    "Intervals" to "Intervals",
    "intervals" to "Intervals",
    "interval" to "Intervals",
    "speed" to "Intervals",
    "Long Run" to "LSD / Long Run",
    "long run" to "LSD / Long Run",
    "long" to "LSD / Long Run",
    "Tempo Run" to "Pace Run / Tempo",
    "tempo run" to "Pace Run / Tempo",
    "tempo" to "Pace Run / Tempo",
    "Recovery" to "Recovery",
    "recovery" to "Recovery",
    "rest" to "Recovery",
    "Strength & Mobility" to "Strength",
    "strength & mobility" to "Strength",
    "strength" to "Strength",
    "mobility" to "Strength",
    "Cross-Training" to "Cross-Training",
    "cross-training" to "Cross-Training",
    "cross training" to "Cross-Training"
)

@HiltViewModel
class EditPlanViewModel @Inject constructor(
    private val planDao: PlanDao
) : ViewModel() {

    private val gson = Gson()

    // ── State ──────────────────────────────────────────────────────────────

    /** The Room entity being edited. */
    var entity by mutableStateOf<SavedPlanEntity?>(null)
        private set

    /** Parsed plan from entity JSON. */
    var parsedPlan by mutableStateOf<TrainingPlanResponse?>(null)
        private set

    /** 0-based week index (only meaningful for marathon/race plans). */
    var selectedWeekIndex by mutableStateOf(0)

    /** Index of the workout currently being edited (-1 = adding new). */
    var editingWorkoutIndex by mutableStateOf(-1)

    // ── Form fields ────────────────────────────────────────────────────────

    var editType by mutableStateOf("Easy Run")
    var editDistance by mutableStateOf("")
    var editDuration by mutableStateOf("")
    var editTitle by mutableStateOf("")
    var editDetails by mutableStateOf("")
    var editIntensity by mutableStateOf("Medium")

    /** Whether the edit form dialog is visible. */
    var showEditDialog by mutableStateOf(false)

    /** Snackbar / toast message. */
    var statusMessage by mutableStateOf<String?>(null)

    // ── Computed ───────────────────────────────────────────────────────────

    /** Weeks available for editing (marathon/race) or null (weekly plan). */
    val availableWeeks: List<Int>?
        get() {
            val plan = parsedPlan ?: return null
            val weeks = plan.marathonPlan?.weeks ?: plan.racePlan?.weeks ?: return null
            return weeks.map { it.week }.sorted()
        }

    /** Workouts for the currently selected week/day. */
    val currentWorkouts: List<PlannedWorkout>
        get() {
            val plan = parsedPlan ?: return emptyList()
            val marathon = plan.marathonPlan
            val race = plan.racePlan
            return when {
                marathon != null -> {
                    val sorted = marathon.weeks.sortedBy { it.week }
                    sorted.getOrNull(selectedWeekIndex)?.workouts ?: emptyList()
                }
                race != null -> {
                    val sorted = race.weeks.sortedBy { it.week }
                    sorted.getOrNull(selectedWeekIndex)?.workouts ?: emptyList()
                }
                else -> plan.workouts // weekly plan: all workouts
            }
        }

    val isWeekBased: Boolean
        get() = parsedPlan?.marathonPlan != null || parsedPlan?.racePlan != null

    // ── Actions ────────────────────────────────────────────────────────────

    fun loadPlan(entity: SavedPlanEntity) {
        this.entity = entity
        runCatching {
            val plan: TrainingPlanResponse = gson.fromJson(entity.planJson, TrainingPlanResponse::class.java)
            parsedPlan = plan
            selectedWeekIndex = 0
            editingWorkoutIndex = -1
            showEditDialog = false
        }
    }

    fun selectWeek(index: Int) {
        selectedWeekIndex = index
        editingWorkoutIndex = -1
        showEditDialog = false
    }

    /** Open the edit form for an existing workout. */
    fun startEditWorkout(workoutIndex: Int) {
        val workouts = currentWorkouts
        if (workoutIndex >= workouts.size) return
        val wo = workouts[workoutIndex]
        editingWorkoutIndex = workoutIndex
        editType = CATEGORY_TO_WORKOUT_TYPE[wo.category] ?: wo.category
        editDistance = wo.distanceKm?.toString() ?: ""
        editDuration = wo.durationMinutes?.toString() ?: ""
        editTitle = wo.title
        editDetails = wo.details
        editIntensity = wo.intensity
        showEditDialog = true
    }

    /** Open the edit form for adding a new workout. */
    fun startAddWorkout() {
        editingWorkoutIndex = -1
        editType = "Easy Run"
        editDistance = ""
        editDuration = ""
        editTitle = ""
        editDetails = ""
        editIntensity = "Medium"
        showEditDialog = true
    }

    fun dismissEdit() {
        showEditDialog = false
        editingWorkoutIndex = -1
    }

    /** Save the currently edited workout (create or update). */
    fun saveWorkout() {
        val ent = entity ?: return
        val plan = parsedPlan ?: return

        val distance = editDistance.toDoubleOrNull()
        val duration = editDuration.toIntOrNull()

        // Determine day abbreviation from index or existing workout day
        val dayLabels = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        val existingWorkouts = currentWorkouts
        val day = if (editingWorkoutIndex >= 0 && editingWorkoutIndex < existingWorkouts.size) {
            existingWorkouts[editingWorkoutIndex].day
        } else {
            // New workout: use next available day or default
            val usedDays = existingWorkouts.map { it.day.take(3).lowercase() }.toSet()
            dayLabels.firstOrNull { it.lowercase() !in usedDays } ?: "Mon"
        }

        val category = WORKOUT_TYPE_TO_CATEGORY[editType] ?: editType
        val workout = PlannedWorkout(
            day = day,
            title = editTitle.ifBlank { editType },
            category = category,
            intensity = editIntensity,
            details = editDetails.ifBlank { "$editType — ${distance ?: "?"} km" },
            purpose = "",
            distanceKm = distance,
            durationMinutes = duration,
            coachingFocus = null
        )

        runCatching {
            val updatedPlan = when {
                plan.marathonPlan != null -> {
                    val weeks = plan.marathonPlan.weeks.toMutableList()
                    val sorted = weeks.sortedBy { it.week }.toMutableList()
                    if (selectedWeekIndex < sorted.size) {
                        val oldWeek = sorted[selectedWeekIndex]
                        val workouts = oldWeek.workouts.toMutableList()
                        if (editingWorkoutIndex >= 0 && editingWorkoutIndex < workouts.size) {
                            workouts[editingWorkoutIndex] = workout
                        } else {
                            workouts.add(workout)
                        }
                        sorted[selectedWeekIndex] = oldWeek.copy(workouts = workouts)
                    }
                    plan.copy(marathonPlan = plan.marathonPlan.copy(weeks = sorted))
                }
                plan.racePlan != null -> {
                    val weeks = plan.racePlan.weeks.toMutableList()
                    val sorted = weeks.sortedBy { it.week }.toMutableList()
                    if (selectedWeekIndex < sorted.size) {
                        val oldWeek = sorted[selectedWeekIndex]
                        val workouts = oldWeek.workouts.toMutableList()
                        if (editingWorkoutIndex >= 0 && editingWorkoutIndex < workouts.size) {
                            workouts[editingWorkoutIndex] = workout
                        } else {
                            workouts.add(workout)
                        }
                        sorted[selectedWeekIndex] = oldWeek.copy(workouts = workouts)
                    }
                    plan.copy(racePlan = plan.racePlan.copy(weeks = sorted))
                }
                else -> {
                    // Weekly plan: replace workouts list
                    val workouts = plan.workouts.toMutableList()
                    if (editingWorkoutIndex >= 0 && editingWorkoutIndex < workouts.size) {
                        workouts[editingWorkoutIndex] = workout
                    } else {
                        workouts.add(workout)
                    }
                    plan.copy(workouts = workouts)
                }
            }

            viewModelScope.launch(Dispatchers.IO) {
                planDao.insert(
                    ent.copy(
                        planJson = gson.toJson(updatedPlan),
                        createdAt = System.currentTimeMillis()
                    )
                )
                withContext(Dispatchers.Main) {
                    parsedPlan = updatedPlan
                    showEditDialog = false
                    editingWorkoutIndex = -1
                    statusMessage = "Workout saved"
                }
            }
        }.onFailure {
            statusMessage = "Save failed: ${it.message}"
        }
    }

    /** Delete a workout from the current week/day. */
    fun deleteWorkout(workoutIndex: Int) {
        val ent = entity ?: return
        val plan = parsedPlan ?: return

        runCatching {
            val updatedPlan = when {
                plan.marathonPlan != null -> {
                    val weeks = plan.marathonPlan.weeks.toMutableList()
                    val sorted = weeks.sortedBy { it.week }.toMutableList()
                    if (selectedWeekIndex < sorted.size) {
                        val oldWeek = sorted[selectedWeekIndex]
                        val workouts = oldWeek.workouts.toMutableList()
                        if (workoutIndex < workouts.size) {
                            workouts.removeAt(workoutIndex)
                        }
                        sorted[selectedWeekIndex] = oldWeek.copy(workouts = workouts)
                    }
                    plan.copy(marathonPlan = plan.marathonPlan.copy(weeks = sorted))
                }
                plan.racePlan != null -> {
                    val weeks = plan.racePlan.weeks.toMutableList()
                    val sorted = weeks.sortedBy { it.week }.toMutableList()
                    if (selectedWeekIndex < sorted.size) {
                        val oldWeek = sorted[selectedWeekIndex]
                        val workouts = oldWeek.workouts.toMutableList()
                        if (workoutIndex < workouts.size) {
                            workouts.removeAt(workoutIndex)
                        }
                        sorted[selectedWeekIndex] = oldWeek.copy(workouts = workouts)
                    }
                    plan.copy(racePlan = plan.racePlan.copy(weeks = sorted))
                }
                else -> {
                    val workouts = plan.workouts.toMutableList()
                    if (workoutIndex < workouts.size) {
                        workouts.removeAt(workoutIndex)
                    }
                    plan.copy(workouts = workouts)
                }
            }

            viewModelScope.launch(Dispatchers.IO) {
                planDao.insert(
                    ent.copy(
                        planJson = gson.toJson(updatedPlan),
                        createdAt = System.currentTimeMillis()
                    )
                )
                withContext(Dispatchers.Main) {
                    parsedPlan = updatedPlan
                    statusMessage = "Workout deleted"
                }
            }
        }.onFailure {
            statusMessage = "Delete failed: ${it.message}"
        }
    }

    fun clearStatus() { statusMessage = null }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN COMPOSABLE
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Edit training plan screen.
 *
 * For marathon/race plans: shows a week selector and the workouts for that week.
 * For weekly plans: shows all workouts directly.
 * Tap a workout to edit, swipe/long-press to delete, or tap + to add.
 *
 * Uses [EditPlanViewModel] (Hilt-injected) for Room persistence.
 */
@Composable
fun EditPlanScreen(
    planEntity: SavedPlanEntity,
    onBack: () -> Unit,
    editVm: EditPlanViewModel = hiltViewModel()
) {
    // Load plan on first composition
    LaunchedEffect(planEntity.id) {
        editVm.loadPlan(planEntity)
    }

    val plan = editVm.parsedPlan
    val workouts = editVm.currentWorkouts
    var deleteIndex by remember { mutableStateOf<Int?>(null) }

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
                stringResource(R.string.edit_day_title),
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.weight(1f))
            if (plan != null) {
                IconButton(onClick = { editVm.startAddWorkout() }) {
                    Icon(
                        Icons.Default.Add,
                        contentDescription = stringResource(R.string.add_training_day),
                        tint = AppColors.Mint
                    )
                }
            }
        }

        if (plan == null) {
            // ── Loading / error state ──────────────────────────────────────
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    stringResource(R.string.error_plan_failed),
                    color = AppColors.TextSecondary,
                    fontSize = 14.sp
                )
            }
            return@Column
        }

        // ── Week selector (marathon/race plans) ─────────────────────────────
        if (editVm.isWeekBased) {
            WeekSelector(
                weeks = editVm.availableWeeks ?: emptyList(),
                selectedIndex = editVm.selectedWeekIndex,
                onSelect = { editVm.selectWeek(it) }
            )
        }

        // ── Workout list ────────────────────────────────────────────────────
        if (workouts.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        stringResource(R.string.edit_no_workouts),
                        color = AppColors.TextSecondary,
                        fontSize = 15.sp
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        stringResource(R.string.edit_add_first),
                        color = AppColors.TextMuted,
                        fontSize = 13.sp
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(workouts.size, key = { it }) { index ->
                    val wo = workouts[index]
                    EditableWorkoutCard(
                        workout = wo,
                        onEdit = { editVm.startEditWorkout(index) },
                        onDelete = { deleteIndex = index }
                    )
                }

                // Spacer for bottom inset
                item { Spacer(Modifier.height(16.dp)) }
            }
        }

        // ── Status message ──────────────────────────────────────────────────
        editVm.statusMessage?.let { msg ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.Mint.copy(alpha = 0.15f))
                    .padding(12.dp)
            ) {
                Text(msg, color = AppColors.Mint, fontSize = 13.sp)
            }
        }
    }

    // ── Edit dialog ────────────────────────────────────────────────────────
    if (editVm.showEditDialog) {
        EditWorkoutDialog(
            editVm = editVm,
            isNew = editVm.editingWorkoutIndex < 0
        )
    }

    // ── Delete confirmation ────────────────────────────────────────────────
    deleteIndex?.let { idx ->
        AlertDialog(
            onDismissRequest = { deleteIndex = null },
            containerColor = AppColors.Ink,
            title = {
                Text(stringResource(R.string.delete_day), color = Color.White, fontWeight = FontWeight.Bold)
            },
            text = {
                Text(stringResource(R.string.delete_plan_confirm), color = AppColors.TextSecondary)
            },
            confirmButton = {
                TextButton(onClick = {
                    editVm.deleteWorkout(idx)
                    deleteIndex = null
                }) {
                    Text(stringResource(R.string.delete_all), color = AppColors.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { deleteIndex = null }) {
                    Text(stringResource(R.string.cancel), color = AppColors.TextSecondary)
                }
            }
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEEK SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun WeekSelector(
    weeks: List<Int>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        contentPadding = PaddingValues(vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        item {
            Text(
                stringResource(R.string.edit_select_week),
                color = AppColors.TextSecondary,
                fontSize = 12.sp,
                modifier = Modifier.padding(bottom = 6.dp)
            )
        }
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                weeks.forEachIndexed { index, week ->
                    val selected = index == selectedIndex
                    FilterChip(
                        selected = selected,
                        onClick = { onSelect(index) },
                        label = {
                            Text(
                                stringResource(R.string.week_label, week),
                                fontSize = 11.sp
                            )
                        },
                        modifier = Modifier.weight(1f),
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = AppColors.Mint.copy(alpha = 0.25f),
                            selectedLabelColor = AppColors.Mint,
                            containerColor = AppColors.Card,
                            labelColor = AppColors.TextSecondary
                        ),
                        border = FilterChipDefaults.filterChipBorder(
                            enabled = true,
                            selected = selected,
                            selectedBorderColor = AppColors.Mint.copy(alpha = 0.6f),
                            borderColor = AppColors.Border
                        )
                    )
                }
            }
        }
        item { Spacer(Modifier.height(8.dp)) }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDITABLE WORKOUT CARD
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun EditableWorkoutCard(
    workout: PlannedWorkout,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    val color = categoryColor(workout.category)
    val dayLabel = try {
        stringResource(
            when (workout.day.lowercase().take(3)) {
                "mon" -> R.string.day_mon
                "tue" -> R.string.day_tue
                "wed" -> R.string.day_wed
                "thu" -> R.string.day_thu
                "fri" -> R.string.day_fri
                "sat" -> R.string.day_sat
                "sun" -> R.string.day_sun
                else -> R.string.day_mon
            }
        )
    } catch (_: Exception) {
        workout.day.take(3)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.Ink)
            .border(0.5.dp, color.copy(alpha = 0.3f), RoundedCornerShape(14.dp))
            .clickable { onEdit() }
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Day badge
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(color.copy(alpha = 0.2f))
                .border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(dayLabel, color = color, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        }

        // Info
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(workout.title, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CategoryPill(workout.category, color)
                IntensityPill(workout.intensity)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                workout.distanceKm?.let {
                    Text("${it}${stringResource(R.string.km_unit)}", color = AppColors.Cyan, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
                workout.durationMinutes?.let {
                    Text("${it}${stringResource(R.string.min_unit)}", color = AppColors.Violet, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        // Edit / Delete icons
        IconButton(onClick = onEdit, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.Edit, contentDescription = null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
        }
        IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.delete_day), tint = AppColors.Red.copy(alpha = 0.7f), modifier = Modifier.size(18.dp))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDIT WORKOUT DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun EditWorkoutDialog(
    editVm: EditPlanViewModel,
    isNew: Boolean
) {
    var typeDropdownOpen by remember { mutableStateOf(false) }
    var intensityDropdownOpen by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = { editVm.dismissEdit() },
        containerColor = AppColors.Ink,
        title = {
            Text(
                if (isNew) stringResource(R.string.new_day_title)
                else stringResource(R.string.edit_day_title),
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // ── Training type dropdown ─────────────────────────────────
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        stringResource(R.string.edit_training_type),
                        color = AppColors.TextSecondary,
                        fontSize = 12.sp
                    )
                    Box {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(AppColors.Navy)
                                .border(1.dp, AppColors.Border, RoundedCornerShape(8.dp))
                                .clickable { typeDropdownOpen = true }
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(editVm.editType, color = Color.White, fontSize = 14.sp)
                            Text("▾", color = AppColors.TextMuted, fontSize = 14.sp)
                        }
                        DropdownMenu(
                            expanded = typeDropdownOpen,
                            onDismissRequest = { typeDropdownOpen = false },
                            modifier = Modifier.background(AppColors.Ink)
                        ) {
                            WORKOUT_TYPES.forEach { type ->
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            type,
                                            color = if (type == editVm.editType) AppColors.Mint else Color.White
                                        )
                                    },
                                    onClick = {
                                        editVm.editType = type
                                        typeDropdownOpen = false
                                    }
                                )
                            }
                        }
                    }
                }

                // ── Title ──────────────────────────────────────────────────
                OutlinedTextField(
                    value = editVm.editTitle,
                    onValueChange = { editVm.editTitle = it },
                    label = { Text(stringResource(R.string.workout_description), color = AppColors.TextSecondary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Mint,
                        unfocusedBorderColor = AppColors.Border,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        cursorColor = AppColors.Mint
                    )
                )

                // ── Distance ───────────────────────────────────────────────
                OutlinedTextField(
                    value = editVm.editDistance,
                    onValueChange = { editVm.editDistance = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text(stringResource(R.string.edit_distance_km), color = AppColors.TextSecondary) },
                    suffix = { Text(stringResource(R.string.km_unit), color = AppColors.TextMuted) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Mint,
                        unfocusedBorderColor = AppColors.Border,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        cursorColor = AppColors.Mint
                    )
                )

                // ── Duration ───────────────────────────────────────────────
                OutlinedTextField(
                    value = editVm.editDuration,
                    onValueChange = { editVm.editDuration = it.filter { c -> c.isDigit() } },
                    label = { Text(stringResource(R.string.edit_duration_min), color = AppColors.TextSecondary) },
                    suffix = { Text(stringResource(R.string.min_unit), color = AppColors.TextMuted) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Mint,
                        unfocusedBorderColor = AppColors.Border,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        cursorColor = AppColors.Mint
                    )
                )

                // ── Details ────────────────────────────────────────────────
                OutlinedTextField(
                    value = editVm.editDetails,
                    onValueChange = { editVm.editDetails = it },
                    label = { Text(stringResource(R.string.workout_description), color = AppColors.TextSecondary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Mint,
                        unfocusedBorderColor = AppColors.Border,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        cursorColor = AppColors.Mint
                    )
                )

                // ── Intensity dropdown ─────────────────────────────────────
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("Intensity", color = AppColors.TextSecondary, fontSize = 12.sp)
                    Box {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(AppColors.Navy)
                                .border(1.dp, AppColors.Border, RoundedCornerShape(8.dp))
                                .clickable { intensityDropdownOpen = true }
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(editVm.editIntensity, color = Color.White, fontSize = 14.sp)
                            Text("▾", color = AppColors.TextMuted, fontSize = 14.sp)
                        }
                        DropdownMenu(
                            expanded = intensityDropdownOpen,
                            onDismissRequest = { intensityDropdownOpen = false },
                            modifier = Modifier.background(AppColors.Ink)
                        ) {
                            listOf("Low", "Medium", "High").forEach { intensity ->
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            intensity,
                                            color = if (intensity == editVm.editIntensity) AppColors.Mint else Color.White
                                        )
                                    },
                                    onClick = {
                                        editVm.editIntensity = intensity
                                        intensityDropdownOpen = false
                                    }
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = { editVm.saveWorkout() },
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Mint,
                    contentColor = Color.Black
                )
            ) {
                Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(stringResource(R.string.edit_save))
            }
        },
        dismissButton = {
            TextButton(onClick = { editVm.dismissEdit() }) {
                Text(stringResource(R.string.cancel), color = AppColors.TextSecondary)
            }
        }
    )
}
