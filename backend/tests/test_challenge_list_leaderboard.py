"""
Tests covering GET /api/v1/challenges and GET /challenges/{id}/leaderboard
that were not in the original test_challenge_club.py suite.
"""

import pytest
from httpx import AsyncClient


CHALLENGE_ID = "14-day-form-challenge"


@pytest.mark.anyio
async def test_list_challenges_no_auth(client: AsyncClient):
    """GET /api/v1/challenges returns a list with at least the 14-day challenge."""
    resp = await client.get("/api/v1/challenges")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    ids = [c["id"] for c in data]
    assert CHALLENGE_ID in ids


@pytest.mark.anyio
async def test_list_challenges_with_user(client: AsyncClient, test_user: str):
    """GET /api/v1/challenges?ios_user_id=X includes personal participation fields."""
    resp = await client.get(f"/api/v1/challenges?ios_user_id={test_user}")
    assert resp.status_code == 200
    data = resp.json()
    challenge = [c for c in data if c["id"] == CHALLENGE_ID][0]
    assert "joined" in challenge
    assert "completed_days" in challenge
    assert "today_completed" in challenge


@pytest.mark.anyio
async def test_leaderboard_unknown_challenge_returns_404(client: AsyncClient):
    """Leaderboard for non-existent challenge returns 404."""
    resp = await client.get("/api/v1/challenges/nonexistent/leaderboard")
    assert resp.status_code == 404


@pytest.mark.anyio
async def test_leaderboard_returns_list(client: AsyncClient):
    """GET leaderboard returns a list (possibly empty if no participants)."""
    resp = await client.get(f"/api/v1/challenges/{CHALLENGE_ID}/leaderboard")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


@pytest.mark.anyio
async def test_leaderboard_with_joined_user(client: AsyncClient, test_user: str):
    """After joining and adding a session, user appears on leaderboard."""
    # Join
    await client.post(f"/api/v1/challenges/{CHALLENGE_ID}/join",
                      json={"ios_user_id": test_user})

    # Add a run session
    import tests.conftest as cf
    from app.db_models import User, RunSession
    from datetime import datetime, timezone, timedelta
    with cf._test_session_factory() as sess:
        user = sess.query(User).filter(User.ios_user_id == test_user).first()
        ts = datetime.now(timezone.utc) - timedelta(hours=1)
        rs = RunSession(
            user_id=user.id,
            start_time=ts,
            end_time=ts + timedelta(minutes=30),
            duration_sec=1800.0,
            avg_cadence=172.0,
            avg_vertical_oscillation=0.08,
        )
        sess.add(rs)
        sess.commit()

    resp = await client.get(f"/api/v1/challenges/{CHALLENGE_ID}/leaderboard")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 1
    entry = data[0]
    assert "rank" in entry
    assert "cadence_improvement_pct" in entry
    assert "overall_score_change" in entry


@pytest.mark.anyio
async def test_leaderboard_is_me_flag(client: AsyncClient, test_user: str):
    """When ios_user_id is provided, the calling user gets is_me=true."""
    # Join and add a session so user appears on leaderboard
    await client.post(f"/api/v1/challenges/{CHALLENGE_ID}/join",
                      json={"ios_user_id": test_user})
    import tests.conftest as cf
    from app.db_models import User, RunSession
    from datetime import datetime, timezone, timedelta
    with cf._test_session_factory() as sess:
        user = sess.query(User).filter(User.ios_user_id == test_user).first()
        ts = datetime.now(timezone.utc) - timedelta(hours=1)
        rs = RunSession(
            user_id=user.id,
            start_time=ts,
            end_time=ts + timedelta(minutes=30),
            duration_sec=1800.0,
            avg_cadence=172.0,
            avg_vertical_oscillation=0.08,
        )
        sess.add(rs)
        sess.commit()

    resp = await client.get(
        f"/api/v1/challenges/{CHALLENGE_ID}/leaderboard?ios_user_id={test_user}"
    )
    assert resp.status_code == 200
    data = resp.json()
    user_entries = [e for e in data if e.get("is_me")]
    assert len(user_entries) == 1
