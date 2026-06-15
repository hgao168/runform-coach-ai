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
import com.runformcoach.runformcoachai.utils.VideoCompressor
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

    // ── RF-206: Video Compression ──────────────────────────────────────────────

    /** Whether the video should be compressed before upload. */
    var shouldCompress by mutableStateOf(true)

    /** Compression progress 0.0..1.0 (only meaningful when compressing). */
    var compressionProgress by mutableStateOf(0f)

    /** Whether compression is currently in progress. */
    var isCompressing by mutableStateOf(false)

    /** Compression result message (e.g. size reduction info). */
    var compressionMessage by mutableStateOf("")

    /** Path to the compressed file (set after compression completes). */
    private var compressedFilePath: String? = null

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

    /** Sub-screen navigation within Plan tab: "main" | "saved" | "edit" */
    var planSubScreen by mutableStateOf("main")
        private set

    fun showSavedPlans() { planSubScreen = "saved" }
    fun showEditPlan() { planSubScreen = "edit" }
    fun backToMainPlan() { planSubScreen = "main" }

    /** Currently editing week index (0-based) for EditPlanScreen */
    var editingWeekIndex by mutableStateOf(0)

    /** Currently editing day index within the week for EditPlanScreen */
    var editingDayIndex by mutableStateOf(0)

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

    /** Compress the selected video before analysis. Call this from the UI. */
    fun compressAndAnalyze() {
        val uri = selectedVideoUri ?: return
        isCompressing = true
        compressionProgress = 0f
        compressionMessage = ""
        viewModelScope.launch {
            try {
                val originalSize = withContext(Dispatchers.IO) {
                    appContext.contentResolver.openInputStream(uri)?.use { it.available().toLong() } ?: 0L
                }
                val compressedFile = VideoCompressor.compress(
                    context = appContext,
                    inputUri = uri,
                    onProgress = { progress ->
                        compressionProgress = progress
                    }
                )
                compressedFilePath = compressedFile.absolutePath
                val compressedSize = compressedFile.length()
                val reduction = if (originalSize > 0) {
                    ((1.0 - compressedSize.toDouble() / originalSize) * 100).toInt()
                } else 0

                compressionMessage = "Reduced from ${formatBytes(originalSize)} to ${formatBytes(compressedSize)}"
                isCompressing = false
                compressionProgress = 1f
            } catch (e: Exception) {
                // Compression failed — proceed with original
                compressedFilePath = null
                compressionMessage = "Compression skipped: ${e.message}"
                isCompressing = false
                compressionProgress = 1f
            }
        }
    }

    /** Start the actual analysis after compression (or skip). */
    fun analyzeVideo() {
        val uri = selectedVideoUri ?: return
        analysisState = AnalysisState.Loading
        viewModelScope.launch {
            try {
                val sourceUri = if (compressedFilePath != null) {
                    Uri.fromFile(File(compressedFilePath!!))
                } else {
                    uri
                }
                val videoFile = withContext(Dispatchers.IO) {
                    copyUriToTempFile(appContext, sourceUri)
                }
                val videoPart = VideoPartFactory.buildVideoPart(videoFile)
                val modePart = VideoPartFactory.buildModePart(selectedMode)
                val result = api.analyzeVideo(videoPart, modePart)
                analysisState = AnalysisState.Success(result)
                saveAnalysisToRoom(videoFile.name, sourceUri.toString(), result)
                // Clean up compressed file
                compressedFilePath?.let { File(it).delete() }
                compressedFilePath = null
                withContext(Dispatchers.IO) { videoFile.delete() }
            } catch (e: Exception) {
                analysisState = AnalysisState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun resetAnalysis() {
        analysisState = AnalysisState.Idle
        selectedVideoUri = null
        compressedFilePath?.let { File(it).delete() }
        compressedFilePath = null
        compressionProgress = 0f
        isCompressing = false
        compressionMessage = ""
    }

    private fun formatBytes(bytes: Long): String {
        return when {
            bytes >= 1_000_000 -> String.format("%.1f MB", bytes / 1_000_000.0)
            bytes >= 1_000 -> String.format("%.0f KB", bytes / 1_000.0)
            else -> "$bytes B"
        }
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

    /** Update a workout in the current plan's marathon/race week and persist to Room. */
    fun updateWorkout(
        planEntity: SavedPlanEntity,
        weekIndex: Int,
        workoutIndex: Int,
        updatedWorkout: PlannedWorkout
    ) {
        runCatching {
            val plan: TrainingPlanResponse = gson.fromJson(planEntity.planJson, TrainingPlanResponse::class.java)

            val updatedPlan = if (plan.marathonPlan != null) {
                val weeks = plan.marathonPlan.weeks.toMutableList()
                if (weekIndex >= weeks.size) return@runCatching
                val week = weeks[weekIndex]
                val workouts = week.workouts.toMutableList()
                if (workoutIndex < workouts.size) {
                    workouts[workoutIndex] = updatedWorkout
                } else {
                    workouts.add(updatedWorkout)
                }
                weeks[weekIndex] = week.copy(workouts = workouts)
                plan.copy(marathonPlan = plan.marathonPlan.copy(weeks = weeks))
            } else if (plan.racePlan != null) {
                val weeks = plan.racePlan.weeks.toMutableList()
                if (weekIndex >= weeks.size) return@runCatching
                val week = weeks[weekIndex]
                val workouts = week.workouts.toMutableList()
                if (workoutIndex < workouts.size) {
                    workouts[workoutIndex] = updatedWorkout
                } else {
                    workouts.add(updatedWorkout)
                }
                weeks[weekIndex] = week.copy(workouts = workouts)
                plan.copy(racePlan = plan.racePlan.copy(weeks = weeks))
            } else {
                return@runCatching
            }

            val json = gson.toJson(updatedPlan)
            viewModelScope.launch(Dispatchers.IO) {
                planDao.insert(
                    planEntity.copy(planJson = json, createdAt = System.currentTimeMillis())
                )
            }
            planState = PlanState.Success(updatedPlan)
        }
    }

    /** Delete a workout from the current plan's marathon/race week. */
    fun deleteWorkout(planEntity: SavedPlanEntity, weekIndex: Int, workoutIndex: Int) {
        runCatching {
            val plan: TrainingPlanResponse = gson.fromJson(planEntity.planJson, TrainingPlanResponse::class.java)

            val updatedPlan = if (plan.marathonPlan != null) {
                val weeks = plan.marathonPlan.weeks.toMutableList()
                if (weekIndex >= weeks.size) return@runCatching
                val week = weeks[weekIndex]
                val workouts = week.workouts.toMutableList()
                if (workoutIndex >= workouts.size) return@runCatching
                workouts.removeAt(workoutIndex)
                weeks[weekIndex] = week.copy(workouts = workouts)
                plan.copy(marathonPlan = plan.marathonPlan.copy(weeks = weeks))
            } else if (plan.racePlan != null) {
                val weeks = plan.racePlan.weeks.toMutableList()
                if (weekIndex >= weeks.size) return@runCatching
                val week = weeks[weekIndex]
                val workouts = week.workouts.toMutableList()
                if (workoutIndex >= workouts.size) return@runCatching
                workouts.removeAt(workoutIndex)
                weeks[weekIndex] = week.copy(workouts = workouts)
                plan.copy(racePlan = plan.racePlan.copy(weeks = weeks))
            } else {
                return@runCatching
            }

            val json = gson.toJson(updatedPlan)
            viewModelScope.launch(Dispatchers.IO) {
                planDao.insert(
                    planEntity.copy(planJson = json, createdAt = System.currentTimeMillis())
                )
            }
            planState = PlanState.Success(updatedPlan)
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
