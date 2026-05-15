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
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(vm: AppViewModel) {
    val profile = vm.profile
    var firstName by rememberSaveable { mutableStateOf(profile.firstName) }
    var lastName by rememberSaveable { mutableStateOf(profile.lastName) }
    var nickname by rememberSaveable { mutableStateOf(profile.nickname) }
    var level by rememberSaveable { mutableStateOf(profile.level) }
    var levelDropdownOpen by remember { mutableStateOf(false) }
    var target by rememberSaveable { mutableStateOf(profile.target) }
    var targetDropdownOpen by remember { mutableStateOf(false) }
    var weeklyKm by rememberSaveable { mutableStateOf(profile.weeklyMileageKm.toFloat()) }
    var runningDays by rememberSaveable { mutableStateOf(profile.runningDaysPerWeek.toFloat()) }
    var heightCm by rememberSaveable { mutableStateOf(profile.heightCm.toFloat()) }
    var weightKg by rememberSaveable { mutableStateOf(profile.weightKg.toFloat()) }
    var exerciseHours by rememberSaveable { mutableStateOf(profile.weeklyExerciseHours.toFloat()) }
    var injuryNote by rememberSaveable { mutableStateOf(profile.injuryNote) }
    var saved by remember { mutableStateOf(false) }

    // ── RF-208: Gear & Fit fields ─────────────────────────────────────────
    var shoeSizeEU by rememberSaveable { mutableStateOf(profile.shoeSizeEU) }
    var shoeSizeUnit by rememberSaveable { mutableStateOf("EU") } // EU / US / UK
    var legLengthCm by rememberSaveable { mutableStateOf(profile.legLengthCm.toFloat()) }
    var shoeBrand by rememberSaveable { mutableStateOf(profile.shoeBrand) }
    var shoeModel by rememberSaveable { mutableStateOf(profile.shoeModel) }
    val textFieldColors = OutlinedTextFieldDefaults.colors(
    val textFieldColors = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = AppColors.Mint,
        unfocusedBorderColor = AppColors.Border,
        focusedTextColor = Color.White,
        unfocusedTextColor = Color.White,
        cursorColor = AppColors.Mint,
        focusedLabelColor = AppColors.Mint,
        unfocusedLabelColor = AppColors.TextSecondary
    )
    val sliderColors = SliderDefaults.colors(
        thumbColor = AppColors.Mint,
        activeTrackColor = AppColors.Mint,
        inactiveTrackColor = AppColors.Border
    )

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column {
                Text("Profile", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                Text("Your info improves plan quality", color = AppColors.TextSecondary, fontSize = 14.sp)
            }
        }

        // ── Name ──────────────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    SectionTitle("Identity")
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedTextField(
                            value = firstName,
                            onValueChange = { firstName = it },
                            label = { Text("First Name") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                            colors = textFieldColors,
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words)
                        )
                        OutlinedTextField(
                            value = lastName,
                            onValueChange = { lastName = it },
                            label = { Text("Last Name") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                            colors = textFieldColors,
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words)
                        )
                    }
                    OutlinedTextField(
                        value = nickname,
                        onValueChange = { nickname = it },
                        label = { Text("Nickname (optional)") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors
                    )
                }
            }
        }

        // ── Level & Goal ──────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    SectionTitle("Runner Profile")

                    // Level
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Experience Level", color = AppColors.TextSecondary, fontSize = 13.sp)
                        DropdownField(
                            value = level,
                            options = RUNNER_LEVELS,
                            expanded = levelDropdownOpen,
                            onExpandedChange = { levelDropdownOpen = it },
                            onSelect = { level = it; levelDropdownOpen = false }
                        )
                    }

                    // Target
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Training Target", color = AppColors.TextSecondary, fontSize = 13.sp)
                        DropdownField(
                            value = target,
                            options = TRAINING_TARGETS,
                            expanded = targetDropdownOpen,
                            onExpandedChange = { targetDropdownOpen = it },
                            onSelect = { target = it; targetDropdownOpen = false }
                        )
                    }
                }
            }
        }

        // ── Running stats ─────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionTitle("Running Stats")

                    SliderRow(
                        label = "Weekly mileage",
                        value = weeklyKm,
                        displayValue = "${weeklyKm.roundToInt()} km",
                        range = 0f..120f,
                        onValueChange = { weeklyKm = it },
                        sliderColors = sliderColors
                    )

                    SliderRow(
                        label = "Running days / week",
                        value = runningDays,
                        displayValue = "${runningDays.roundToInt()} days",
                        range = 1f..7f,
                        steps = 5,
                        onValueChange = { runningDays = it },
                        sliderColors = sliderColors
                    )

                    SliderRow(
                        label = "Weekly exercise hours",
                        value = exerciseHours,
                        displayValue = "${exerciseHours.roundToInt()} h",
                        range = 0f..20f,
                        onValueChange = { exerciseHours = it },
                        sliderColors = sliderColors
                    )
                }
            }
        }

        // ── Body stats ────────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionTitle("Body Stats")

                    SliderRow(
                        label = "Height",
                        value = heightCm,
                        displayValue = "${heightCm.roundToInt()} cm",
                        range = 140f..220f,
                        onValueChange = { heightCm = it },
                        sliderColors = sliderColors
                    )

                    SliderRow(
                        label = "Weight",
                        value = weightKg,
                        displayValue = "${weightKg.roundToInt()} kg",
                        range = 35f..160f,
                        onValueChange = { weightKg = it },
                        sliderColors = sliderColors
                    )
                }
            }
        }

        // ── Injury note ───────────────────────────────────────────────────────
        item {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    SectionTitle("Injury / Medical Note")
                    OutlinedTextField(
                        value = injuryNote,
                        onValueChange = { injuryNote = it },
                        placeholder = { Text("e.g. knee pain, plantar fasciitis…", color = AppColors.TextMuted) },
                        minLines = 3,
                        modifier = Modifier.fillMaxWidth(),
                        colors = textFieldColors
                    )
                }
            }
        }

        // ── Save ──────────────────────────────────────────────────────────────
        item {
            Button(
                onClick = {
                    vm.updateProfile(
                        TesterProfile(
                            firstName = firstName,
                            lastName = lastName,
                            nickname = nickname,
                            level = level,
                            weeklyMileageKm = weeklyKm.toDouble(),
                            runningDaysPerWeek = runningDays.roundToInt(),
                            heightCm = heightCm.toDouble(),
                            weightKg = weightKg.toDouble(),
                            target = target,
                            injuryNote = injuryNote,
                            weeklyExerciseHours = exerciseHours.toDouble()
                        )
                    )
                    saved = true
                },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Mint,
                    contentColor = Color.Black
                )
            ) {
                if (saved) {
                    Icon(Icons.Default.Check, contentDescription = null)
                    Spacer(Modifier.padding(horizontal = 4.dp))
                    Text("Saved!", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                } else {
                    Text("Save Profile", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun DropdownField(
    value: String,
    options: List<String>,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onSelect: (String) -> Unit
) {
    Box {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onExpandedChange(true) }
                .background(AppColors.Navy, RoundedCornerShape(10.dp))
                .border(1.dp, AppColors.Border, RoundedCornerShape(10.dp))
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(value, color = Color.White, fontSize = 15.sp)
            Text("▾", color = AppColors.TextMuted, fontSize = 14.sp)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { onExpandedChange(false) },
            modifier = Modifier.background(AppColors.Ink)
        ) {
            options.forEach { opt ->
                DropdownMenuItem(
                    text = { Text(opt, color = if (opt == value) AppColors.Mint else Color.White) },
                    onClick = { onSelect(opt) }
                )
            }
        }
    }
}

@Composable
private fun SliderRow(
    label: String,
    value: Float,
    displayValue: String,
    range: ClosedFloatingPointRange<Float>,
    onValueChange: (Float) -> Unit,
    sliderColors: androidx.compose.material3.SliderColors,
    steps: Int = 0
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, color = AppColors.TextSecondary, fontSize = 13.sp)
            Text(displayValue, color = AppColors.Mint, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = range,
            steps = steps,
            colors = sliderColors,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
