"""
Tests for C5: Challenge check-in + C4: Club leaderboard endpoints.

Requires the test database fixture from conftest.py.
"""

import pytest
from datetime import datetime, timezone, timedelta
from httpx import AsyncClient

from app.db_models import ChallengeParticipant, CoachCode, CoachStudent, RunSession, User
from tests.conftest import _test_session_factory


# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════

CHALLENGE_ID = "14-day-form-challenge"
CHECK_IN_URL = f"/api/v1/challenges/{CHALLENGE_ID}/check-in"
JOIN_URL = f"/api/v1/challenges/{CHALLENGE_ID}/join"


def _add_run_session(user_ios_id: str, days_ago: int = 0, cadence: float = 170.0, osc: float = 0.08, gct: float = 0.22):
    """Insert a RunSession for the given user, offset by days_ago from now."""
    with _test_session_factory() as sess:
        user = sess.query(User).filter(User.ios_user_id == user_ios_id).first()
        if not user:
            raise ValueError(f"User {user_ios_id} not found")
        ts = datetime.now(timezone.utc) - timedelta(days=days_ago, hours=1)
        rs = RunSession(
            user_id=user.id,
            start_time=ts,
            end_time=ts + timedelta(minutes=30),
            duration_sec=1800.0,
            avg_cadence=cadence,
            avg_vertical_oscillation=osc,
            avg_gct=gct,
        )
        sess.add(rs)
        sess.commit()


# ═══════════════════════════════════════════════════════════════════════════
# C5: Challenge Check-In Tests
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.anyio
async def test_checkin_without_joining_returns_400(client: AsyncClient, test_user: str):
    """Check-in fails if user hasn't joined the challenge."""
    resp = await client.post(CHECK_IN_URL, json={"user_id": test_user})
    print(f"DEBUG status={resp.status_code} body={resp.text}")
    assert resp.status_code == 400
    assert "must join" in resp.json()["detail"].lower()


@pytest.mark.anyio
async def test_checkin_unknown_challenge_returns_404(client: AsyncClient, test_user: str):
    """Check-in with unknown challenge ID returns 404."""
    resp = await client.post("/api/v1/challenges/nonexistent/check-in", json={"user_id": test_user})
    assert resp.status_code == 404


@pytest.mark.anyio
async def test_checkin_first_time_success(client: AsyncClient, test_user: str):
    """First check-in after joining succeeds, returns streak=1."""
    # Join first
    await client.post(JOIN_URL, json={"ios_user_id": test_user})
    # Add a run session for today
    _add_run_session(test_user, days_ago=0, cadence=172.0, osc=0.07)

    resp = await client.post(CHECK_IN_URL, json={"user_id": test_user})
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "ok"
    assert data["check_in_count"] == 1
    assert data["streak_days"] == 1
    assert "cadence" in data["today_metrics"]


@pytest.mark.anyio
async def test_checkin_no_today_run_still_works(client: AsyncClient, test_user: str):
    """Check-in succeeds even without today's run data (metrics will be empty)."""
    await client.post(JOIN_URL, json={"ios_user_id": test_user})

    resp = await client.post(CHECK_IN_URL, json={"user_id": test_user})
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "ok"
    assert data["check_in_count"] == 1
    assert data["streak_days"] == 1
    assert data["today_metrics"] == {}


@pytest.mark.anyio
async def test_checkin_duplicate_same_day_returns_409(client: AsyncClient, test_user: str):
    """Cannot check in twice on the same UTC day."""
    await client.post(JOIN_URL, json={"ios_user_id": test_user})

    # First check-in
    r1 = await client.post(CHECK_IN_URL, json={"user_id": test_user})
    assert r1.status_code == 200

    # Second check-in same day
    r2 = await client.post(CHECK_IN_URL, json={"user_id": test_user})
    assert r2.status_code == 409
    assert "already checked in" in r2.json()["detail"].lower()


@pytest.mark.anyio
async def test_checkin_updates_participant_fields(client: AsyncClient, test_user: str):
    """Check-in updates last_check_in, check_in_count, current_streak, latest_cadence, latest_score."""
    await client.post(JOIN_URL, json={"ios_user_id": test_user})
    _add_run_session(test_user, days_ago=0, cadence=175.0, osc=0.06)

    resp = await client.post(CHECK_IN_URL, json={"user_id": test_user})
    assert resp.status_code == 200

    # Verify DB fields
    with _test_session_factory() as sess:
        user = sess.query(User).filter(User.ios_user_id == test_user).first()
        p = sess.query(ChallengeParticipant).filter(
            ChallengeParticipant.challenge_id == CHALLENGE_ID,
            ChallengeParticipant.user_id == user.id,
        ).first()
        assert p is not None
        assert p.check_in_count == 1
        assert p.current_streak == 1
        assert p.last_check_in is not None
        assert p.latest_cadence == 175.0
        assert p.latest_score is not None
        assert p.latest_score > 0


# ═══════════════════════════════════════════════════════════════════════════
# C4: Club Leaderboard Tests
# ═══════════════════════════════════════════════════════════════════════════


@pytest.fixture
def club_setup(_db_setup):
    """Create a coach with a code and two students, returning (coach_ios_id, coach_code, student1_ios_id, student2_ios_id)."""
    with _test_session_factory() as sess:
        # Coach user
        coach = User(ios_user_id="coach-club-001", nickname="Coach Alice")
        sess.add(coach)
        sess.flush()

        code = CoachCode(coach_id=coach.id, code="CLUB001", is_active=True)
        sess.add(code)
        sess.flush()

        # Student 1
        s1 = User(ios_user_id="student-club-001", nickname="Runner One", first_name="Runner")
        sess.add(s1)
        sess.flush()
        cs1 = CoachStudent(coach_id=coach.id, student_id=s1.id)
        sess.add(cs1)

        # Student 2
        s2 = User(ios_user_id="student-club-002", nickname="Runner Two")
        sess.add(s2)
        sess.flush()
        cs2 = CoachStudent(coach_id=coach.id, student_id=s2.id)
        sess.add(cs2)

        sess.commit()
        return ("coach-club-001", "CLUB001", "student-club-001", "student-club-002")


@pytest.mark.anyio
async def test_club_leaderboard_unknown_code_returns_coming_soon(client: AsyncClient):
    """Unknown club_code returns empty entries + coming_soon=true."""
    resp = await client.get("/api/v1/clubs/UNKNOWNXY/leaderboard")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["members"] == []
    assert data["coming_soon"] is True


@pytest.mark.anyio
async def test_club_leaderboard_empty_students(client: AsyncClient):
    """Club with coach but no students returns coming_soon=true."""
    with _test_session_factory() as sess:
        coach = User(ios_user_id="solo-coach", nickname="Solo Coach")
        sess.add(coach)
        sess.flush()
        code = CoachCode(coach_id=coach.id, code="SOLOCODE", is_active=True)
        sess.add(code)
        sess.commit()

    resp = await client.get("/api/v1/clubs/SOLOCODE/leaderboard")
    assert resp.status_code == 200
    data = resp.json()
    assert data["coming_soon"] is True


@pytest.mark.anyio
async def test_club_leaderboard_returns_ranked_entries(client: AsyncClient, club_setup):
    """Club leaderboard returns students ranked by form_score."""
    coach_ios_id, coach_code, s1_id, s2_id = club_setup

    # Add run sessions for both students
    _add_run_session(s1_id, days_ago=0, cadence=180.0, osc=0.06)  # high score
    _add_run_session(s2_id, days_ago=0, cadence=165.0, osc=0.10)  # lower score

    resp = await client.get(f"/api/v1/clubs/{coach_code}/leaderboard")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["coming_soon"] is False
    assert len(data["members"]) == 2

    # Check structure
    e0 = data["members"][0]
    assert "rank" in e0
    assert "nickname" in e0
    assert "cadence" in e0
    assert "form_score" in e0
    assert "score_change" in e0
    assert "is_me" in e0

    # First entry should be higher score
    assert e0["rank"] == 1
    assert e0["cadence"] == 180.0
    assert e0["form_score"] is not None
    assert e0["form_score"] > 0

    # Second entry should be rank 2
    e1 = data["members"][1]
    assert e1["rank"] == 2


@pytest.mark.anyio
async def test_club_leaderboard_is_me_flag(client: AsyncClient, club_setup):
    """When ios_user_id is passed, matching entries get is_me=true."""
    coach_ios_id, coach_code, s1_id, s2_id = club_setup
    _add_run_session(s1_id, days_ago=0, cadence=170.0, osc=0.08)
    _add_run_session(s2_id, days_ago=0, cadence=160.0, osc=0.09)

    # Requesting as student 2
    resp = await client.get(f"/api/v1/clubs/{coach_code}/leaderboard?ios_user_id={s2_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["members"]) == 2

    # Find student 2's entry
    s2_entry = [e for e in data["members"] if e["nickname"] == "Runner Two"]
    assert len(s2_entry) == 1
    assert s2_entry[0]["is_me"] is True

    s1_entry = [e for e in data["members"] if e["nickname"] == "Runner One"]
    assert len(s1_entry) == 1
    assert s1_entry[0]["is_me"] is False


@pytest.mark.anyio
async def test_club_leaderboard_score_change(client: AsyncClient, club_setup):
    """When a student has 2+ sessions, score_change reflects improvement/drop."""
    coach_ios_id, coach_code, s1_id, s2_id = club_setup

    # Student 1: improving (cadence went up, oscillation went down)
    _add_run_session(s1_id, days_ago=1, cadence=165.0, osc=0.10)  # older, worse
    _add_run_session(s1_id, days_ago=0, cadence=175.0, osc=0.07)  # newer, better

    resp = await client.get(f"/api/v1/clubs/{coach_code}/leaderboard")
    assert resp.status_code == 200
    data = resp.json()

    s1_entry = [e for e in data["members"] if e["nickname"] == "Runner One"][0]
    assert s1_entry["score_change"] == "+"


@pytest.mark.anyio
async def test_club_leaderboard_case_insensitive_code(client: AsyncClient, club_setup):
    """Club code lookup is case-insensitive."""
    coach_ios_id, coach_code, s1_id, s2_id = club_setup
    _add_run_session(s1_id, days_ago=0, cadence=170.0, osc=0.08)

    resp = await client.get(f"/api/v1/clubs/{coach_code.lower()}/leaderboard")
    assert resp.status_code == 200
    data = resp.json()
    assert data["coming_soon"] is False
    assert len(data["members"]) >= 1


@pytest.mark.anyio
async def test_club_leaderboard_by_ios_user_id(client: AsyncClient):
    """Club lookup also works by coach's ios_user_id as a fallback."""
    with _test_session_factory() as sess:
        coach = User(ios_user_id="coach-by-id", nickname="Coach ID")
        sess.add(coach)
        sess.flush()
        code = CoachCode(coach_id=coach.id, code="BYIDCODE", is_active=True)
        sess.add(code)
        student = User(ios_user_id="student-by-id", nickname="Student ID")
        sess.add(student)
        sess.flush()
        cs = CoachStudent(coach_id=coach.id, student_id=student.id)
        sess.add(cs)
        sess.commit()

    _add_run_session("student-by-id", days_ago=0, cadence=170.0, osc=0.08)

    # Lookup by ios_user_id of the coach
    resp = await client.get("/api/v1/clubs/coach-by-id/leaderboard")
    assert resp.status_code == 200
    data = resp.json()
    assert data["coming_soon"] is False
    assert len(data["members"]) == 1
