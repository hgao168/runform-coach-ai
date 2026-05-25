from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ios_user_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now, onupdate=_utc_now)

    # Profile fields
    first_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    last_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    nickname: Mapped[str | None] = mapped_column(String(128), nullable=True)
    level: Mapped[str | None] = mapped_column(String(32), nullable=True)
    weekly_mileage_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    running_days_per_week: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    target: Mapped[str | None] = mapped_column(String(64), nullable=True)
    injury_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(32), nullable=True)
    shoe_size: Mapped[str | None] = mapped_column(String(32), nullable=True)
    shoe_brand_model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    leg_length_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    date_of_birth: Mapped[str | None] = mapped_column(String(32), nullable=True)
    weekly_exercise_hours: Mapped[float | None] = mapped_column(Float, nullable=True)

    oauth_connections: Mapped[list["OAuthConnection"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    strava_runs: Mapped[list["StravaRun"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    strava_weekly_stats: Mapped[list["StravaWeeklyStat"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class OAuthConnection(Base):
    __tablename__ = "oauth_connections"
    __table_args__ = (UniqueConstraint("provider", "provider_athlete_id", name="uq_oauth_provider_athlete"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(32), index=True)
    provider_athlete_id: Mapped[str] = mapped_column(String(64), index=True)
    access_token_encrypted: Mapped[str] = mapped_column(Text)
    refresh_token_encrypted: Mapped[str] = mapped_column(Text)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    scope: Mapped[str | None] = mapped_column(Text, nullable=True)
    connected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)
    last_refresh_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship(back_populates="oauth_connections")


class StravaRun(Base):
    __tablename__ = "strava_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    strava_activity_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    distance_m: Mapped[float] = mapped_column(Float)
    moving_time_s: Mapped[int] = mapped_column(Integer)
    elapsed_time_s: Mapped[int | None] = mapped_column(Integer, nullable=True)
    average_speed_mps: Mapped[float | None] = mapped_column(Float, nullable=True)
    max_speed_mps: Mapped[float | None] = mapped_column(Float, nullable=True)
    average_hr: Mapped[float | None] = mapped_column(Float, nullable=True)
    total_elevation_gain_m: Mapped[float | None] = mapped_column(Float, nullable=True)
    trainer: Mapped[bool] = mapped_column(default=False)
    commute: Mapped[bool] = mapped_column(default=False)
    raw_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)

    user: Mapped[User] = relationship(back_populates="strava_runs")


class StravaWeeklyStat(Base):
    __tablename__ = "strava_weekly_stats"
    __table_args__ = (UniqueConstraint("user_id", "week_start", name="uq_weekly_user_week"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    week_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    total_distance_m: Mapped[float] = mapped_column(Float, default=0.0)
    run_count: Mapped[int] = mapped_column(Integer, default=0)
    longest_run_m: Mapped[float] = mapped_column(Float, default=0.0)
    avg_pace_s_per_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    intensity_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now, onupdate=_utc_now)

    user: Mapped[User] = relationship(back_populates="strava_weekly_stats")
