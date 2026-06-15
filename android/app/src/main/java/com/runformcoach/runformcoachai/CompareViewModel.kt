package com.runformcoach.runformcoachai

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.runformcoach.runformcoachai.data.AnalysisDao
import com.runformcoach.runformcoachai.data.AnalysisHistoryEntity
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

// ── Compare ViewModel ─────────────────────────────────────────────────────────
// Manages elite athlete comparison, custom history-vs-history comparison,
// and history comparison browsing. Used by CompareScreen, CompareResultScreen,
// CustomCompareScreen, and CompareHistoryScreen.

sealed class AthleteListState {
    object Loading : AthleteListState()
    data class Success(val athletes: List<AthleteListItem>) : AthleteListState()
    data class Error(val message: String) : AthleteListState()
}

sealed class CompareResultState {
    object Idle : CompareResultState()
    object Loading : CompareResultState()
    data class Success(val result: CompareResponse) : CompareResultState()
    data class Error(val message: String) : CompareResultState()
}

@HiltViewModel
class CompareViewModel @Inject constructor(
    private val api: RunFormApi,
    private val analysisDao: AnalysisDao
) : ViewModel() {

    private val gson = Gson()

    // ── Athlete list ───────────────────────────────────────────────────────────

    private val _athleteListState = MutableStateFlow<AthleteListState>(AthleteListState.Loading)
    val athleteListState: StateFlow<AthleteListState> = _athleteListState.asStateFlow()

    // ── Compare result ─────────────────────────────────────────────────────────

    private val _compareResultState = MutableStateFlow<CompareResultState>(CompareResultState.Idle)
    val compareResultState: StateFlow<CompareResultState> = _compareResultState.asStateFlow()

    // ── Selected athlete (for result screen title) ─────────────────────────────

    private val _selectedAthleteName = MutableStateFlow<String?>(null)
    val selectedAthleteName: StateFlow<String?> = _selectedAthleteName.asStateFlow()

    // ── History items for custom compare ───────────────────────────────────────

    private val _historyItems = MutableStateFlow<List<AnalysisHistoryItem>>(emptyList())
    val historyItems: StateFlow<List<AnalysisHistoryItem>> = _historyItems.asStateFlow()

    // ── Custom compare selections ──────────────────────────────────────────────

    private val _selectedHistoryA = MutableStateFlow<AnalysisHistoryItem?>(null)
    val selectedHistoryA: StateFlow<AnalysisHistoryItem?> = _selectedHistoryA.asStateFlow()

    private val _selectedHistoryB = MutableStateFlow<AnalysisHistoryItem?>(null)
    val selectedHistoryB: StateFlow<AnalysisHistoryItem?> = _selectedHistoryB.asStateFlow()

    // ── Custom compare result ──────────────────────────────────────────────────

    private val _customCompareResultState = MutableStateFlow<CompareResultState>(CompareResultState.Idle)
    val customCompareResultState: StateFlow<CompareResultState> = _customCompareResultState.asStateFlow()

    init {
        loadAthletes()
        loadHistory()
    }

    // ── Athlete loading ────────────────────────────────────────────────────────

    fun loadAthletes() {
        if (_athleteListState.value is AthleteListState.Success) return // already loaded
        _athleteListState.value = AthleteListState.Loading
        viewModelScope.launch {
            try {
                val athletes = api.fetchAthletes()
                _athleteListState.value = AthleteListState.Success(athletes)
            } catch (e: Exception) {
                _athleteListState.value = AthleteListState.Error(e.message ?: "Unknown error")
            }
        }
    }

    // ── Compare with elite athlete ─────────────────────────────────────────────

    fun compareWithAthlete(athlete: AthleteListItem, analysis: AnalysisResponse) {
        _selectedAthleteName.value = athlete.name
        _compareResultState.value = CompareResultState.Loading
        val metrics = createPoseMetricsFromAnalysis(analysis)
        val request = CompareRequest(
            userMetrics = metrics,
            athleteId = athlete.id,
            language = java.util.Locale.getDefault().language.let { if (it == "zh") "zh" else "en" }
        )
        viewModelScope.launch {
            try {
                val result = api.compareWithAthlete(request)
                _compareResultState.value = CompareResultState.Success(result)
            } catch (e: Exception) {
                _compareResultState.value = CompareResultState.Error(e.message ?: "Unknown error")
            }
        }
    }

    // ── Compare with elite athlete (from history item) ─────────────────────────

    fun compareWithAthleteFromHistory(athlete: AthleteListItem, historyItem: AnalysisHistoryItem) {
        _selectedAthleteName.value = athlete.name
        _compareResultState.value = CompareResultState.Loading
        val metrics = createPoseMetricsFromAnalysis(historyItem.result)
        val request = CompareRequest(
            userMetrics = metrics,
            athleteId = athlete.id,
            language = java.util.Locale.getDefault().language.let { if (it == "zh") "zh" else "en" }
        )
        viewModelScope.launch {
            try {
                val result = api.compareWithAthlete(request)
                _compareResultState.value = CompareResultState.Success(result)
            } catch (e: Exception) {
                _compareResultState.value = CompareResultState.Error(e.message ?: "Unknown error")
            }
        }
    }

    // ── Reset ──────────────────────────────────────────────────────────────────

    fun resetCompare() {
        _compareResultState.value = CompareResultState.Idle
        _selectedAthleteName.value = null
    }

    fun resetCustomCompare() {
        _customCompareResultState.value = CompareResultState.Idle
        _selectedHistoryA.value = null
        _selectedHistoryB.value = null
    }

    // ── History loading (for custom compare) ───────────────────────────────────

    private fun loadHistory() {
        viewModelScope.launch {
            try {
                val entities = withContext(Dispatchers.IO) { analysisDao.getAll() }
                _historyItems.value = entities.map { it.toItem(gson) }.reversed()
            } catch (_: Exception) {
                _historyItems.value = emptyList()
            }
        }
    }

    fun refreshHistory() {
        loadHistory()
    }

    // ── Custom compare: select two history items ───────────────────────────────

    fun selectHistoryItem(item: AnalysisHistoryItem) {
        val a = _selectedHistoryA.value
        val b = _selectedHistoryB.value
        when {
            a == null -> _selectedHistoryA.value = item
            b == null && a.id != item.id -> _selectedHistoryB.value = item
            a.id == item.id -> _selectedHistoryA.value = null
            b?.id == item.id -> _selectedHistoryB.value = null
            else -> {
                // Both slots filled, replace A
                _selectedHistoryA.value = item
                _selectedHistoryB.value = null
            }
        }
    }

    fun runCustomCompare() {
        val a = _selectedHistoryA.value ?: return
        val b = _selectedHistoryB.value ?: return
        _customCompareResultState.value = CompareResultState.Loading
        viewModelScope.launch {
            try {
                // Use analysis A as "user" and analysis B as "athlete" substitute
                val metricsA = createPoseMetricsFromAnalysis(a.result)
                val metricsB = createPoseMetricsFromAnalysis(b.result)
                // We construct a pseudo CompareResponse for side-by-side
                val comparisons = buildMetricsComparison(a.result, b.result)
                val avgSimilarity = comparisons.map { it.gapPct }.average().let { 1.0 - it.coerceIn(0.0, 1.0) }
                val result = CompareResponse(
                    athlete = AthleteProfile(
                        id = b.id,
                        name = "Analysis #${b.id}",
                        event = "",
                        nationality = "",
                        achievement = "",
                        bio = java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.getDefault())
                            .format(java.util.Date(b.createdAt)),
                        photoUrl = ""
                    ),
                    comparisons = comparisons,
                    topGaps = comparisons.filter { it.status == "gap" }.map { it.metric },
                    coachingNarrative = "Side-by-side comparison of your two analyses.",
                    overallSimilarityScore = avgSimilarity
                )
                _customCompareResultState.value = CompareResultState.Success(result)
            } catch (e: Exception) {
                _customCompareResultState.value = CompareResultState.Error(e.message ?: "Unknown error")
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun createPoseMetricsFromAnalysis(analysis: AnalysisResponse): PoseMetrics {
        val confidence = analysis.confidence
        // Map AnalysisResponse metrics to PoseMetrics fields by name
        fun scoreFor(name: String): Double =
            analysis.metrics.find { it.name.equals(name, ignoreCase = true) }?.score ?: confidence
        fun statusFor(name: String): String =
            analysis.metrics.find { it.name.equals(name, ignoreCase = true) }?.status ?: "good"

        return PoseMetrics(
            cadenceEstimateSPM = 170.0,
            cadenceScore = scoreFor("Cadence"),
            cadenceStatus = statusFor("Cadence"),
            overstrideRiskScore = 1.0 - scoreFor("Overstride Risk"),
            overstrideStatus = statusFor("Overstride Risk"),
            trunkLeanDegrees = 5.0,
            trunkLeanScore = scoreFor("Trunk Lean"),
            trunkLeanStatus = statusFor("Trunk Lean"),
            kneeValgusRiskScore = 1.0 - scoreFor("Knee Valgus Risk"),
            kneeValgusStatus = statusFor("Knee Valgus Risk"),
            verticalOscillationScore = scoreFor("Vertical Oscillation"),
            verticalOscillationStatus = statusFor("Vertical Oscillation"),
            shoulderElevationScore = scoreFor("Shoulder Elevation"),
            shoulderElevationStatus = statusFor("Shoulder Elevation"),
            armSwingScore = scoreFor("Arm Swing"),
            armSwingStatus = statusFor("Arm Swing"),
            armCrossingScore = scoreFor("Arm Crossing"),
            armCrossingStatus = statusFor("Arm Crossing"),
            backwardElbowDriveScore = scoreFor("Backward Elbow Drive"),
            backwardElbowDriveStatus = statusFor("Backward Elbow Drive"),
            elbowAngleScore = scoreFor("Elbow Angle"),
            elbowAngleStatus = statusFor("Elbow Angle"),
            shoulderArmIndependenceScore = scoreFor("Shoulder-Arm Independence"),
            shoulderArmIndependenceStatus = statusFor("Shoulder-Arm Independence"),
            pelvicDropScore = scoreFor("Pelvic Drop"),
            pelvicDropStatus = statusFor("Pelvic Drop"),
            stepSymmetryScore = scoreFor("Step Symmetry"),
            stepSymmetryStatus = statusFor("Step Symmetry"),
            headForwardScore = scoreFor("Head Forward"),
            headForwardStatus = statusFor("Head Forward"),
            postureScore = scoreFor("Posture"),
            efficiencyScore = scoreFor("Efficiency"),
            stabilityScore = scoreFor("Stability"),
            propulsionScore = scoreFor("Propulsion"),
            armMechanicsScore = scoreFor("Arm Mechanics"),
            symmetryScore = scoreFor("Symmetry"),
            injuryRiskScore = 1.0 - scoreFor("Injury Risk"),
            frameCount = 300,
            videoDurationSeconds = 10.0,
            notes = emptyList(),
            videoQualityScore = analysis.videoQualityScore ?: 0.85,
            poseDetectionRate = 0.95,
            qualityNotes = analysis.qualityNotes
        )
    }

    private fun buildMetricsComparison(a: AnalysisResponse, b: AnalysisResponse): List<MetricComparison> {
        val allKeys = (a.metrics.map { it.name } + b.metrics.map { it.name }).distinct()
        return allKeys.map { key ->
            val metricA = a.metrics.find { it.name == key }
            val metricB = b.metrics.find { it.name == key }
            val scoreA = metricA?.score ?: 0.0
            val scoreB = metricB?.score ?: 0.0
            val gap = scoreB - scoreA
            val gapPct = kotlin.math.abs(gap)
            MetricComparison(
                metric = key,
                metricKey = key.lowercase().replace(" ", "_"),
                userScore = scoreA,
                athleteScore = scoreB,
                userLabel = "${(scoreA * 100).toInt()}%",
                athleteLabel = "${(scoreB * 100).toInt()}%",
                userValue = scoreA,
                athleteValue = scoreB,
                gap = gap,
                gapPct = gapPct,
                status = when {
                    gap > 0.05 -> "gap"
                    gap < -0.05 -> "ahead"
                    else -> "on_par"
                }
            )
        }
    }
}

// ── Entity → domain mapping (shared with AppViewModel) ────────────────────────

private fun AnalysisHistoryEntity.toItem(gson: Gson): AnalysisHistoryItem {
    val result: AnalysisResponse = gson.fromJson(analysisJson, AnalysisResponse::class.java)
    return AnalysisHistoryItem(
        id = id.toString(),
        createdAt = createdAt,
        videoFilename = videoUri.substringAfterLast('/'),
        result = result
    )
}
