"""
Run Session API tests — CRUD, Trends, Compare.

Requires the test database fixture from conftest.py.
"""

import pytest


# ── Helper payloads ───────────────────────────────────────────────────────────

def _session_payload(ios_user_id: str = "test-user-001", **overrides) -> dict:
    """Build a minimal valid RunSessionCreate payload."""
    base = {
        "ios_user_id": ios_user_id,
        "start_time": "2026-05-15T08:00:00+00:00",
        "end_time": "2026-05-15T08:30:00+00:00",
        "duration_sec": 1800.0,
        "avg_cadence": 172.5,
        "avg_vertical_oscillation": 8.2,
        "avg_gct": 245.0,
        "metrics_json": {"cadence": 172.5, "oscillation_cm": 8.2, "gct_ms": 245},
    }
    base.update(overrides)
    return base


# ── CRUD: Create ─────────────────────────────────────────────────────────────


@pytest.mark.anyio
async def test_create_session_requires_valid_user(client, test_user):
    """POST /sessions with valid payload returns 201 + session data."""
    payload = _session_payload(ios_user_id=test_user)
    response = await client.post("/sessions", json=payload)
    assert response.status_code == 201, response.text
    data = response.json()
    assert data["ios_user_id"] == test_user
    assert data["avg_cadence"] == 172.5
    assert data["avg_vertical_oscillation"] == 8.2
    assert data["avg_gct"] == 245.0
    assert data["duration_sec"] == 1800.0
    assert "id" in data
    assert "created_at" in data
    assert data["metrics_json"] == payload["metrics_json"]


@pytest.mark.anyio
async def test_create_session_unknown_user_returns_404(client, test_user):
    """POST /sessions with unknown ios_user_id returns 404."""
    payload = _session_payload(ios_user_id="nonexistent-user")
    response = await client.post("/sessions", json=payload)
    assert response.status_code == 404, response.text


@pytest.mark.anyio
async def test_create_session_minimal_payload(client, test_user):
    """POST /sessions with only required fields returns 201."""
    payload = {
        "ios_user_id": test_user,
        "start_time": "2026-05-16T07:00:00+00:00",
    }
    response = await client.post("/sessions", json=payload)
    assert response.status_code == 201, response.text
    data = response.json()
    assert data["avg_cadence"] is None
    assert data["end_time"] is None


@pytest.mark.anyio
async def test_create_session_rejects_missing_fields(client, test_user):
    """POST /sessions without required fields returns 422."""
    response = await client.post("/sessions", json={})
    assert response.status_code == 422, response.text


# ── CRUD: List ───────────────────────────────────────────────────────────────


@pytest.mark.anyio
async def test_list_sessions_returns_paginated(client, test_user):
    """GET /sessions returns sessions for the user, newest first."""
    # Create two sessions
    p1 = _session_payload(ios_user_id=test_user, start_time="2026-05-14T08:00:00+00:00", avg_cadence=160)
    p2 = _session_payload(ios_user_id=test_user, start_time="2026-05-15T08:00:00+00:00", avg_cadence=170)
    await client.post("/sessions", json=p1)
    await client.post("/sessions", json=p2)

    response = await client.get(f"/sessions?ios_user_id={test_user}&limit=10")
    assert response.status_code == 200, response.text
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 2
    # newest first
    assert data[0]["avg_cadence"] == 170.0
    assert data[1]["avg_cadence"] == 160.0


@pytest.mark.anyio
async def test_list_sessions_respects_limit_offset(client, test_user):
    """GET /sessions honours limit and offset parameters."""
    for i in range(3):
        p = _session_payload(
            ios_user_id=test_user,
            start_time=f"2026-05-1{i+3}T08:00:00+00:00",
        )
        await client.post("/sessions", json=p)

    # limit=2
    r = await client.get(f"/sessions?ios_user_id={test_user}&limit=2&offset=0")
    assert len(r.json()) == 2

    # offset=1
    r = await client.get(f"/sessions?ios_user_id={test_user}&limit=10&offset=1")
    assert len(r.json()) == 2


@pytest.mark.anyio
async def test_list_sessions_empty_for_new_user(client, test_user):
    """GET /sessions for user with no sessions returns empty list."""
    response = await client.get(f"/sessions?ios_user_id={test_user}")
    assert response.status_code == 200, response.text
    assert response.json() == []


# ── CRUD: Get single ─────────────────────────────────────────────────────────


@pytest.mark.anyio
async def test_get_session_by_id(client, test_user):
    """GET /sessions/{id} returns a single session."""
    r = await client.post("/sessions", json=_session_payload(ios_user_id=test_user))
    session_id = r.json()["id"]

    r2 = await client.get(f"/sessions/{session_id}?ios_user_id={test_user}")
    assert r2.status_code == 200, r2.text
    assert r2.json()["id"] == session_id
    assert r2.json()["metrics_json"] is not None


@pytest.mark.anyio
async def test_get_session_not_found(client, test_user):
    """GET /sessions/{id} for missing session returns 404."""
    r = await client.get(f"/sessions/99999?ios_user_id={test_user}")
    assert r.status_code == 404, r.text


@pytest.mark.anyio
async def test_get_session_wrong_user(client, test_user):
    """GET /sessions/{id} from a different user should 404."""
    # Create session owned by test_user
    r = await client.post("/sessions", json=_session_payload(ios_user_id=test_user))
    sid = r.json()["id"]

    # Try to access with a different user
    r2 = await client.get(f"/sessions/{sid}?ios_user_id=other-user")
    assert r2.status_code == 404, r2.text


# ── CRUD: Delete ─────────────────────────────────────────────────────────────


@pytest.mark.anyio
async def test_delete_session(client, test_user):
    """DELETE /sessions/{id} removes the session."""
    r = await client.post("/sessions", json=_session_payload(ios_user_id=test_user))
    sid = r.json()["id"]

    d = await client.delete(f"/sessions/{sid}?ios_user_id={test_user}")
    assert d.status_code == 204, d.text

    # Verify gone
    r2 = await client.get(f"/sessions/{sid}?ios_user_id={test_user}")
    assert r2.status_code == 404


@pytest.mark.anyio
async def test_delete_session_not_found(client, test_user):
    """DELETE /sessions/{id} for missing session returns 404."""
    r = await client.delete(f"/sessions/99999?ios_user_id={test_user}")
    assert r.status_code == 404, r.text


# ── Trends ───────────────────────────────────────────────────────────────────


@pytest.mark.anyio
async def test_trends_returns_chronological_arrays(client, test_user):
    """GET /sessions/trends returns metric arrays in chronological order."""
    # Create 3 sessions with increasing cadence
    for i, cad in enumerate([160, 165, 172]):
        p = _session_payload(
            ios_user_id=test_user,
            start_time=f"2026-05-1{i+3}T08:00:00+00:00",
            avg_cadence=cad,
            avg_vertical_oscillation=7.0 + i,
            avg_gct=250.0 - i * 5,
        )
        await client.post("/sessions", json=p)

    r = await client.get(f"/sessions/trends?ios_user_id={test_user}&limit=10")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["session_count"] == 3
    assert data["cadence"] == [160.0, 165.0, 172.0]
    assert data["vertical_oscillation"] == [7.0, 8.0, 9.0]
    assert data["gct"] == [250.0, 245.0, 240.0]


@pytest.mark.anyio
async def test_trends_respects_limit(client, test_user):
    """GET /sessions/trends?limit=N returns at most N sessions."""
    for i in range(5):
        p = _session_payload(
            ios_user_id=test_user,
            start_time=f"2026-05-1{i+1}T08:00:00+00:00",
            avg_cadence=160 + i,
        )
        await client.post("/sessions", json=p)

    r = await client.get(f"/sessions/trends?ios_user_id={test_user}&limit=3")
    assert r.status_code == 200
    data = r.json()
    assert data["session_count"] == 3
    assert len(data["cadence"]) == 3


@pytest.mark.anyio
async def test_trends_filter_metrics_param(client, test_user):
    """GET /sessions/trends?metrics=cadence returns only cadence."""
    p = _session_payload(
        ios_user_id=test_user,
        start_time="2026-05-15T08:00:00+00:00",
        avg_cadence=170,
        avg_vertical_oscillation=8.0,
        avg_gct=240,
    )
    await client.post("/sessions", json=p)

    r = await client.get(f"/sessions/trends?ios_user_id={test_user}&metrics=cadence")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["cadence"] == [170.0]
    assert data["vertical_oscillation"] == []
    assert data["gct"] == []


@pytest.mark.anyio
async def test_trends_empty_for_new_user(client, test_user):
    """GET /sessions/trends for user with no sessions returns empty arrays."""
    r = await client.get(f"/sessions/trends?ios_user_id={test_user}")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["session_count"] == 0
    assert data["cadence"] == []


# ── Compare ──────────────────────────────────────────────────────────────────


@pytest.mark.anyio
async def test_compare_sessions_side_by_side(client, test_user):
    """POST /sessions/compare returns side-by-side comparison."""
    a = await client.post("/sessions", json=_session_payload(
        ios_user_id=test_user,
        start_time="2026-05-14T08:00:00+00:00",
        avg_cadence=160,
        avg_vertical_oscillation=9.0,
        avg_gct=260,
        duration_sec=2000,
    ))
    b = await client.post("/sessions", json=_session_payload(
        ios_user_id=test_user,
        start_time="2026-05-15T08:00:00+00:00",
        avg_cadence=172,
        avg_vertical_oscillation=7.5,
        avg_gct=240,
        duration_sec=1800,
    ))
    id_a = a.json()["id"]
    id_b = b.json()["id"]

    r = await client.post("/sessions/compare", json={
        "ios_user_id": test_user,
        "session_id_a": id_a,
        "session_id_b": id_b,
    })
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["session_a"]["id"] == id_a
    assert data["session_b"]["id"] == id_b
    assert len(data["comparisons"]) == 4

    # Check cadence comparison
    cad = [c for c in data["comparisons"] if c["metric"] == "avg_cadence"][0]
    assert cad["session_a_value"] == 160.0
    assert cad["session_b_value"] == 172.0
    assert cad["delta"] == -12.0
    assert cad["delta_pct"] is not None


@pytest.mark.anyio
async def test_compare_session_not_found(client, test_user):
    """POST /sessions/compare with invalid session_id returns 404."""
    a = await client.post("/sessions", json=_session_payload(ios_user_id=test_user))
    id_a = a.json()["id"]

    r = await client.post("/sessions/compare", json={
        "ios_user_id": test_user,
        "session_id_a": id_a,
        "session_id_b": 99999,
    })
    assert r.status_code == 404, r.text


@pytest.mark.anyio
async def test_compare_session_wrong_user(client, test_user):
    """POST /sessions/compare with wrong ios_user_id returns 404."""
    a = await client.post("/sessions", json=_session_payload(ios_user_id=test_user))
    id_a = a.json()["id"]

    r = await client.post("/sessions/compare", json={
        "ios_user_id": "other-user",
        "session_id_a": id_a,
        "session_id_b": id_a,
    })
    assert r.status_code == 404, r.text
