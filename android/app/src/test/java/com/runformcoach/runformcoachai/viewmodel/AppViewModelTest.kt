package com.runformcoach.runformcoachai.viewmodel

import android.content.Context
import android.net.Uri
import com.google.gson.Gson
import com.runformcoach.runformcoachai.AnalysisResponse
import com.runformcoach.runformcoachai.AnalysisState
import com.runformcoach.runformcoachai.AppViewModel
import com.runformcoach.runformcoachai.Metric
import com.runformcoach.runformcoachai.RunFormApi
import com.runformcoach.runformcoachai.TesterProfile
import com.runformcoach.runformcoachai.data.AnalysisDao
import com.runformcoach.runformcoachai.data.AnalysisHistoryEntity
import com.runformcoach.runformcoachai.data.PlanDao
import com.runformcoach.runformcoachai.data.ProfileDao
import com.runformcoach.runformcoachai.data.RunFormDatabase
import com.runformcoach.runformcoachai.data.RunnerProfileEntity
import io.mockk.Runs
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModelTest {

    private val testDispatcher: TestDispatcher = StandardTestDispatcher()

    // Mocks
    private val appContext: Context = mockk(relaxed = true) {
        every { cacheDir } returns java.io.File(System.getProperty("java.io.tmpdir"))
        every { contentResolver.openInputStream(any()) } returns java.io.ByteArrayInputStream("mock-video".toByteArray())
    }
    private val api: RunFormApi = mockk()
    private val database: RunFormDatabase = mockk()
    private val analysisDao: AnalysisDao = mockk()
    private val profileDao: ProfileDao = mockk()
    private val planDao: PlanDao = mockk()

    private lateinit var viewModel: AppViewModel

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        // DAOs return empty by default
        coEvery { profileDao.getByUser() } returns null
        coEvery { analysisDao.observeAll() } returns emptyFlow()
        coEvery { analysisDao.countByUser() } returns 0

        viewModel = AppViewModel(appContext, api, database, analysisDao, profileDao, planDao)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Analysis state machine tests ───────────────────────────────────────────

    @Test
    fun `analysis state starts as Idle`() = runTest {
        assertTrue(viewModel.analysisState is AnalysisState.Idle)
    }

    @Test
    fun `analyzeVideo transitions Idle to Loading`() = runTest {
        // Arrange: set a video URI
        val uri: Uri = mockk(relaxed = true)
        viewModel.selectedVideoUri = uri

        // Act
        viewModel.analyzeVideo()

        // Assert: state transitions to Loading immediately (before coroutine executes)
        assertEquals(AnalysisState.Loading::class, viewModel.analysisState::class)
    }

    @Test
    fun `analyzeVideo transitions to Success on API success`() = runTest {
        val uri: Uri = mockk(relaxed = true)
        viewModel.selectedVideoUri = uri

        val mockResponse = AnalysisResponse(
            summary = "Good form",
            confidence = 0.85,
            metrics = listOf(Metric("Cadence", 0.8, "good", "Steady rhythm")),
            issues = emptyList()
        )

        coEvery { api.analyzeVideo(any(), any()) } returns mockResponse
        coEvery { analysisDao.insert(any()) } returns 1L
        every { database.analysisDao() } returns analysisDao

        viewModel.analyzeVideo()
        advanceUntilIdle()

        val state = viewModel.analysisState
        assertTrue(state is AnalysisState.Success)
        assertEquals(0.85, (state as AnalysisState.Success).result.confidence, 0.001)
        assertEquals("Good form", state.result.summary)
    }

    @Test
    fun `analyzeVideo transitions to Error on API failure`() = runTest {
        val uri: Uri = mockk(relaxed = true)
        viewModel.selectedVideoUri = uri

        coEvery { api.analyzeVideo(any(), any()) } throws RuntimeException("Network error")

        viewModel.analyzeVideo()
        advanceUntilIdle()

        val state = viewModel.analysisState
        assertTrue(state is AnalysisState.Error)
        assertEquals("Network error", (state as AnalysisState.Error).message)
    }

    @Test
    fun `analyzeVideo does nothing when no video selected`() = runTest {
        viewModel.selectedVideoUri = null
        viewModel.analyzeVideo()
        assertTrue(viewModel.analysisState is AnalysisState.Idle)
    }

    @Test
    fun `resetAnalysis returns to Idle and clears URI`() = runTest {
        val uri: Uri = mockk(relaxed = true)
        viewModel.selectedVideoUri = uri
        viewModel.analysisState = AnalysisState.Success(
            AnalysisResponse("ok", 0.5, emptyList(), emptyList())
        )

        viewModel.resetAnalysis()

        assertTrue(viewModel.analysisState is AnalysisState.Idle)
        assertNull(viewModel.selectedVideoUri)
    }

    // ── History CRUD tests ─────────────────────────────────────────────────────

    @Test
    fun `history is initially empty`() = runTest {
        coEvery { analysisDao.observeAll() } returns flowOf(emptyList())
        advanceUntilIdle()
        assertTrue(viewModel.history.isEmpty())
    }

    @Test
    fun `history loads from Room on init`() = runTest {
        val entity = AnalysisHistoryEntity(
            id = 1,
            userId = "local",
            videoUri = "content://video/1",
            analysisJson = """{"summary":"test","confidence":0.9,"metrics":[],"issues":[]}""",
            metricsJson = "[]",
            confidence = 0.9,
            createdAt = 1000L
        )

        coEvery { analysisDao.observeAll() } returns flowOf(listOf(entity))
        coEvery { profileDao.getByUser() } returns null

        // Re-create ViewModel so init picks up the flow
        viewModel = AppViewModel(appContext, api, database, analysisDao, profileDao, planDao)
        advanceUntilIdle()

        assertEquals(1, viewModel.history.size)
        assertEquals("test", viewModel.history[0].result.summary)
        assertEquals("1", viewModel.history[0].id)
    }

    @Test
    fun `clearHistory deletes all from DAO`() = runTest {
        coEvery { analysisDao.deleteAll() } just Runs

        viewModel.clearHistory()
        advanceUntilIdle()

        coVerify(exactly = 1) { analysisDao.deleteAll() }
    }

    // ── Profile tests ──────────────────────────────────────────────────────────

    @Test
    fun `updateProfile updates state and persists`() = runTest {
        coEvery { profileDao.upsert(any()) } just Runs

        val newProfile = TesterProfile(
            firstName = "Test",
            lastName = "Runner",
            level = "Advanced",
            weeklyMileageKm = 50.0
        )
        viewModel.updateProfile(newProfile)
        advanceUntilIdle()

        assertEquals("Test Runner", viewModel.profile.displayName)
        assertEquals("Advanced", viewModel.profile.level)
        assertEquals(50.0, viewModel.profile.weeklyMileageKm, 0.001)

        coVerify(exactly = 1) { profileDao.upsert(any()) }
    }

    @Test
    fun `loads profile from Room on init`() = runTest {
        val storedProfile = TesterProfile(firstName = "Jane", level = "Intermediate")
        val entity = RunnerProfileEntity(
            id = 1,
            userId = "local",
            profileJson = Gson().toJson(storedProfile),
            updatedAt = System.currentTimeMillis()
        )

        coEvery { profileDao.getByUser() } returns entity
        coEvery { analysisDao.observeAll() } returns emptyFlow()

        viewModel = AppViewModel(appContext, api, database, analysisDao, profileDao, planDao)
        advanceUntilIdle()

        assertEquals("Jane", viewModel.profile.firstName)
        assertEquals("Intermediate", viewModel.profile.level)
    }

    @Test
    fun `profile defaults when Room returns null`() = runTest {
        coEvery { profileDao.getByUser() } returns null
        coEvery { analysisDao.observeAll() } returns emptyFlow()

        viewModel = AppViewModel(appContext, api, database, analysisDao, profileDao, planDao)
        advanceUntilIdle()

        // Default TesterProfile values
        assertEquals("Runner", viewModel.profile.displayName)
        assertEquals("Beginner", viewModel.profile.level)
        assertEquals(15.0, viewModel.profile.weeklyMileageKm, 0.001)
    }
}
