from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from .db_models import OAuthConnection, StravaRun, StravaWeeklyStat, User
from .strava_oauth import StravaOAuthError, get_valid_access_token

STRAVA_API_BASE_URL = "https://www.strava.com/api/v3"
STRAVA_LOOKBACK_WEEKS = 8
STRAVA_LOOKBACK_DAYS = STRAVA_LOOKBACK_WEEKS * 7


def _parse_datetime(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _week_start(value: datetime) -> datetime:
    utc_value = value.astimezone(timezone.utc)
    start = utc_value - timedelta(days=utc_value.weekday())
    return datetime(start.year, start.month, start.day, tzinfo=timezone.utc)


def _week_start_from_iso(value: datetime) -> datetime:
    return _week_start(value)


def _week_starts_for_window(reference: datetime, week_count: int) -> list[datetime]:
    current_week_start = _week_start(reference)
    return [
        current_week_start - timedelta(weeks=offset)
        for offset in range(week_count - 1, -1, -1)
    ]


def _activity_kind(activity: dict[str, Any]) -> str:
    for key in ("sport_type", "type"):
        value = activity.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def _is_run_activity(activity: dict[str, Any]) -> bool:
    return (
        _activity_kind(activity) in {"Run", "TrailRun", "VirtualRun"}
        and float(activity.get("distance") or 0.0) > 0
        and int(activity.get("moving_time") or 0) > 0
    )


def _estimate_intensity_score(total_distance_km: float, run_count: int, longest_run_km: float, avg_pace_s_per_km: float | None) -> float:
    pace_boost = 0.0
    if avg_pace_s_per_km is not None:
        pace_boost = max(0.0, min(20.0, (360.0 - avg_pace_s_per_km) / 6.0))
    raw_score = (run_count * 8.0) + (total_distance_km * 1.4) + (longest_run_km * 2.0) + pace_boost
    return round(min(100.0, raw_score), 1)


def _activity_to_run_fields(activity: dict[str, Any], user_id: int) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "strava_activity_id": str(activity["id"]),
        "name": activity.get("name"),
        "start_date": _parse_datetime(activity["start_date"]),
        "distance_m": float(activity.get("distance") or 0.0),
        "moving_time_s": int(activity.get("moving_time") or 0),
        "elapsed_time_s": int(activity["elapsed_time"]) if activity.get("elapsed_time") is not None else None,
        "average_speed_mps": float(activity["average_speed"]) if activity.get("average_speed") is not None else None,
        "max_speed_mps": float(activity["max_speed"]) if activity.get("max_speed") is not None else None,
        "average_hr": float(activity["average_heartrate"]) if activity.get("average_heartrate") is not None else None,
        "total_elevation_gain_m": float(activity["total_elevation_gain"]) if activity.get("total_elevation_gain") is not None else None,
        "trainer": bool(activity.get("trainer") or False),
        "commute": bool(activity.get("commute") or False),
        "raw_json": activity,
    }


def _upsert_run(session: Session, activity: dict[str, Any], user_id: int) -> bool:
    activity_id = str(activity["id"])
    fields = _activity_to_run_fields(activity, user_id)
    existing = session.scalar(select(StravaRun).where(StravaRun.strava_activity_id == activity_id))
    if existing is None:
        session.add(StravaRun(**fields))
        return True

    updated = False
    for key, value in fields.items():
        if getattr(existing, key) != value:
            setattr(existing, key, value)
            updated = True
    return updated


def _weekly_summary_from_runs(runs: list[StravaRun]) -> list[dict[str, Any]]:
    grouped: dict[datetime, list[StravaRun]] = defaultdict(list)
    for run in runs:
        grouped[_week_start_from_iso(run.start_date)].append(run)

    summaries: list[dict[str, Any]] = []
    for week_start, week_runs in sorted(grouped.items(), key=lambda item: item[0]):
        total_distance_m = sum(run.distance_m for run in week_runs)
        total_moving_time_s = sum(run.moving_time_s for run in week_runs)
        longest_run_m = max((run.distance_m for run in week_runs), default=0.0)
        avg_pace_s_per_km = None
        if total_distance_m > 0:
            avg_pace_s_per_km = round(total_moving_time_s / (total_distance_m / 1000.0), 1)

        total_distance_km = round(total_distance_m / 1000.0, 2)
        longest_run_km = round(longest_run_m / 1000.0, 2)
        intensity_score = _estimate_intensity_score(total_distance_km, len(week_runs), longest_run_km, avg_pace_s_per_km)

        summaries.append(
            {
                "week_start": week_start,
                "total_distance_m": total_distance_m,
                "run_count": len(week_runs),
                "longest_run_m": longest_run_m,
                "avg_pace_s_per_km": avg_pace_s_per_km,
                "intensity_score": intensity_score,
            }
        )

    return summaries


def _empty_week_summary(week_start: datetime) -> dict[str, Any]:
    return {
        "week_start": week_start,
        "total_distance_m": 0.0,
        "run_count": 0,
        "longest_run_m": 0.0,
        "avg_pace_s_per_km": None,
        "intensity_score": 0.0,
    }


async def _fetch_strava_athlete(access_token: str) -> dict[str, Any] | None:
    """Fetch the connected athlete's profile from Strava. Returns None on failure (non-fatal)."""
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.get(
                f"{STRAVA_API_BASE_URL}/athlete",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if response.status_code >= 400:
                return None
            payload = response.json()
            return payload if isinstance(payload, dict) else None
    except (httpx.HTTPError, ValueError):
        return None


def _strava_sex_to_gender(sex: str | None) -> str | None:
    if not sex:
        return None
    s = sex.strip().upper()
    if s == "M":
        return "male"
    if s == "F":
        return "female"
    return None


def _prefill_user_from_strava_athlete(user: User, athlete: dict[str, Any]) -> dict[str, Any]:
    """Fill empty User profile fields from Strava /athlete data. Never overwrites user-set values.

    Returns a dict of fields that were actually filled, for client feedback.
    """
    prefilled: dict[str, Any] = {}

    def _is_blank(v: Any) -> bool:
        return v is None or (isinstance(v, str) and not v.strip())

    first = athlete.get("firstname")
    if isinstance(first, str) and first.strip() and _is_blank(user.first_name):
        user.first_name = first.strip()
        prefilled["first_name"] = user.first_name

    last = athlete.get("lastname")
    if isinstance(last, str) and last.strip() and _is_blank(user.last_name):
        user.last_name = last.strip()
        prefilled["last_name"] = user.last_name

    gender = _strava_sex_to_gender(athlete.get("sex"))
    # Treat "unspecified" as blank, since it's the iOS default
    current_gender = user.gender
    if gender and (current_gender is None or current_gender == "" or current_gender == "unspecified"):
        user.gender = gender
        prefilled["gender"] = gender

    weight = athlete.get("weight")
    if isinstance(weight, (int, float)) and weight > 0 and user.weight_kg in (None, 0, 70):
        # 70 is the iOS default seed value; only overwrite the default, never user-edited values
        user.weight_kg = float(weight)
        prefilled["weight_kg"] = float(weight)

    return prefilled


async def _fetch_strava_activities(access_token: str, cutoff: datetime) -> list[dict[str, Any]]:
    activities: list[dict[str, Any]] = []
    params = {"after": int(cutoff.timestamp()) - 1, "per_page": 200}

    async with httpx.AsyncClient(timeout=30) as client:
        page = 1
        while True:
            response = await client.get(
                f"{STRAVA_API_BASE_URL}/athlete/activities",
                headers={"Authorization": f"Bearer {access_token}"},
                params={**params, "page": page},
            )
            if response.status_code >= 400:
                raise StravaOAuthError(f"Strava activity sync failed: {response.text}")

            batch = response.json()
            if not isinstance(batch, list):
                raise StravaOAuthError("Strava activities response was not a list.")

            if not batch:
                break

            activities.extend(batch)
            if len(batch) < params["per_page"]:
                break
            page += 1

    return activities


async def sync_strava_runs_for_user(session: Session, ios_user_id: str, lookback_days: int = STRAVA_LOOKBACK_DAYS) -> dict[str, Any]:
    user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))
    if user is None:
        raise LookupError("No app user found for this ios_user_id.")

    connection = session.scalar(
        select(OAuthConnection).where(OAuthConnection.user_id == user.id, OAuthConnection.provider == "strava")
    )
    if connection is None:
        raise LookupError("Strava is not connected for this user.")

    access_token = await get_valid_access_token(session, connection)
    now = datetime.now(timezone.utc)
    week_count = max(1, min(12, (lookback_days + 6) // 7))
    week_starts = _week_starts_for_window(now, week_count)
    cutoff = week_starts[0]
    activities = await _fetch_strava_activities(access_token, cutoff)

    # Best-effort: pull /athlete and fill empty profile fields. Failures are non-fatal.
    prefilled: dict[str, Any] = {}
    athlete_payload = await _fetch_strava_athlete(access_token)
    if athlete_payload:
        prefilled = _prefill_user_from_strava_athlete(user, athlete_payload)

    run_activities = [activity for activity in activities if _is_run_activity(activity)]
    for activity in run_activities:
        _upsert_run(session, activity, user.id)

    session.flush()

    touched_runs = session.scalars(
        select(StravaRun).where(StravaRun.user_id == user.id, StravaRun.start_date >= cutoff)
    ).all()
    summaries_by_week = {
        item["week_start"]: item
        for item in _weekly_summary_from_runs(touched_runs)
        if item["week_start"] in week_starts
    }
    summaries = [
        summaries_by_week.get(week_start, _empty_week_summary(week_start))
        for week_start in week_starts
    ]

    session.execute(
        delete(StravaWeeklyStat).where(
            StravaWeeklyStat.user_id == user.id,
            StravaWeeklyStat.week_start.in_(week_starts),
        )
    )

    weekly_rows: list[StravaWeeklyStat] = [
        StravaWeeklyStat(
            user_id=user.id,
            week_start=item["week_start"],
            total_distance_m=item["total_distance_m"],
            run_count=item["run_count"],
            longest_run_m=item["longest_run_m"],
            avg_pace_s_per_km=item["avg_pace_s_per_km"],
            intensity_score=item["intensity_score"],
        )
        for item in summaries
    ]
    session.add_all(weekly_rows)

    session.flush()

    # Record the sync timestamp so Profile UI can display it
    connection.last_refresh_at = datetime.now(timezone.utc)

    return {
        "ios_user_id": ios_user_id,
        "lookback_days": lookback_days,
        "scanned_activity_count": len(activities),
        "synced_run_count": len(run_activities),
        "week_count": len(weekly_rows),
        "prefilled_profile": prefilled,
        "weekly_stats": [
            {
                "week_start": item["week_start"].date().isoformat(),
                "total_distance_km": round(item["total_distance_m"] / 1000.0, 2),
                "run_count": item["run_count"],
                "longest_run_km": round(item["longest_run_m"] / 1000.0, 2),
                "avg_pace_s_per_km": item["avg_pace_s_per_km"],
                "intensity_score": item["intensity_score"],
            }
            for item in summaries
        ],
    }
