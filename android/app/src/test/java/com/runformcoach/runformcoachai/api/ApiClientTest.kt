package com.runformcoach.runformcoachai.api

import com.google.gson.Gson
import com.runformcoach.runformcoachai.AnalysisResponse
import com.runformcoach.runformcoachai.FeedbackRequest
import com.runformcoach.runformcoachai.FeedbackResponse
import com.runformcoach.runformcoachai.Metric
import com.runformcoach.runformcoachai.RunFormApi
import com.runformcoach.runformcoachai.TrainingPlanRequest
import com.runformcoach.runformcoachai.TrainingPlanResponse
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.OkHttpClient
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

class ApiClientTest {

    private lateinit var server: MockWebServer
    private lateinit var api: RunFormApi

    @BeforeEach
    fun setup() {
        server = MockWebServer()
        server.start()

        val client = OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(5, TimeUnit.SECONDS)
            .build()

        api = Retrofit.Builder()
            .baseUrl(server.url("/"))
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(RunFormApi::class.java)
    }

    @AfterEach
    fun tearDown() {
        server.shutdown()
    }

    // ── POST /feedback ─────────────────────────────────────────────────────────

    @Test
    fun `submitFeedback returns success on 200`() = runBlocking {
        val responseJson = """{"received":true,"message":"Thank you for your feedback!"}"""
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(responseJson)
                .addHeader("Content-Type", "application/json")
        )

        val request = FeedbackRequest(
            analysisId = "abc-123",
            rating = 4,
            comment = "Very helpful analysis"
        )

        val response = api.submitFeedback(request)

        assertTrue(response.received)
        assertEquals("Thank you for your feedback!", response.message)

        val recordedRequest = server.takeRequest()
        assertEquals("POST", recordedRequest.method)
        assertTrue(recordedRequest.path!!.contains("feedback"))
    }

    @Test
    fun `submitFeedback with empty comment succeeds`() = runBlocking {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody("""{"received":true,"message":"OK"}""")
                .addHeader("Content-Type", "application/json")
        )

        val request = FeedbackRequest(analysisId = "xyz", rating = 3)
        val response = api.submitFeedback(request)

        assertTrue(response.received)
    }

    @Test
    fun `submitFeedback throws on server error 500`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(500))

        val request = FeedbackRequest(analysisId = "fail", rating = 2)

        try {
            api.submitFeedback(request)
            fail("Expected exception")
        } catch (e: Exception) {
            assertNotNull(e)
        }
    }

    // ── POST /training-plan ────────────────────────────────────────────────────

    @Test
    fun `generatePlan returns parsed response`() = runBlocking {
        val planJson = """
        {
            "summary": "4-week plan",
            "planned_weekly_km": 35.0,
            "running_days": 4,
            "workouts": [
                {
                    "day": "Mon",
                    "title": "Easy Run",
                    "category": "Easy",
                    "intensity": "Low",
                    "details": "30 min easy",
                    "purpose": "Recovery",
                    "distance_km": 5.0,
                    "duration_minutes": 30,
                    "coaching_focus": "Relax"
                }
            ],
            "notes": ["Stay hydrated"],
            "connected_analysis_used": true
        }
        """.trimIndent()

        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(planJson)
                .addHeader("Content-Type", "application/json")
        )

        val request = TrainingPlanRequest(
            currentWeeklyKm = 20.0,
            target = "10K",
            availableRunningDays = 4,
            selectedRunDays = listOf("Mon", "Wed", "Fri", "Sat"),
            injuryFlag = false
        )

        val response = api.generatePlan(request)

        assertEquals("4-week plan", response.summary)
        assertEquals(35.0, response.plannedWeeklyKm, 0.001)
        assertEquals(4, response.runningDays)
        assertEquals(1, response.workouts.size)
        assertEquals("Easy Run", response.workouts[0].title)
        assertEquals(1, response.notes.size)
        assertTrue(response.connectedAnalysisUsed)
    }

    @Test
    fun `generatePlan throws on 400`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(400).setBody("""{"error":"Invalid request"}"""))

        val request = TrainingPlanRequest(0.0, "", 0, emptyList(), false)

        try {
            api.generatePlan(request)
            fail("Expected exception")
        } catch (e: Exception) {
            assertNotNull(e)
        }
    }

    // ── GET /athletes ──────────────────────────────────────────────────────────

    @Test
    fun `fetchAthletes returns parsed list`() = runBlocking {
        val athletesJson = """
        [
            {
                "id": "1",
                "name": "Eliud Kipchoge",
                "event": "Marathon",
                "nationality": "KEN",
                "achievement": "WR 2:01:39",
                "photo_url": "https://example.com/photo.jpg"
            }
        ]
        """.trimIndent()

        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(athletesJson)
                .addHeader("Content-Type", "application/json")
        )

        val athletes = api.fetchAthletes()

        assertEquals(1, athletes.size)
        assertEquals("Eliud Kipchoge", athletes[0].name)
        assertEquals("Marathon", athletes[0].event)
        assertEquals("KEN", athletes[0].nationality)
    }

    @Test
    fun `fetchAthletes returns empty on empty array`() = runBlocking {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody("[]")
                .addHeader("Content-Type", "application/json")
        )

        val athletes = api.fetchAthletes()
        assertTrue(athletes.isEmpty())
    }

    @Test
    fun `fetchAthletes throws on network error`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(503))

        try {
            api.fetchAthletes()
            fail("Expected exception")
        } catch (e: Exception) {
            assertNotNull(e)
        }
    }

    // ── POST /compare ──────────────────────────────────────────────────────────

    @Test
    fun `compareWithAthlete returns parsed compare response`() = runBlocking {
        val compareJson = """
        {
            "athlete": {
                "id": "1",
                "name": "Kipchoge",
                "event": "Marathon",
                "nationality": "KEN",
                "achievement": "WR",
                "bio": "The GOAT",
                "photo_url": ""
            },
            "comparisons": [],
            "top_gaps": ["Cadence"],
            "coaching_narrative": "Focus on cadence.",
            "overall_similarity_score": 0.72
        }
        """.trimIndent()

        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody(compareJson)
                .addHeader("Content-Type", "application/json")
        )

        val response = api.compareWithAthlete(
            com.runformcoach.runformcoachai.CompareRequest(
                userMetrics = com.runformcoach.runformcoachai.PoseMetrics(),
                athleteId = "1",
                language = "en"
            )
        )

        assertEquals("Kipchoge", response.athlete.name)
        assertEquals(0.72, response.overallSimilarityScore, 0.001)
        assertEquals("Focus on cadence.", response.coachingNarrative)
        assertEquals(listOf("Cadence"), response.topGaps)
    }
}
