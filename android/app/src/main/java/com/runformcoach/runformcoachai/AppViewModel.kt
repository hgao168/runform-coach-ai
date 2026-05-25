package com.runformcoach.runformcoachai

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

sealed class AnalysisState {
    object Idle : AnalysisState()
    object Loading : AnalysisState()
    data class Success(val result: AnalysisResponse) : AnalysisState()
    data class Error(val message: String) : AnalysisState()
}

sealed class PlanState {
    object Idle : PlanState()
    object Loading : PlanState()
    data class Success(val plan: TrainingPlanResponse) : PlanState()
    data class Error(val message: String) : PlanState()
}

class AppViewModel : ViewModel() {

    // ── Analyze Tab ───────────────────────────────────────────────────────────

    var selectedVideoUri by mutableStateOf<Uri?>(null)
    var captureVideoUri by mutableStateOf<Uri?>(null)
    var selectedMode by mutableStateOf("side")   // side / rear / front
    var analysisState by mutableStateOf<AnalysisState>(AnalysisState.Idle)

    // ── Profile Tab ───────────────────────────────────────────────────────────

    var profile by mutableStateOf(TesterProfile())
        private set

    // ── History Tab ───────────────────────────────────────────────────────────

    var history by mutableStateOf<List<AnalysisHistoryItem>>(emptyList())
        private set

    // ── Plan Tab ─────────────────────────────────────────────────────────────

    var planState by mutableStateOf<PlanState>(PlanState.Idle)

    // ── SharedPreferences ─────────────────────────────────────────────────────

    private val gson = Gson()
    private lateinit var prefs: SharedPreferences

    fun init(context: Context) {
        prefs = context.getSharedPreferences("runform_prefs", Context.MODE_PRIVATE)
        loadProfile()
        loadHistory()
    }

    // ── Analyze ───────────────────────────────────────────────────────────────

    fun analyzeVideo(context: Context) {
        val uri = selectedVideoUri ?: return
        analysisState = AnalysisState.Loading
        viewModelScope.launch {
            try {
                val videoFile = withContext(Dispatchers.IO) {
                    copyUriToTempFile(context, uri)
                }
                val videoPart = ApiClient.buildVideoPart(videoFile)
                val modePart = ApiClient.buildModePart(selectedMode)
                val result = ApiClient.api.analyzeVideo(videoPart, modePart)
                analysisState = AnalysisState.Success(result)
                addToHistory(videoFile.name, result)
                withContext(Dispatchers.IO) { videoFile.delete() }
            } catch (e: Exception) {
                analysisState = AnalysisState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun resetAnalysis() {
        analysisState = AnalysisState.Idle
        selectedVideoUri = null
    }

    // ── History ───────────────────────────────────────────────────────────────

    private fun addToHistory(filename: String, result: AnalysisResponse) {
        val item = AnalysisHistoryItem(
            id = UUID.randomUUID().toString(),
            createdAt = System.currentTimeMillis(),
            videoFilename = filename,
            result = result
        )
        val updated = (listOf(item) + history).take(50)
        history = updated
        saveHistory(updated)
    }

    fun clearHistory() {
        history = emptyList()
        prefs.edit { putString("history", "[]") }
    }

    // ── Training Plan ─────────────────────────────────────────────────────────

    fun generatePlan(
        weeklyKm: Double,
        target: String,
        selectedDays: List<String>,
        injuryFlag: Boolean,
        language: String = "en"
    ) {
        planState = PlanState.Loading
        val lastAnalysis = (analysisState as? AnalysisState.Success)?.result
        val formIssues = lastAnalysis?.issues?.map { issue ->
            FormIssueContext(
                title = issue.title,
                severity = issue.severity,
                explanation = issue.explanation,
                exerciseNames = issue.recommendedExercises.map { it.name }
            )
        } ?: emptyList()

        val request = TrainingPlanRequest(
            currentWeeklyKm = weeklyKm,
            target = target,
            availableRunningDays = selectedDays.size.coerceAtLeast(1),
            selectedRunDays = selectedDays,
            injuryFlag = injuryFlag,
            formIssues = formIssues,
            recentAnalysisSummary = lastAnalysis?.summary,
            recentAnalysisConfidence = lastAnalysis?.confidence,
            language = language
        )
        viewModelScope.launch {
            try {
                val plan = ApiClient.api.generatePlan(request)
                planState = PlanState.Success(plan)
            } catch (e: Exception) {
                planState = PlanState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun resetPlan() { planState = PlanState.Idle }

    // ── Profile ───────────────────────────────────────────────────────────────

    fun updateProfile(updated: TesterProfile) {
        profile = updated
        prefs.edit { putString("profile", gson.toJson(updated)) }
    }

    // ── Persistence helpers ───────────────────────────────────────────────────

    private fun loadProfile() {
        val json = prefs.getString("profile", null) ?: return
        runCatching { gson.fromJson(json, TesterProfile::class.java) }
            .onSuccess { profile = it }
    }

    private fun loadHistory() {
        val json = prefs.getString("history", "[]") ?: "[]"
        runCatching {
            val type = object : TypeToken<List<AnalysisHistoryItem>>() {}.type
            gson.fromJson<List<AnalysisHistoryItem>>(json, type)
        }.onSuccess { history = it ?: emptyList() }
    }

    private fun saveHistory(items: List<AnalysisHistoryItem>) {
        prefs.edit { putString("history", gson.toJson(items)) }
    }

    // ── Utility ───────────────────────────────────────────────────────────────

    private suspend fun copyUriToTempFile(context: Context, uri: Uri): File =
        withContext(Dispatchers.IO) {
            val file = File.createTempFile("upload_", ".mp4", context.cacheDir)
            context.contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { output -> input.copyTo(output) }
            }
            file
        }
}
