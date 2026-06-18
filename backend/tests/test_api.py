"""
API endpoint tests for RunForm backend.

Covers the public endpoints: health, athletes, analyze-metrics, compare.
Tests are written to work without a database or external API key.
"""

from datetime import datetime, timezone

import pytest

from app import main as main_mod
from app import strava_sync
from app import strava_oauth

# ---------------------------------------------------------------------------
# Health endpoint
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_health_returns_ok(client):
    """GET /health should return 200 with service info."""
    response = await client.get("/health")
    assert response.status_code == 200, response.text
    data = response.json()
    assert "status" in data
    assert data["service"] == "runform-coach-ai"
    assert data["version"] == "0.5.0"


# ---------------------------------------------------------------------------
# Athletes endpoint
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_list_athletes_returns_list(client):
    """GET /athletes should return a non-empty list of athlete profiles."""
    response = await client.get("/athletes")
    assert response.status_code == 200, response.text
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 5  # at least 5 elite athletes in the DB
    # Verify structure of first athlete
    first = data[0]
    for key in ("id", "name", "event", "nationality", "achievement"):
        assert key in first, f"Missing key '{key}' in athlete item"


# ---------------------------------------------------------------------------
# Analyze-metrics endpoint (requires valid PoseMetricsInput payload)
# ---------------------------------------------------------------------------


def _make_minimal_pose_input() -> dict:
    """Build a minimal valid PoseMetricsInput payload."""
    return {
        "cadence_estimate_spm": 165.0,
        "cadence_score": 0.7,
        "cadence_status": "Needs work",
        "overstride_risk_score": 0.6,
        "overstride_status": "Moderate risk",
        "trunk_lean_degrees": 12.0,
        "trunk_lean_score": 0.65,
        "trunk_lean_status": "Moderate",
        "knee_valgus_risk_score": 0.55,
        "knee_valgus_status": "Moderate risk",
        "frame_count": 120,
        "video_duration_seconds": 4.0,
    }


@pytest.mark.anyio
async def test_analyze_metrics_requires_openai_key_or_503(client):
    """POST /analyze-metrics without OpenAI API key returns 503."""
    response = await client.post("/analyze-metrics", json=_make_minimal_pose_input())
    # Without OPENAI_API_KEY the endpoint should return 503 (RuntimeError)
    assert response.status_code in (200, 503), response.text


@pytest.mark.anyio
async def test_analyze_metrics_rejects_missing_required_fields(client):
    """POST /analyze-metrics with empty body returns 422."""
    response = await client.post("/analyze-metrics", json={})
    assert response.status_code == 422, response.text


# ---------------------------------------------------------------------------
# Compare endpoint
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_compare_with_unknown_athlete_returns_404(client):
    """POST /compare with unknown athlete_id returns 404."""
    payload = {
        "user_metrics": _make_minimal_pose_input(),
        "athlete_id": "nonexistent_athlete",
    }
    response = await client.post("/compare", json=payload)
    assert response.status_code == 404, response.text


@pytest.mark.anyio
async def test_compare_requires_valid_payload(client):
    """POST /compare with empty body returns 422."""
    response = await client.post("/compare", json={})
    assert response.status_code == 422, response.text


# ---------------------------------------------------------------------------
# Training-plan endpoint
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_training_plan_requires_valid_payload(client):
    """POST /training-plan with empty body returns 422."""
    response = await client.post("/training-plan", json={})
    assert response.status_code == 422, response.text


# ---------------------------------------------------------------------------
# Analyze (video upload) endpoint
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_analyze_video_requires_video_file(client):
    """POST /analyze without a video file returns 422."""
    # Sending multipart without the required 'video' field
    response = await client.post("/analyze")
    assert response.status_code == 422, response.text


def test_transactional_email_uses_movenova_sender_by_default(monkeypatch):
    """Resend payload should use the production sender when no override is set."""
    captured_payload = {}

    class DummyResponse:
        def raise_for_status(self):
            return None

    def fake_post(url, headers, json, timeout):
        captured_payload.update(json)
        return DummyResponse()

    monkeypatch.setattr(main_mod, "RESEND_API_KEY", "test-resend-api-key")
    monkeypatch.setattr(main_mod, "RESEND_FROM_EMAIL", "")
    monkeypatch.setattr(main_mod.httpx, "post", fake_post)

    main_mod._send_transactional_email(
        recipient_email="runner@example.com",
        subject="Reset",
        html_body="<p>Reset</p>",
        text_body="Reset",
    )

    assert captured_payload["from"] == "noreply@movenova.ai"


def test_strava_app_callback_url_normalizes_bare_scheme(monkeypatch):
    monkeypatch.setenv("STRAVA_APP_CALLBACK_URL", "runformcoachai")

    assert strava_oauth.app_callback_url() == "runformcoachai://strava/callback"


def test_strava_app_callback_url_defaults_to_none(monkeypatch):
    monkeypatch.delenv("STRAVA_APP_CALLBACK_URL", raising=False)

    assert strava_oauth.app_callback_url() is None


def test_strava_state_preserves_requested_app_callback(monkeypatch):
    monkeypatch.setenv("STRAVA_CLIENT_SECRET", "test-strava-client-secret")

    state = strava_oauth.make_state(
        "test-user-001",
        app_callback_url="runformcoachai://strava/callback",
    )

    payload = strava_oauth.verify_state_payload(state)
    assert payload["uid"] == "test-user-001"
    assert payload["cb"] == "runformcoachai://strava/callback"


def test_strava_sync_defaults_to_eight_weeks_for_plan_history():
    assert strava_sync.STRAVA_LOOKBACK_DAYS == 56


def test_strava_week_window_returns_four_calendar_weeks():
    reference = datetime(2026, 6, 18, 12, 0, tzinfo=timezone.utc)

    week_starts = strava_sync._week_starts_for_window(reference, 4)

    assert [item.date().isoformat() for item in week_starts] == [
        "2026-05-25",
        "2026-06-01",
        "2026-06-08",
        "2026-06-15",
    ]


def test_strava_empty_week_summary_keeps_zero_week_in_status():
    week_start = datetime(2026, 6, 15, tzinfo=timezone.utc)

    summary = strava_sync._empty_week_summary(week_start)

    assert summary == {
        "week_start": week_start,
        "total_distance_m": 0.0,
        "run_count": 0,
        "longest_run_m": 0.0,
        "avg_pace_s_per_km": None,
        "intensity_score": 0.0,
    }
