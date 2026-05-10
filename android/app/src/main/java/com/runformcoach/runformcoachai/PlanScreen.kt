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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsRun
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale

private val DAYS = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

@Composable
fun PlanScreen(vm: AppViewModel) {
    val profile = vm.profile

    var weeklyKmText by rememberSaveable { mutableStateOf(profile.weeklyMileageKm.toInt().toString()) }
    var selectedTarget by rememberSaveable { mutableStateOf(profile.target) }
    var targetDropdownOpen by remember { mutableStateOf(false) }
    var selectedDays by rememberSaveable { mutableStateOf(setOf<String>()) }
    var injuryFlag by rememberSaveable { mutableStateOf(profile.injuryNote.isNotBlank()) }

    val locale = Locale.getDefault()
    val language = if (locale.language == "zh") "zh" else "en"

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column {
                Text("Training Plan", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Text("Get an AI-generated weekly plan", color = AppColors.TextSecondary, fontSize = 14.sp)
            }
        }

        // ── Form card ─────────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionTitle("Plan Settings")

                    // Weekly km
                    OutlinedTextField(
                        value = weeklyKmText,
                        onValueChange = { weeklyKmText = it.filter { c -> c.isDigit() } },
                        label = { Text("Current weekly km", color = AppColors.TextSecondary) },
                        suffix = { Text("km", color = AppColors.TextMuted) },
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

                    // Goal dropdown
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Training Goal", color = AppColors.TextSecondary, fontSize = 13.sp)
                        Box {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(AppColors.Navy)
                                    .border(1.dp, AppColors.Border, RoundedCornerShape(10.dp))
                                    .clickable { targetDropdownOpen = true }
                                    .padding(horizontal = 14.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(selectedTarget, color = Color.White, fontSize = 15.sp)
                                Text("▾", color = AppColors.TextMuted, fontSize = 14.sp)
                            }
                            DropdownMenu(
                                expanded = targetDropdownOpen,
                                onDismissRequest = { targetDropdownOpen = false },
                                modifier = Modifier.background(AppColors.Ink)
                            ) {
                                TRAINING_TARGETS.forEach { target ->
                                    DropdownMenuItem(
                                        text = { Text(target, color = if (target == selectedTarget) AppColors.Mint else Color.White) },
                                        onClick = {
                                            selectedTarget = target
                                            targetDropdownOpen = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    // Day chips
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Available Days", color = AppColors.TextSecondary, fontSize = 13.sp)
                            Text("${selectedDays.size} selected", color = AppColors.Mint, fontSize = 12.sp)
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            DAYS.forEach { day ->
                                FilterChip(
                                    selected = day in selectedDays,
                                    onClick = {
                                        selectedDays = if (day in selectedDays)
                                            selectedDays - day
                                        else
                                            selectedDays + day
                                    },
                                    label = { Text(day, fontSize = 11.sp) },
                                    modifier = Modifier.weight(1f),
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = AppColors.Mint.copy(alpha = 0.25f),
                                        selectedLabelColor = AppColors.Mint,
                                        containerColor = AppColors.Card,
                                        labelColor = AppColors.TextSecondary
                                    ),
                                    border = FilterChipDefaults.filterChipBorder(
                                        enabled = true,
                                        selected = day in selectedDays,
                                        selectedBorderColor = AppColors.Mint.copy(alpha = 0.6f),
                                        borderColor = AppColors.Border
                                    )
                                )
                            }
                        }
                    }

                    // Injury toggle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Injury / Pain Flag", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Medium)
                            Text("Plan will be more conservative", color = AppColors.TextMuted, fontSize = 12.sp)
                        }
                        Switch(
                            checked = injuryFlag,
                            onCheckedChange = { injuryFlag = it },
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

        // ── Generate button ───────────────────────────────────────────────────
        item {
            val isLoading = vm.planState is PlanState.Loading
            val weeklyKm = weeklyKmText.toDoubleOrNull() ?: 0.0
            val canGenerate = weeklyKm > 0 && selectedDays.isNotEmpty() && !isLoading

            Button(
                onClick = {
                    vm.generatePlan(
                        weeklyKm = weeklyKm,
                        target = selectedTarget,
                        selectedDays = selectedDays.sortedBy { DAYS.indexOf(it) },
                        injuryFlag = injuryFlag,
                        language = language
                    )
                },
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
                if (isLoading) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Color.Black, strokeWidth = 2.dp)
                    Spacer(Modifier.width(10.dp))
                    Text("Building plan...", fontWeight = FontWeight.Bold)
                } else {
                    Icon(Icons.Default.DirectionsRun, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Generate Plan", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }

            if (selectedDays.isEmpty() && vm.planState is PlanState.Idle) {
                Spacer(Modifier.height(4.dp))
                Text("Select at least one available day", color = AppColors.Orange, fontSize = 12.sp)
            }
        }

        // ── Error ─────────────────────────────────────────────────────────────
        if (vm.planState is PlanState.Error) {
            item {
                val msg = (vm.planState as PlanState.Error).message
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

        // ── Plan result ───────────────────────────────────────────────────────
        if (vm.planState is PlanState.Success) {
            val plan = (vm.planState as PlanState.Success).plan

            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("Your Training Plan", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                                Text("${plan.runningDays} run days · ${plan.plannedWeeklyKm.toInt()} km/week", color = AppColors.Mint, fontSize = 13.sp)
                            }
                            if (plan.connectedAnalysisUsed) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(AppColors.Violet.copy(alpha = 0.2f))
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text("AI-personalized", color = AppColors.Violet, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                        Text(plan.summary, color = AppColors.TextSecondary, fontSize = 13.sp, lineHeight = 18.sp)
                    }
                }
            }

            items(plan.workouts) { workout ->
                WorkoutCard(workout)
            }

            if (plan.notes.isNotEmpty()) {
                item {
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            SectionTitle("Coach Notes")
                            plan.notes.forEach { note ->
                                Row(verticalAlignment = Alignment.Top) {
                                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = AppColors.Mint, modifier = Modifier.size(14.dp).padding(top = 2.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text(note, color = AppColors.TextSecondary, fontSize = 13.sp, lineHeight = 18.sp)
                                }
                            }
                        }
                    }
                }
            }

            item {
                Button(
                    onClick = { vm.resetPlan() },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Card, contentColor = AppColors.TextSecondary)
                ) { Text("New Plan") }
            }
        }
    }
}

@Composable
private fun WorkoutCard(workout: PlannedWorkout) {
    val color = categoryColor(workout.category)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.Ink)
            .border(0.5.dp, color.copy(alpha = 0.4f), RoundedCornerShape(14.dp))
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Day badge
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(color.copy(alpha = 0.2f))
                .border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(workout.day.take(3), color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(workout.title, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CategoryPill(workout.category, color)
                IntensityPill(workout.intensity)
            }
            Text(workout.details, color = AppColors.TextSecondary, fontSize = 12.sp, lineHeight = 16.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                workout.distanceKm?.let {
                    Text("${it}km", color = AppColors.Cyan, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
                workout.durationMinutes?.let {
                    Text("${it}min", color = AppColors.Violet, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            workout.coachingFocus?.let {
                Text("Focus: $it", color = AppColors.Mint, fontSize = 11.sp, fontWeight = FontWeight.Medium)
            }
            Text(workout.purpose, color = AppColors.TextMuted, fontSize = 11.sp, lineHeight = 15.sp)
        }
    }
}

@Composable
private fun CategoryPill(category: String, color: Color) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.15f))
            .padding(horizontal = 8.dp, vertical = 2.dp)
    ) {
        Text(category, color = color, fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun IntensityPill(intensity: String) {
    val color = when (intensity.lowercase()) {
        "high", "very high" -> AppColors.Red
        "medium", "moderate" -> AppColors.Orange
        else -> AppColors.Mint
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 8.dp, vertical = 2.dp)
    ) {
        Text(intensity, color = color, fontSize = 11.sp)
    }
}
