package com.runformcoach.runformcoachai

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class MarathonGenState {
    object Idle : MarathonGenState()
    object Loading : MarathonGenState()
    data class Success(val plan: TrainingPlanResponse) : MarathonGenState()
    data class Error(val message: String) : MarathonGenState()
}

@HiltViewModel
class MarathonPlanViewModel @Inject constructor(
    private val api: RunFormApi
) : ViewModel() {

    // ── Inputs ─────────────────────────────────────────────────────────────

    /** Selected World Marathon Major or "Custom" */
    var selectedMajor by mutableStateOf("Berlin")

    /** Custom race name when selectedMajor == "Custom" */
    var customRaceName by mutableStateOf("")

    /** Target finish time in HH:MM format (e.g. "3:45") */
    var targetTime by mutableStateOf("")

    /** Plan duration in weeks (12 or 16) */
    var planWeeks by mutableStateOf(16)

    /** Training level */
    var trainingLevel by mutableStateOf("Intermediate")

    /** Current weekly km baseline */
    var weeklyKmText by mutableStateOf("30")

    /** Selected running days (indices 0=Mon..6=Sun) */
    var selectedDays by mutableStateOf(setOf(0, 2, 4))

    /** Injury / pain flag */
    var injuryFlag by mutableStateOf(false)

    /** Language for API request */
    var language by mutableStateOf("en")

    // ── Generation state ───────────────────────────────────────────────────

    var genState by mutableStateOf<MarathonGenState>(MarathonGenState.Idle)

    // ── Detail view state ──────────────────────────────────────────────────

    /** "weeks" or "phases" */
    var viewMode by mutableStateOf("phases")

    /** Which phase label is currently selected in phase view */
    var selectedPhase by mutableStateOf<String?>(null)

    /** Expanded week indices (0-based) in week view */
    var expandedWeeks by mutableStateOf(setOf<Int>())

    // ── Computed ───────────────────────────────────────────────────────────

    /** The race name sent to the API (major or custom) */
    val effectiveRaceName: String
        get() = if (selectedMajor == "Custom") customRaceName.trim().ifEmpty { "Custom Marathon" }
        else selectedMajor

    /** Phase boundaries computed from plan weeks */
    val phaseBoundaries: List<MarathonPhaseLink>
        get() {
            val state = genState
            if (state !is MarathonGenState.Success) return emptyList()
            val weeks = state.plan.marathonPlan?.weeks ?: return emptyList()
            val sorted = weeks.sortedBy { it.week }
            if (sorted.isEmpty()) return emptyList()
            var groups = mutableListOf<MutableList<MarathonPlanWeek>>()
            groups.add(mutableListOf(sorted.first()))
            for (week in sorted.drop(1)) {
                val lastGroup = groups.last()
                if (lastGroup.first().phase == week.phase) {
                    lastGroup.add(week)
                } else {
                    groups.add(mutableListOf(week))
                }
            }
            return groups.mapNotNull { group ->
                val start = group.first()
                val end = group.last()
                MarathonPhaseLink(
                    id = "${start.phase}-${start.week}-${end.week}",
                    label = start.phase,
                    startWeek = start.week,
                    endWeek = end.week,
                    startTargetKm = start.targetKm,
                    endTargetKm = end.targetKm,
                    startLongRunKm = start.longRunKm,
                    endLongRunKm = end.longRunKm
                )
            }
        }

    /** Weeks grouped by phase for phase view display */
    val weeksByPhase: Map<String, List<MarathonPlanWeek>>
        get() {
            val state = genState
            if (state !is MarathonGenState.Success) return emptyMap()
            val weeks = state.plan.marathonPlan?.weeks ?: return emptyMap()
            return weeks.groupBy { it.phase }
        }

    /** All weeks sorted */
    val allWeeks: List<MarathonPlanWeek>
        get() {
            val state = genState
            if (state !is MarathonGenState.Success) return emptyList()
            return state.plan.marathonPlan?.weeks?.sortedBy { it.week } ?: emptyList()
        }

    /** Marathon plan from the response (null if no marathon block) */
    val marathonPlan: MarathonPlan?
        get() = (genState as? MarathonGenState.Success)?.plan?.marathonPlan

    // ── Actions ────────────────────────────────────────────────────────────

    fun generateMarathonPlan() {
        val km = weeklyKmText.toDoubleOrNull() ?: 0.0
        if (km <= 0 || selectedDays.isEmpty()) return

        val dayLabels = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        val selectedDayNames = selectedDays.sorted().mapNotNull { i ->
            if (i < dayLabels.size) dayLabels[i] else null
        }

        val request = TrainingPlanRequest(
            currentWeeklyKm = km,
            target = "Marathon",
            availableRunningDays = selectedDays.size.coerceAtLeast(1),
            selectedRunDays = selectedDayNames,
            injuryFlag = injuryFlag,
            formIssues = emptyList(),
            language = language,
            marathonMajor = effectiveRaceName,
            marathonPlanWeeks = planWeeks,
            includeMarathonBlock = true,
            includeRaceBlock = false,
            trainingLevel = trainingLevel,
            planDurationWeeks = planWeeks
        )

        genState = MarathonGenState.Loading
        viewModelScope.launch {
            try {
                val plan = api.generatePlan(request)
                genState = MarathonGenState.Success(plan)
                selectedPhase = null
                expandedWeeks = emptySet()
            } catch (e: Exception) {
                genState = MarathonGenState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun resetPlan() {
        genState = MarathonGenState.Idle
        selectedPhase = null
        expandedWeeks = emptySet()
    }

    fun toggleWeekExpanded(weekIndex: Int) {
        expandedWeeks = if (weekIndex in expandedWeeks)
            expandedWeeks - weekIndex
        else
            expandedWeeks + weekIndex
    }

    fun selectPhase(phaseLabel: String) {
        selectedPhase = if (selectedPhase == phaseLabel) null else phaseLabel
    }
}
