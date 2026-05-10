from __future__ import annotations

from datetime import datetime

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from .db_models import OAuthConnection, StravaWeeklyStat, User


def _percent_change(previous: float, current: float) -> float | None:
    if previous <= 0:
        return None
    return round(((current - previous) / previous) * 100.0, 1)


def _load_trend(previous_value: float, recent_value: float) -> str:
    delta = recent_value - previous_value
    threshold = max(1.0, previous_value * 0.1)
    if delta > threshold:
        return "increasing"
    elif delta < -threshold:
        return "decreasing"
    else:
        return "stable"


def build_strava_summary(session: Session, ios_user_id: str, weeks: int) -> dict:
    user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))
    if user is None:
        raise LookupError("No app user found for this ios_user_id.")

    connection = session.scalar(
        select(OAuthConnection).where(OAuthConnection.user_id == user.id, OAuthConnection.provider == "strava")
    )
    if connection is None:
        raise LookupError("Strava is not connected for this user.")

    weekly_rows = session.scalars(
        select(StravaWeeklyStat)
        .where(StravaWeeklyStat.user_id == user.id)
        .order_by(desc(StravaWeeklyStat.week_start))
        .limit(weeks)
    ).all()
    weekly_rows = list(reversed(weekly_rows))

    if not weekly_rows:
        return {
            "ios_user_id": ios_user_id,
            "weeks": weeks,
            "weekly_stats": [],
            "total_distance_km": 0.0,
            "average_weekly_km": 0.0,
            "run_count": 0,
            "longest_run_km": 0.0,
            "avg_pace_s_per_km": None,
            "intensity_estimate": None,
            "load_trend": "stable",
            "trend_delta_pct": None,
            "last_sync_at": connection.last_refresh_at.isoformat() if connection.last_refresh_at else None,
        }

    total_distance_m = sum(row.total_distance_m for row in weekly_rows)
    total_run_count = sum(row.run_count for row in weekly_rows)
    longest_run_m = max((row.longest_run_m for row in weekly_rows), default=0.0)

    pace_weighted_distance_m = sum(row.total_distance_m for row in weekly_rows if row.avg_pace_s_per_km is not None)
    pace_weighted_total = sum(
        row.avg_pace_s_per_km * row.total_distance_m
        for row in weekly_rows
        if row.avg_pace_s_per_km is not None
    )
    avg_pace_s_per_km = (
        round(pace_weighted_total / pace_weighted_distance_m, 1)
        if pace_weighted_distance_m > 0
        else None
    )

    intensity_values = [row.intensity_score for row in weekly_rows if row.intensity_score is not None]
    intensity_estimate = round(sum(intensity_values) / len(intensity_values), 1) if intensity_values else None

    recent_window = weekly_rows[-4:] if len(weekly_rows) >= 4 else weekly_rows
    prior_window = weekly_rows[-8:-4] if len(weekly_rows) >= 8 else weekly_rows[: max(0, len(weekly_rows) - len(recent_window))]

    recent_distance_km = sum(row.total_distance_m for row in recent_window) / 1000.0
    prior_distance_km = sum(row.total_distance_m for row in prior_window) / 1000.0
    load_trend = _load_trend(prior_distance_km, recent_distance_km) if prior_window else "stable"
    trend_delta_pct = _percent_change(prior_distance_km, recent_distance_km) if prior_window else None

    weekly_stats = [
        {
            "week_start": row.week_start.date().isoformat(),
            "total_distance_km": round(row.total_distance_m / 1000.0, 2),
            "run_count": row.run_count,
            "longest_run_km": round(row.longest_run_m / 1000.0, 2),
            "avg_pace_s_per_km": row.avg_pace_s_per_km,
            "intensity_score": row.intensity_score,
        }
        for row in weekly_rows
    ]

    return {
        "ios_user_id": ios_user_id,
        "weeks": weeks,
        "weekly_stats": weekly_stats,
        "total_distance_km": round(total_distance_m / 1000.0, 2),
        "average_weekly_km": round((total_distance_m / 1000.0) / len(weekly_rows), 2),
        "run_count": total_run_count,
        "longest_run_km": round(longest_run_m / 1000.0, 2),
        "avg_pace_s_per_km": avg_pace_s_per_km,
        "intensity_estimate": intensity_estimate,
        "load_trend": load_trend,
        "trend_delta_pct": trend_delta_pct,
        "last_sync_at": max((row.updated_at for row in weekly_rows if row.updated_at is not None), default=None).isoformat() if any(row.updated_at is not None for row in weekly_rows) else None,
    }
