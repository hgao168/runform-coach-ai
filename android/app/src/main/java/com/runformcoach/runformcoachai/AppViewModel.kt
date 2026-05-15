package com.runformcoach.runformcoachai

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.runformcoach.runformcoachai.data.AnalysisDao
import com.runformcoach.runformcoachai.data.AnalysisHistoryEntity
import com.runformcoach.runformcoachai.data.MigrationHelper
import com.runformcoach.runformcoachai.data.PlanDao
import com.runformcoach.runformcoachai.data.ProfileDao
import com.runformcoach.runformcoachai.data.RunFormDatabase
import com.runformcoach.runformcoachai.data.RunnerProfileEntity
import com.runformcoach.runformcoachai.data.SavedPlanEntity
import com.runformcoach.runformcoachai.di.VideoPartFactory
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import javax.inject.Inject

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

@HiltViewModel
class AppViewModel @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val api: RunFormApi,
    private val database: RunFormDatabase,
    private val analysisDao: AnalysisDao,
    private val profileDao: ProfileDao,
    private val planDao: PlanDao
) : ViewModel() {

    private val gson = Gson()

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

    /** Which plan mode is active: "weekly", "marathon", "race" */
    var planType by mutableStateOf("weekly")

    /** Marathon plan generation inputs */
    var marathonMajor by mutableStateOf("Berlin")
    var marathonTargetTime by mutableStateOf("")
    var marathonPlanWeeks by mutableStateOf(16)
    var trainingLevel by mutableStateOf("Intermediate")
    var planDurationWeeks by mutableStateOf<Int?>(null)

    /** Saved plans list (observed from Room) */
    var savedPlans by mutableStateOf<List<SavedPlanEntity>>(emptyList())
        private set

    init {
        // One-shot SharedPreferences → Room migration, then load from Room
        viewModelScope.launch {
            MigrationHelper.migrateIfNeeded(appContext, database)
            loadProfile()
            observeHistory()
            observeSavedPlans()
        }
    }

    // ── Analyze ───────────────────────────────────────────────────────────────

    fun analyzeVideo() {
        val uri = selectedVideoUri ?: return
        analysisState = AnalysisState.Loading
        viewModelScope.launch {
            try {
                val videoFile = withContext(Dispatchers.IO) {
                    copyUriToTempFile(appContext, uri)
                }
                val videoPart = VideoPartFactory.buildVideoPart(videoFile)
                val modePart = VideoPartFactory.buildModePart(selectedMode)
                val result = api.analyzeVideo(videoPart, modePart)
                analysisState = AnalysisState.Success(result)
                saveAnalysisToRoom(videoFile.name, uri.toString(), result)
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

    // ── History (Room-backed) ─────────────────────────────────────────────────

    private fun observeHistory() {
        viewModelScope.launch {
            analysisDao.observeAll()
                .map { entities -> entities.map { it.toDomainModel(gson) } }
                .catch { } // silently ignore DB read errors
                .collect { items -> history = items }
        }
    }

    private fun saveAnalysisToRoom(filename: String, videoUri: String, result: AnalysisResponse) {
        viewModelScope.launch(Dispatchers.IO) {
            analysisDao.insert(
                AnalysisHistoryEntity(
                    userId = "local",
                    videoUri = videoUri,
                    analysisJson = gson.toJson(result),
                    metricsJson = gson.toJson(result.metrics),
                    confidence = result.confidence,
                    createdAt = System.currentTimeMillis()
                )
            )
            // Trim to max 50 records
            val count = analysisDao.countByUser()
            if (count > 50) {
                // Keep newest 50 — delete oldest by collecting all and removing extras
                val all = analysisDao.getAll()
                all.drop(50).forEach { analysisDao.delete(it) }
            }
        }
    }

    fun clearHistory() {
        viewModelScope.launch(Dispatchers.IO) {
            analysisDao.deleteAll()
        }
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

        // Determine marathon/race block flags from planType
        val includeMarathon = planType == "marathon"
        val includeRace = planType == "race"

        val request = TrainingPlanRequest(
            currentWeeklyKm = weeklyKm,
            target = target,
            availableRunningDays = selectedDays.size.coerceAtLeast(1),
            selectedRunDays = selectedDays,
            injuryFlag = injuryFlag,
            formIssues = formIssues,
            recentAnalysisSummary = lastAnalysis?.summary,
            recentAnalysisConfidence = lastAnalysis?.confidence,
            language = language,
            marathonMajor = if (includeMarathon) marathonMajor else null,
            marathonPlanWeeks = if (includeMarathon) marathonPlanWeeks else null,
            includeMarathonBlock = includeMarathon,
            includeRaceBlock = includeRace,
            trainingLevel = trainingLevel,
            planDurationWeeks = planDurationWeeks
        )
        viewModelScope.launch {
            try {
                val plan = api.generatePlan(request)
                planState = PlanState.Success(plan)
            } catch (e: Exception) {
                planState = PlanState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun resetPlan() { planState = PlanState.Idle }

    // ── Saved Plans (Room-backed) ─────────────────────────────────────────────

    private fun observeSavedPlans() {
        viewModelScope.launch {
            planDao.observeAll()
                .catch { }
                .collect { entities -> savedPlans = entities }
        }
    }

    fun saveCurrentPlan() {
        val state = planState
        if (state !is PlanState.Success) return
        viewModelScope.launch(Dispatchers.IO) {
            planDao.insert(
                SavedPlanEntity(
                    userId = "local",
                    planJson = gson.toJson(state.plan),
                    planType = planType,
                    createdAt = System.currentTimeMillis()
                )
            )
        }
    }

    fun deleteSavedPlan(entity: SavedPlanEntity) {
        viewModelScope.launch(Dispatchers.IO) {
            planDao.delete(entity)
        }
    }

    fun loadSavedPlan(entity: SavedPlanEntity) {
        runCatching {
            val plan: TrainingPlanResponse = gson.fromJson(entity.planJson, TrainingPlanResponse::class.java)
            planState = PlanState.Success(plan)
            planType = entity.planType
        }
    }

    // ── Profile (Room-backed) ─────────────────────────────────────────────────

    fun updateProfile(updated: TesterProfile) {
        profile = updated
        viewModelScope.launch(Dispatchers.IO) {
            profileDao.upsert(
                RunnerProfileEntity(
                    userId = "local",
                    profileJson = gson.toJson(updated),
                    updatedAt = System.currentTimeMillis()
                )
            )
        }
    }

    private suspend fun loadProfile() {
        val entity = withContext(Dispatchers.IO) {
            profileDao.getByUser()
        }
        entity?.let {
            runCatching {
                gson.fromJson(it.profileJson, TesterProfile::class.java)
            }.onSuccess { profile = it }
        }
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

// ── Entity → domain mapping (used by observeHistory) ─────────────────────────

private fun AnalysisHistoryEntity.toDomainModel(gson: Gson): AnalysisHistoryItem {
    val result: AnalysisResponse = gson.fromJson(analysisJson, AnalysisResponse::class.java)
    return AnalysisHistoryItem(
        id = id.toString(),
        createdAt = createdAt,
        videoFilename = videoUri.substringAfterLast('/'),
        result = result
    )
}
