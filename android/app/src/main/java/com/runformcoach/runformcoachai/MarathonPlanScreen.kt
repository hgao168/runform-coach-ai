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
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
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

private val DAYS = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

/** Full marathon plan screen with setup, generation, phase view and week view. */
@Composable
fun MarathonPlanScreen(
    vm: MarathonPlanViewModel = hiltViewModel(),
    language: String = "en"
) {
    // Keep language in sync so VM can use it for API calls
    vm.language = language

    val plan = vm.genState
    val marathonPlan = vm.marathonPlan

    if (plan is MarathonGenState.Idle || plan is MarathonGenState.Error) {
        // ── Setup view ─────────────────────────────────────────────────
        MarathonSetupContent(vm, plan)
    } else if (plan is MarathonGenState.Loading) {
        // ── Loading overlay ─────────────────────────────────────────────
        Box(
            modifier = Modifier.fillMaxSize().padding(32.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(color = AppColors.Mint, modifier = Modifier.size(48.dp))
                Spacer(Modifier.height(16.dp))
                Text(stringResource(R.string.building_plan), color = AppColors.TextSecondary, fontSize = 14.sp)
            }
        }
    } else if (plan is MarathonGenState.Success && marathonPlan != null) {
        // ── Result view ─────────────────────────────────────────────────
        MarathonResultContent(vm, marathonPlan)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SETUP CONTENT
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun MarathonSetupContent(
    vm: MarathonPlanViewModel,
    planState: MarathonGenState
) {
    var majorDropdownOpen by remember { mutableStateOf(false) }
    var weeksDropdownOpen by remember { mutableStateOf(false) }
    var levelDropdownOpen by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Title ──────────────────────────────────────────────────────────
        item {
            Column {
                Text(stringResource(R.string.marathon_plan_title), color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.marathon_plan_subtitle), color = AppColors.TextSecondary, fontSize = 14.sp)
            }
        }

        // ── Form card ──────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionTitle(stringResource(R.string.plan_settings))

                    // ── Race selection ─────────────────────────────────────
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(stringResource(R.string.select_race), color = AppColors.TextSecondary, fontSize = 13.sp)
                        Box {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(AppColors.Navy)
                                    .border(1.dp, AppColors.Border, RoundedCornerShape(10.dp))
                                    .clickable { majorDropdownOpen = true }
                                    .padding(horizontal = 14.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                val displayName = when (vm.selectedMajor) {
                                    "Custom" -> stringResource(R.string.marathon_custom)
                                    else -> vm.selectedMajor
                                }
                                Text(displayName, color = Color.White, fontSize = 15.sp)
                                Text("▾", color = AppColors.TextMuted, fontSize = 14.sp)
                            }
                            DropdownMenu(
                                expanded = majorDropdownOpen,
                                onDismissRequest = { majorDropdownOpen = false },
                                modifier = Modifier.background(AppColors.Ink)
                            ) {
                                MARATHON_MAJORS.forEach { major ->
                                    val label = when (major) {
                                        "Custom" -> stringResource(R.string.marathon_custom)
                                        else -> major
                                    }
                                    DropdownMenuItem(
                                        text = {
                                            Text(label, color = if (major == vm.selectedMajor) AppColors.Mint else Color.White)
                                        },
                                        onClick = {
                                            vm.selectedMajor = major
                                            majorDropdownOpen = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // ── Custom race name ────────────────────────────────────
                    if (vm.selectedMajor == "Custom") {
                        OutlinedTextField(
                            value = vm.customRaceName,
                            onValueChange = { vm.customRaceName = it },
                            label = { Text(stringResource(R.string.marathon_race_name), color = AppColors.TextSecondary) },
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
                    }

                    // ── Target time ─────────────────────────────────────────
                    OutlinedTextField(
                        value = vm.targetTime,
                        onValueChange = { vm.targetTime = it },
                        label = { Text(stringResource(R.string.target_time_hhmm), color = AppColors.TextSecondary) },
                        placeholder = { Text(stringResource(R.string.target_time_hint), color = AppColors.TextMuted) },
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

                    // ── Plan weeks picker ───────────────────────────────────
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(stringResource(R.string.plan_duration), color = AppColors.TextSecondary, fontSize = 13.sp)
                        Box {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(AppColors.Navy)
                                    .border(1.dp, AppColors.Border, RoundedCornerShape(10.dp))
                                    .clickable { weeksDropdownOpen = true }
                                    .padding(horizontal = 14.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    stringResource(R.string.x_weeks, vm.planWeeks),
                                    color = Color.White, fontSize = 15.sp
                                )
                                Text("▾", color = AppColors.TextMuted, fontSize = 14.sp)
                            }
                            DropdownMenu(
                                expanded = weeksDropdownOpen,
                                onDismissRequest = { weeksDropdownOpen = false },
                                modifier = Modifier.background(AppColors.Ink)
                            ) {
                                listOf(12, 16).forEach { weeks ->
                                    DropdownMenuItem(
                                        text = {
                                            Text(
                                                stringResource(R.string.x_weeks, weeks),
                                                color = if (weeks == vm.planWeeks) AppColors.Mint else Color.White
                                            )
                                        },
                                        onClick = {
                                            vm.planWeeks = weeks
                                            weeksDropdownOpen = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // ── Training level picker ───────────────────────────────
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(stringResource(R.string.training_level), color = AppColors.TextSecondary, fontSize = 13.sp)
                        Box {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(AppColors.Navy)
                                    .border(1.dp, AppColors.Border, RoundedCornerShape(10.dp))
                                    .clickable { levelDropdownOpen = true }
                                    .padding(horizontal = 14.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(vm.trainingLevel, color = Color.White, fontSize = 15.sp)
                                Text("▾", color = AppColors.TextMuted, fontSize = 14.sp)
                            }
                            DropdownMenu(
                                expanded = levelDropdownOpen,
                                onDismissRequest = { levelDropdownOpen = false },
                                modifier = Modifier.background(AppColors.Ink)
                            ) {
                                TRAINING_LEVELS.forEach { level ->
                                    DropdownMenuItem(
                                        text = {
                                            Text(level, color = if (level == vm.trainingLevel) AppColors.Mint else Color.White)
                                        },
                                        onClick = {
                                            vm.trainingLevel = level
                                            levelDropdownOpen = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // ── Weekly km ───────────────────────────────────────────
                    OutlinedTextField(
                        value = vm.weeklyKmText,
                        onValueChange = { vm.weeklyKmText = it.filter { c -> c.isDigit() || c == '.' } },
                        label = { Text(stringResource(R.string.current_weekly_km), color = AppColors.TextSecondary) },
                        suffix = { Text(stringResource(R.string.km_unit), color = AppColors.TextMuted) },
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

                    // ── Day chips ───────────────────────────────────────────
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(stringResource(R.string.available_days), color = AppColors.TextSecondary, fontSize = 13.sp)
                            Text(
                                stringResource(R.string.x_selected, vm.selectedDays.size),
                                color = AppColors.Mint, fontSize = 12.sp
                            )
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            DAYS.indices.forEach { i ->
                                val selected = i in vm.selectedDays
                                FilterChip(
                                    selected = selected,
                                    onClick = {
                                        vm.selectedDays = if (selected)
                                            vm.selectedDays - i
                                        else
                                            vm.selectedDays + i
                                    },
                                    label = { Text(DAYS[i], fontSize = 11.sp) },
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

                    // ── Injury toggle ───────────────────────────────────────
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(stringResource(R.string.injury_pain_flag), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Medium)
                            Text(stringResource(R.string.injury_pain_desc), color = AppColors.TextMuted, fontSize = 12.sp)
                        }
                        Switch(
                            checked = vm.injuryFlag,
                            onCheckedChange = { vm.injuryFlag = it },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = Color.Black,
                                checkedTrackColor = AppColors.Mint,
                                uncheckedThumbColor = AppColors.TextMuted,
                                uncheckedTrackColor = AppColors.Border
                            )
                        )
                    }
                }
            }
        }

        // ── Generate button ─────────────────────────────────────────────────
        item {
            val km = vm.weeklyKmText.toDoubleOrNull() ?: 0.0
            val canGenerate = km > 0 && vm.selectedDays.isNotEmpty() && vm.genState !is MarathonGenState.Loading

            Button(
                onClick = { vm.generateMarathonPlan() },
                enabled = canGenerate,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Mint,
                    contentColor = Color.Black,
                    disabledContainerColor = AppColors.Mint.copy(alpha = 0.3f),
                    disabledContentColor = Color.Black.copy(alpha = 0.5f)
                )
            ) {
                Icon(Icons.Default.Flag, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.generate_marathon_plan), fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }

            if (vm.selectedDays.isEmpty() && vm.genState is MarathonGenState.Idle) {
                Spacer(Modifier.height(4.dp))
                Text(stringResource(R.string.select_at_least_one_day), color = AppColors.Orange, fontSize = 12.sp)
            }
        }

        // ── Error ───────────────────────────────────────────────────────────
        if (planState is MarathonGenState.Error) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(AppColors.Red.copy(alpha = 0.15f))
                        .border(1.dp, AppColors.Red.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                        .padding(16.dp)
                ) {
                    Text(
                        stringResource(R.string.error_prefix, planState.message),
                        color = AppColors.Red, fontSize = 14.sp
                    )
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESULT CONTENT
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun MarathonResultContent(vm: MarathonPlanViewModel, marathonPlan: MarathonPlan) {
    val phaseLabels = phaseLabels()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Header card ────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                stringResource(R.string.marathon_plan_title),
                                color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold
                            )
                            Text(
                                marathonPlan.race + " · " + marathonPlan.planProfile,
                                color = AppColors.Mint, fontSize = 13.sp
                            )
                            Text(
                                stringResource(R.string.total_weeks, marathonPlan.totalWeeks),
                                color = AppColors.TextSecondary, fontSize = 12.sp
                            )
                        }
                    }
                }
            }
        }

        // ── View mode toggle ────────────────────────────────────────────────
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ModeChip(
                    label = stringResource(R.string.phase_view),
                    selected = vm.viewMode == "phases",
                    onClick = { vm.viewMode = "phases" },
                    modifier = Modifier.weight(1f)
                )
                ModeChip(
                    label = stringResource(R.string.week_view),
                    selected = vm.viewMode == "weeks",
                    onClick = { vm.viewMode = "weeks" },
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // ── Phase view ─────────────────────────────────────────────────────
        if (vm.viewMode == "phases") {
            val boundaries = vm.phaseBoundaries
            if (boundaries.isNotEmpty()) {
                items(boundaries, key = { it.id }) { boundary ->
                    val phaseName = phaseLabels[boundary.label] ?: boundary.label
                    val isSelected = vm.selectedPhase == boundary.label
                    MarathonPhaseCard(
                        phaseName = phaseName,
                        boundary = boundary,
                        weeks = marathonPlan.weeks.filter { it.phase == boundary.label },
                        isSelected = isSelected,
                        onClick = { vm.selectPhase(boundary.label) }
                    )
                }
            }
        }

        // ── Week view ──────────────────────────────────────────────────────
        if (vm.viewMode == "weeks") {
            val sortedWeeks = marathonPlan.weeks.sortedBy { it.week }
            items(sortedWeeks, key = { it.week }) { week ->
                val weekIdx = week.week - 1 // 0-based index
                val isExpanded = weekIdx in vm.expandedWeeks
                MarathonWeekCard(
                    week = week,
                    phaseLabels = phaseLabels,
                    isExpanded = isExpanded,
                    onToggle = { vm.toggleWeekExpanded(weekIdx) }
                )
            }
        }

        // ── New Plan button ─────────────────────────────────────────────────
        item {
            Button(
                onClick = { vm.resetPlan() },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Card,
                    contentColor = AppColors.TextSecondary
                )
            ) { Text(stringResource(R.string.new_plan)) }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARATHON-SPECIFIC COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

/** Card showing a training phase summary (Base, Build, Peak, Taper). */
@Composable
private fun MarathonPhaseCard(
    phaseName: String,
    boundary: MarathonPhaseLink,
    weeks: List<MarathonPlanWeek>,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val borderColor = when {
        isSelected -> AppColors.Mint
        boundary.label.lowercase().contains("base") -> AppColors.Cyan.copy(alpha = 0.5f)
        boundary.label.lowercase().contains("build") -> AppColors.Orange.copy(alpha = 0.5f)
        boundary.label.lowercase().contains("peak") -> AppColors.Violet.copy(alpha = 0.5f)
        boundary.label.lowercase().contains("taper") -> AppColors.Green.copy(alpha = 0.5f)
        else -> AppColors.Border
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.Ink)
            .border(1.dp, borderColor, RoundedCornerShape(14.dp))
            .clickable { onClick() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(phaseName, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Icon(
                if (isSelected) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                contentDescription = null,
                tint = AppColors.TextMuted,
                modifier = Modifier.size(20.dp)
            )
        }

        // Week range
        Text(
            "W${boundary.startWeek} – W${boundary.endWeek}  (${boundary.endWeek - boundary.startWeek + 1} ${stringResource(R.string.week_view).lowercase().replace(" view", "s")})",
            color = AppColors.TextSecondary, fontSize = 12.sp
        )

        // KM progression
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Column {
                Text(stringResource(R.string.target_km, boundary.startTargetKm), color = AppColors.TextMuted, fontSize = 11.sp)
                Text(stringResource(R.string.target_km, boundary.endTargetKm), color = AppColors.TextMuted, fontSize = 11.sp)
            }
            Column {
                Text(stringResource(R.string.long_run, boundary.startLongRunKm), color = AppColors.TextMuted, fontSize = 11.sp)
                Text(stringResource(R.string.long_run, boundary.endLongRunKm), color = AppColors.TextMuted, fontSize = 11.sp)
            }
        }

        // Expanded: show weeks summary
        if (isSelected) {
            Spacer(Modifier.height(4.dp))
            weeks.sortedBy { it.week }.forEach { w ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        stringResource(R.string.week_label, w.week),
                        color = AppColors.Mint, fontSize = 13.sp, fontWeight = FontWeight.SemiBold
                    )
                    Column(horizontalAlignment = Alignment.End) {
                        Text("${w.targetKm.toInt()} km", color = Color.White, fontSize = 12.sp)
                        Text(
                            stringResource(R.string.long_run, w.longRunKm),
                            color = AppColors.TextSecondary, fontSize = 11.sp
                        )
                    }
                    Text(
                        "${w.workouts.size} workouts",
                        color = AppColors.TextMuted, fontSize = 11.sp
                    )
                }
            }
        }
    }
}

/** Card showing a single marathon training week with its workouts. */
@Composable
private fun MarathonWeekCard(
    week: MarathonPlanWeek,
    phaseLabels: Map<String, String>,
    isExpanded: Boolean,
    onToggle: () -> Unit
) {
    val phaseName = phaseLabels[week.phase] ?: week.phase

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.Ink)
            .border(0.5.dp, AppColors.Border, RoundedCornerShape(14.dp))
            .clickable { onToggle() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        // ── Week header ────────────────────────────────────────────────────
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    stringResource(R.string.week_label, week.week),
                    color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold
                )
                Text(phaseName, color = AppColors.TextSecondary, fontSize = 12.sp)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(horizontalAlignment = Alignment.End) {
                    Text("${week.targetKm.toInt()} km", color = AppColors.Mint, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    Text(
                        stringResource(R.string.long_run, week.longRunKm),
                        color = AppColors.TextSecondary, fontSize = 11.sp
                    )
                }
                Spacer(Modifier.width(8.dp))
                Icon(
                    if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = null,
                    tint = AppColors.TextMuted,
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        // ── Phase / KM bar ─────────────────────────────────────────────────
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("${week.workouts.size} workouts", color = AppColors.TextMuted, fontSize = 11.sp)
        }

        week.notes?.let { note ->
            Text(note, color = AppColors.TextSecondary, fontSize = 11.sp, lineHeight = 15.sp)
        }

        // ── Expanded: workout list ─────────────────────────────────────────
        if (isExpanded && week.workouts.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            week.workouts.forEach { workout ->
                MarathonWorkoutCard(workout)
            }
        }
    }
}

/** Marathon-specific workout card highlighting LSD, pace run, recovery run etc. */
@Composable
private fun MarathonWorkoutCard(workout: PlannedWorkout) {
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
    } catch (_: Exception) { workout.day.take(3) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.DarkCard)
            .border(0.5.dp, color.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
            .padding(10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
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

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(workout.title, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                MarathonCategoryPill(workout.category, color)
                IntensityPill(workout.intensity)
            }
            Text(workout.details, color = AppColors.TextSecondary, fontSize = 11.sp, lineHeight = 15.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                workout.distanceKm?.let {
                    Text("${it}${stringResource(R.string.km_unit)}", color = AppColors.Cyan, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
                workout.durationMinutes?.let {
                    Text("${it}${stringResource(R.string.min_unit)}", color = AppColors.Violet, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            workout.coachingFocus?.let {
                Text(stringResource(R.string.focus_prefix, it), color = AppColors.Mint, fontSize = 10.sp, fontWeight = FontWeight.Medium)
            }
            Text(workout.purpose, color = AppColors.TextMuted, fontSize = 10.sp, lineHeight = 13.sp)
        }
    }
}

/** Category pill with marathon-specific labels (LSD, pace run, recovery, etc.). */
@Composable
private fun MarathonCategoryPill(category: String, color: Color) {
    val label = when (category.lowercase().trim()) {
        "long run", "long" -> "LSD"
        "tempo", "tempo run" -> "Pace"
        "recovery", "rest" -> "Recovery"
        "easy run", "easy" -> "Easy"
        "intervals", "interval", "speed" -> "Speed"
        "strength", "strength & mobility", "mobility" -> "Strength"
        else -> category
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(5.dp))
            .background(color.copy(alpha = 0.15f))
            .padding(horizontal = 6.dp, vertical = 1.dp)
    ) {
        Text(label, color = color, fontSize = 10.sp, fontWeight = FontWeight.Medium)
    }
}

/** View mode toggle chip (Phase View / Week View). */
@Composable
private fun ModeChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (selected) AppColors.Mint.copy(alpha = 0.18f) else AppColors.Card)
            .border(1.dp, if (selected) AppColors.Mint.copy(alpha = 0.5f) else AppColors.Border, RoundedCornerShape(10.dp))
            .clickable { onClick() }
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            label,
            color = if (selected) AppColors.Mint else AppColors.TextSecondary,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
        )
    }
}

/** Map phase API labels to Chinese or English display names. */
@Composable
private fun phaseLabels(): Map<String, String> = mapOf(
    "Base Phase" to stringResource(R.string.phase_base),
    "Build Phase" to stringResource(R.string.phase_build),
    "Peak Phase" to stringResource(R.string.phase_peak),
    "Taper Phase" to stringResource(R.string.phase_taper),
    // Chinese labels from API responses
    "基础期" to stringResource(R.string.phase_base),
    "强化期" to stringResource(R.string.phase_build),
    "巅峰期" to stringResource(R.string.phase_peak),
    "减量期" to stringResource(R.string.phase_taper)
)
