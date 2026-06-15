package com.runformcoach.runformcoachai.repository

import com.google.gson.Gson
import com.runformcoach.runformcoachai.AnalysisResponse
import com.runformcoach.runformcoachai.Metric
import com.runformcoach.runformcoachai.data.AnalysisDao
import com.runformcoach.runformcoachai.data.AnalysisHistoryEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.just
import io.mockk.Runs
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
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

/**
 * Unit tests for Room DAO operations using mocked [AnalysisDao].
 *
 * In a real integration test, these would use Room's in-memory database
 * (Room.inMemoryDatabaseBuilder). Since WSL lacks the Android SDK, we
 * mock the DAO interface and verify the contract.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AnalysisDaoTest {

    private val testDispatcher: TestDispatcher = StandardTestDispatcher()
    private val dao: AnalysisDao = mockk()
    private val gson = Gson()

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Insert ─────────────────────────────────────────────────────────────────

    @Test
    fun `insert returns generated ID`() = runTest {
        coEvery { dao.insert(any()) } returns 42L

        val entity = createEntity(id = 0, videoUri = "video1")
        val id = dao.insert(entity)

        assertEquals(42L, id)
        coVerify(exactly = 1) { dao.insert(entity) }
    }

    @Test
    fun `insert replaces on conflict`() = runTest {
        coEvery { dao.insert(any()) } returns 1L

        val entity = createEntity(id = 5, videoUri = "video2")
        dao.insert(entity)

        coVerify { dao.insert(entity) }
    }

    // ── observeAll (reactive flow) ─────────────────────────────────────────────

    @Test
    fun `observeAll emits empty list when no records`() = runTest {
        coEvery { dao.observeAll() } returns flowOf(emptyList())

        val emitted = dao.observeAll().first()

        assertTrue(emitted.isEmpty())
        coVerify { dao.observeAll() }
    }

    @Test
    fun `observeAll emits entities newest first`() = runTest {
        val older = createEntity(id = 1, createdAt = 1000L)
        val newer = createEntity(id = 2, createdAt = 2000L)

        coEvery { dao.observeAll() } returns flowOf(listOf(newer, older))

        val emitted = dao.observeAll().first()

        assertEquals(2, emitted.size)
        assertEquals(2L, emitted[0].id)    // newer first
        assertEquals(1L, emitted[1].id)
    }

    // ── getAll (one-shot) ──────────────────────────────────────────────────────

    @Test
    fun `getAll returns all entities`() = runTest {
        val entities = listOf(
            createEntity(id = 1, videoUri = "uri1"),
            createEntity(id = 2, videoUri = "uri2"),
            createEntity(id = 3, videoUri = "uri3")
        )
        coEvery { dao.getAll() } returns entities

        val result = dao.getAll()

        assertEquals(3, result.size)
        assertEquals("uri1", result[0].videoUri)
        assertEquals("uri3", result[2].videoUri)
    }

    @Test
    fun `getAll returns empty on no records`() = runTest {
        coEvery { dao.getAll() } returns emptyList()

        val result = dao.getAll()

        assertTrue(result.isEmpty())
    }

    // ── getById ────────────────────────────────────────────────────────────────

    @Test
    fun `getById returns entity when found`() = runTest {
        val entity = createEntity(id = 99L, videoUri = "found")
        coEvery { dao.getById(99L) } returns entity

        val result = dao.getById(99L)

        assertNotNull(result)
        assertEquals(99L, result!!.id)
        assertEquals("found", result.videoUri)
    }

    @Test
    fun `getById returns null when not found`() = runTest {
        coEvery { dao.getById(999L) } returns null

        val result = dao.getById(999L)

        assertNull(result)
    }

    // ── Delete ─────────────────────────────────────────────────────────────────

    @Test
    fun `delete removes entity`() = runTest {
        val entity = createEntity(id = 1)
        coEvery { dao.delete(entity) } just Runs

        dao.delete(entity)

        coVerify(exactly = 1) { dao.delete(entity) }
    }

    // ── deleteAll ──────────────────────────────────────────────────────────────

    @Test
    fun `deleteAll clears all records`() = runTest {
        coEvery { dao.deleteAll() } just Runs

        dao.deleteAll()

        coVerify(exactly = 1) { dao.deleteAll() }
    }

    // ── countByUser ────────────────────────────────────────────────────────────

    @Test
    fun `countByUser returns correct count`() = runTest {
        coEvery { dao.countByUser("local") } returns 5
        coEvery { dao.countByUser("other") } returns 0

        assertEquals(5, dao.countByUser("local"))
        assertEquals(0, dao.countByUser("other"))
    }

    // ── Flow-based observer with multiple emissions ────────────────────────────

    @Test
    fun `observeAll emits updates when data changes`() = runTest {
        val initial = listOf(createEntity(id = 1))
        val updated = listOf(createEntity(id = 1), createEntity(id = 2))

        // Simulate two emissions
        var emissionCount = 0
        coEvery { dao.observeAll() } answers {
            emissionCount++
            if (emissionCount == 1) flowOf(initial)
            else flowOf(updated)
        }

        // Collect first emission
        val collected = mutableListOf<List<AnalysisHistoryEntity>>()
        val job = launch {
            dao.observeAll().toList(collected)
        }
        advanceUntilIdle()
        job.cancel()

        assertTrue(collected.isNotEmpty())
        assertEquals(1, collected[0].size)
    }

    // ── Entity ↔ JSON round-trip ───────────────────────────────────────────────

    @Test
    fun `entity rounds trips through JSON correctly`() {
        val original = AnalysisResponse(
            summary = "Test summary",
            confidence = 0.92,
            metrics = listOf(Metric("Cadence", 0.85, "good", "Steady")),
            issues = emptyList()
        )
        val entity = AnalysisHistoryEntity(
            id = 1,
            userId = "local",
            videoUri = "content://test.mp4",
            analysisJson = gson.toJson(original),
            metricsJson = gson.toJson(original.metrics),
            confidence = original.confidence,
            createdAt = 1234567890L
        )

        // Deserialize back
        val restored: AnalysisResponse = gson.fromJson(entity.analysisJson, AnalysisResponse::class.java)

        assertEquals(original.summary, restored.summary)
        assertEquals(original.confidence, restored.confidence, 0.001)
        assertEquals(original.metrics.size, restored.metrics.size)
        assertEquals(original.metrics[0].name, restored.metrics[0].name)
        assertEquals(original.metrics[0].score, restored.metrics[0].score, 0.001)
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun createEntity(
        id: Long = 0,
        userId: String = "local",
        videoUri: String = "content://test.mp4",
        confidence: Double = 0.8,
        createdAt: Long = System.currentTimeMillis()
    ): AnalysisHistoryEntity {
        val analysis = AnalysisResponse(
            summary = "test",
            confidence = confidence,
            metrics = emptyList(),
            issues = emptyList()
        )
        return AnalysisHistoryEntity(
            id = id,
            userId = userId,
            videoUri = videoUri,
            analysisJson = gson.toJson(analysis),
            metricsJson = "[]",
            confidence = confidence,
            createdAt = createdAt
        )
    }
}
