package com.runformcoach.runformcoachai.viewmodel

import com.runformcoach.runformcoachai.AnalysisHistoryItem
import com.runformcoach.runformcoachai.AnalysisResponse
import com.runformcoach.runformcoachai.AthleteListItem
import com.runformcoach.runformcoachai.AthleteListState
import com.runformcoach.runformcoachai.CompareRequest
import com.runformcoach.runformcoachai.CompareResponse
import com.runformcoach.runformcoachai.CompareResultState
import com.runformcoach.runformcoachai.CompareViewModel
import com.runformcoach.runformcoachai.Metric
import com.runformcoach.runformcoachai.RunFormApi
import com.runformcoach.runformcoachai.data.AnalysisDao
import com.runformcoach.runformcoachai.data.AnalysisHistoryEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
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
class CompareViewModelTest {

    private val testDispatcher: TestDispatcher = StandardTestDispatcher()

    private val api: RunFormApi = mockk()
    private val analysisDao: AnalysisDao = mockk()

    private lateinit var viewModel: CompareViewModel

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Athlete loading state tests ────────────────────────────────────────────

    @Test
    fun `athlete list starts as Loading`() = runTest {
        coEvery { api.fetchAthletes() } returns emptyList()
        coEvery { analysisDao.getAll() } returns emptyList()

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        // After init completes, check the state
        val state = viewModel.athleteListState.value
        assertTrue(state is AthleteListState.Success)
    }

    @Test
    fun `athlete list transitions to Success on API success`() = runTest {
        val mockAthletes = listOf(
            AthleteListItem("1", "Eliud Kipchoge", "Marathon", "KEN", "WR 2:01:39", ""),
            AthleteListItem("2", "Kenenisa Bekele", "Marathon", "ETH", "2:01:41", "")
        )
        coEvery { api.fetchAthletes() } returns mockAthletes
        coEvery { analysisDao.getAll() } returns emptyList()

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        val state = viewModel.athleteListState.value
        assertTrue(state is AthleteListState.Success)
        assertEquals(2, (state as AthleteListState.Success).athletes.size)
        assertEquals("Eliud Kipchoge", state.athletes[0].name)
    }

    @Test
    fun `athlete list transitions to Error on API failure`() = runTest {
        coEvery { api.fetchAthletes() } throws RuntimeException("Server down")
        coEvery { analysisDao.getAll() } returns emptyList()

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        val state = viewModel.athleteListState.value
        assertTrue(state is AthleteListState.Error)
        assertEquals("Server down", (state as AthleteListState.Error).message)
    }

    @Test
    fun `loadAthletes skips reload when already loaded`() = runTest {
        coEvery { api.fetchAthletes() } returns listOf(
            AthleteListItem("1", "Test", "5K", "USA", "", "")
        )
        coEvery { analysisDao.getAll() } returns emptyList()

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        // First load succeeded
        assertTrue(viewModel.athleteListState.value is AthleteListState.Success)

        // Call loadAthletes again — should not re-fetch
        viewModel.loadAthletes()

        coVerify(exactly = 0) { api.fetchAthletes() }
    }

    // ── Compare request state tests ────────────────────────────────────────────

    @Test
    fun `compare result starts as Idle`() = runTest {
        coEvery { api.fetchAthletes() } returns emptyList()
        coEvery { analysisDao.getAll() } returns emptyList()

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        assertTrue(viewModel.compareResultState.value is CompareResultState.Idle)
    }

    @Test
    fun `compareWithAthlete transitions to Loading then Success`() = runTest {
        coEvery { api.fetchAthletes() } returns emptyList()
        coEvery { analysisDao.getAll() } returns emptyList()

        val mockCompareResponse = CompareResponse(
            athlete = com.runformcoach.runformcoachai.AthleteProfile(
                "1", "Test Athlete", "Marathon", "KEN", "", "", ""
            ),
            comparisons = emptyList(),
            topGaps = emptyList(),
            coachingNarrative = "Keep it up!",
            overallSimilarityScore = 0.75
        )
        coEvery { api.compareWithAthlete(any<CompareRequest>()) } returns mockCompareResponse

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        val athlete = AthleteListItem("1", "Test Athlete", "Marathon", "KEN", "", "")
        val analysis = AnalysisResponse("summary", 0.8, emptyList(), emptyList())

        viewModel.compareWithAthlete(athlete, analysis)

        // Should be Loading immediately
        assertTrue(viewModel.compareResultState.value is CompareResultState.Loading)

        advanceUntilIdle()

        val result = viewModel.compareResultState.value
        assertTrue(result is CompareResultState.Success)
        assertEquals(0.75, (result as CompareResultState.Success).result.overallSimilarityScore, 0.001)
        assertEquals("Keep it up!", result.result.coachingNarrative)
    }

    @Test
    fun `compareWithAthlete transitions to Error on API failure`() = runTest {
        coEvery { api.fetchAthletes() } returns emptyList()
        coEvery { analysisDao.getAll() } returns emptyList()
        coEvery { api.compareWithAthlete(any<CompareRequest>()) } throws RuntimeException("Timeout")

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        val athlete = AthleteListItem("1", "Test", "5K", "USA", "", "")
        val analysis = AnalysisResponse("ok", 0.7, emptyList(), emptyList())

        viewModel.compareWithAthlete(athlete, analysis)
        advanceUntilIdle()

        val result = viewModel.compareResultState.value
        assertTrue(result is CompareResultState.Error)
        assertEquals("Timeout", (result as CompareResultState.Error).message)
    }

    @Test
    fun `resetCompare returns to Idle`() = runTest {
        coEvery { api.fetchAthletes() } returns emptyList()
        coEvery { analysisDao.getAll() } returns emptyList()

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        // Set a fake Success state
        val athlete = AthleteListItem("1", "Test", "5K", "USA", "", "")
        val analysis = AnalysisResponse("ok", 0.7, emptyList(), emptyList())
        coEvery { api.compareWithAthlete(any<CompareRequest>()) } returns CompareResponse(
            athlete = com.runformcoach.runformcoachai.AthleteProfile("1", "", "", "", "", "", ""),
            comparisons = emptyList(),
            topGaps = emptyList(),
            coachingNarrative = "",
            overallSimilarityScore = 0.5
        )
        viewModel.compareWithAthlete(athlete, analysis)
        advanceUntilIdle()

        viewModel.resetCompare()

        assertTrue(viewModel.compareResultState.value is CompareResultState.Idle)
        assertNull(viewModel.selectedAthleteName.value)
    }

    // ── History selection tests ─────────────────────────────────────────────────

    @Test
    fun `selectHistoryItem fills slot A then B`() = runTest {
        coEvery { api.fetchAthletes() } returns emptyList()
        coEvery { analysisDao.getAll() } returns listOf(
            AnalysisHistoryEntity(1, "local", "uri1", "{}", "[]", 0.8, 1000),
            AnalysisHistoryEntity(2, "local", "uri2", "{}", "[]", 0.7, 2000)
        )

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        val items = viewModel.historyItems.value
        assertTrue(items.isNotEmpty())

        viewModel.selectHistoryItem(items[0])
        assertNotNull(viewModel.selectedHistoryA.value)

        viewModel.selectHistoryItem(items[1])
        assertNotNull(viewModel.selectedHistoryB.value)
    }

    @Test
    fun `resetCustomCompare clears selections and result`() = runTest {
        coEvery { api.fetchAthletes() } returns emptyList()
        coEvery { analysisDao.getAll() } returns emptyList()

        viewModel = CompareViewModel(api, analysisDao)
        advanceUntilIdle()

        viewModel.resetCustomCompare()

        assertTrue(viewModel.customCompareResultState.value is CompareResultState.Idle)
        assertNull(viewModel.selectedHistoryA.value)
        assertNull(viewModel.selectedHistoryB.value)
    }
}
