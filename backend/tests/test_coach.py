"""
Tests for RF-602: Coach Panel API (CRUD operations).
"""
import pytest
from httpx import AsyncClient

from app.db_models import CoachCode, CoachStudent, User
from tests.conftest import _test_session_factory


@pytest.fixture
def coach_user(_db_setup):
    """Create a coach user and return their ios_user_id."""
    with _test_session_factory() as sess:
        user = User(ios_user_id="coach-001", nickname="Coach Alice")
        sess.add(user)
        sess.commit()
        uid = user.ios_user_id
    return uid


@pytest.fixture
def student_user(_db_setup):
    """Create a student user and return their ios_user_id."""
    with _test_session_factory() as sess:
        user = User(ios_user_id="student-001", nickname="Student Bob")
        sess.add(user)
        sess.commit()
        uid = user.ios_user_id
    return uid


@pytest.mark.anyio
async def test_generate_coach_code(client: AsyncClient, coach_user: str):
    """POST /api/v1/coach/generate-code creates a coach code."""
    response = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    assert response.status_code == 200
    data = response.json()
    assert "code" in data
    assert len(data["code"]) == 8
    assert data["student_limit"] == 20
    assert data["is_active"] is True
    assert "created_at" in data


@pytest.mark.anyio
async def test_generate_coach_code_limit(client: AsyncClient, coach_user: str):
    """Cannot generate more than 5 active coach codes."""
    # Generate 5 codes
    for _ in range(5):
        resp = await client.post(
            "/api/v1/coach/generate-code",
            json={"ios_user_id": coach_user},
        )
        assert resp.status_code == 200

    # 6th should be rejected
    resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    assert resp.status_code == 429


@pytest.mark.anyio
async def test_join_coach_success(client: AsyncClient, coach_user: str, student_user: str):
    """POST /api/v1/coach/join allows student to join coach using code."""
    # Generate coach code
    gen_resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    assert gen_resp.status_code == 200
    code = gen_resp.json()["code"]

    # Student joins
    join_resp = await client.post(
        "/api/v1/coach/join",
        json={"ios_user_id": student_user, "code": code},
    )
    assert join_resp.status_code == 200
    data = join_resp.json()
    assert data["joined"] is True
    assert data["coach_ios_user_id"] == coach_user


@pytest.mark.anyio
async def test_join_coach_invalid_code(client: AsyncClient, student_user: str):
    """Joining with invalid code returns 404."""
    resp = await client.post(
        "/api/v1/coach/join",
        json={"ios_user_id": student_user, "code": "DEADBEEF"},
    )
    assert resp.status_code == 404


@pytest.mark.anyio
async def test_join_coach_self_join(client: AsyncClient, coach_user: str):
    """Coach cannot join themselves."""
    gen_resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    code = gen_resp.json()["code"]

    resp = await client.post(
        "/api/v1/coach/join",
        json={"ios_user_id": coach_user, "code": code},
    )
    assert resp.status_code == 400


@pytest.mark.anyio
async def test_join_coach_duplicate(client: AsyncClient, coach_user: str, student_user: str):
    """Joining the same coach twice returns already-joined message."""
    gen_resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    code = gen_resp.json()["code"]

    # First join
    r1 = await client.post("/api/v1/coach/join", json={"ios_user_id": student_user, "code": code})
    assert r1.status_code == 200

    # Second join
    r2 = await client.post("/api/v1/coach/join", json={"ios_user_id": student_user, "code": code})
    assert r2.status_code == 200
    assert "already" in r2.json()["message"].lower()


@pytest.mark.anyio
async def test_coach_students_list(client: AsyncClient, coach_user: str, student_user: str):
    """GET /api/v1/coach/students returns list of students."""
    # Generate code and join
    gen_resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    code = gen_resp.json()["code"]
    await client.post("/api/v1/coach/join", json={"ios_user_id": student_user, "code": code})

    # Get coach's internal ID
    with _test_session_factory() as sess:
        coach = sess.query(User).filter(User.ios_user_id == coach_user).first()

    # List students
    resp = await client.get(f"/api/v1/coach/students?coach_id={coach.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) == 1
    assert data[0]["ios_user_id"] == student_user


@pytest.mark.anyio
async def test_coach_dashboard(client: AsyncClient, coach_user: str, student_user: str):
    """GET /api/v1/coach/dashboard returns coach dashboard with form summaries."""
    # Generate code and join
    gen_resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    code = gen_resp.json()["code"]
    await client.post("/api/v1/coach/join", json={"ios_user_id": student_user, "code": code})

    # Get coach's internal ID
    with _test_session_factory() as sess:
        coach = sess.query(User).filter(User.ios_user_id == coach_user).first()

    # Get dashboard
    resp = await client.get(f"/api/v1/coach/dashboard?coach_id={coach.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["coach_ios_user_id"] == coach_user
    assert data["student_count"] == 1
    assert len(data["students"]) == 1
    assert len(data["form_summaries"]) == 1
    assert data["students"][0]["ios_user_id"] == student_user
    # Form summary for student with no sessions
    fs = data["form_summaries"][0]
    assert fs["session_count"] == 0
    assert fs["latest_session_at"] is None


@pytest.mark.anyio
async def test_coach_dashboard_with_sessions(client: AsyncClient, coach_user: str, student_user: str):
    """Dashboard shows latest run session metrics for students."""
    # Generate code and join
    gen_resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    code = gen_resp.json()["code"]
    await client.post("/api/v1/coach/join", json={"ios_user_id": student_user, "code": code})

    # Create a run session for the student
    from app.db_models import RunSession
    from datetime import datetime, timezone
    with _test_session_factory() as sess:
        student = sess.query(User).filter(User.ios_user_id == student_user).first()
        coach = sess.query(User).filter(User.ios_user_id == coach_user).first()
        rs = RunSession(
            user_id=student.id,
            start_time=datetime(2026, 5, 20, 10, 0, 0, tzinfo=timezone.utc),
            avg_cadence=170.0,
            avg_vertical_oscillation=0.08,
            avg_gct=0.22,
        )
        sess.add(rs)
        sess.commit()

    # Get dashboard
    resp = await client.get(f"/api/v1/coach/dashboard?coach_id={coach.id}")
    assert resp.status_code == 200
    data = resp.json()
    fs = data["form_summaries"][0]
    assert fs["session_count"] == 1
    assert fs["latest_session_at"] is not None
    assert fs["avg_cadence"] == 170.0
    assert fs["avg_vertical_oscillation"] == 0.08
    assert fs["avg_gct"] == 0.22
    assert fs["overall_score"] is not None
    assert fs["overall_score"] > 0


@pytest.mark.anyio
async def test_coach_students_empty(client: AsyncClient, coach_user: str):
    """Empty student list when coach has no students."""
    with _test_session_factory() as sess:
        coach = sess.query(User).filter(User.ios_user_id == coach_user).first()

    resp = await client.get(f"/api/v1/coach/students?coach_id={coach.id}")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.anyio
async def test_coach_code_case_insensitive(client: AsyncClient, coach_user: str, student_user: str):
    """Coach code join is case-insensitive."""
    gen_resp = await client.post(
        "/api/v1/coach/generate-code",
        json={"ios_user_id": coach_user},
    )
    code = gen_resp.json()["code"]

    # Join with lowercase
    resp = await client.post(
        "/api/v1/coach/join",
        json={"ios_user_id": student_user, "code": code.lower()},
    )
    assert resp.status_code == 200
    assert resp.json()["joined"] is True
