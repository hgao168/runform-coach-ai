from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


# ── RF-600 / RF-601 ───────────────────────────────────────────────────────

_MAX_INVITE_CODES_PER_USER = 5


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
    run_sessions: Mapped[list["RunSession"]] = relationship(back_populates="user", cascade="all, delete-orphan")

    # RF-600: invite codes created by this user
    created_invite_codes: Mapped[list["InviteCode"]] = relationship(
        "InviteCode", back_populates="creator", foreign_keys="InviteCode.creator_user_id",
        cascade="all, delete-orphan",
    )
    # RF-600: invite codes redeemed by this user (at most 1)
    redeemed_invite_code: Mapped["InviteCode | None"] = relationship(
        "InviteCode", back_populates="redeemer", foreign_keys="InviteCode.redeemed_by",
    )
    # RF-601: challenge participations
    challenge_participations: Mapped[list["ChallengeParticipant"]] = relationship(
        back_populates="user", cascade="all, delete-orphan",
    )
    # RF-602: coach codes created by this user
    created_coach_codes: Mapped[list["CoachCode"]] = relationship(
        "CoachCode", back_populates="coach_user", foreign_keys="CoachCode.coach_id",
        cascade="all, delete-orphan",
    )
    # RF-602: coach-student relationships (as coach)
    coach_students_as_coach: Mapped[list["CoachStudent"]] = relationship(
        "CoachStudent", back_populates="coach_user", foreign_keys="CoachStudent.coach_id",
        cascade="all, delete-orphan",
    )
    # RF-602: coach-student relationships (as student)
    coach_students_as_student: Mapped[list["CoachStudent"]] = relationship(
        "CoachStudent", back_populates="student_user", foreign_keys="CoachStudent.student_id",
        cascade="all, delete-orphan",
    )


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


class RunSession(Base):
    __tablename__ = "run_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    end_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_sec: Mapped[float | None] = mapped_column(Float, nullable=True)
    avg_cadence: Mapped[float | None] = mapped_column(Float, nullable=True)
    avg_vertical_oscillation: Mapped[float | None] = mapped_column(Float, nullable=True)
    avg_gct: Mapped[float | None] = mapped_column(Float, nullable=True)
    metrics_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)

    user: Mapped[User] = relationship(back_populates="run_sessions")


# ── RF-600: Invite code model ─────────────────────────────────────────────

class InviteCode(Base):
    __tablename__ = "invite_codes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    creator_user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    redeemed_by: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)
    redeemed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    creator: Mapped[User] = relationship(back_populates="created_invite_codes", foreign_keys=[creator_user_id])
    redeemer: Mapped[User | None] = relationship(back_populates="redeemed_invite_code", foreign_keys=[redeemed_by])


# ── RF-601: Challenge participant model ───────────────────────────────────

_FOURTEEN_DAY_CHALLENGE_ID = "14-day-form-challenge"


class ChallengeParticipant(Base):
    __tablename__ = "challenge_participants"
    __table_args__ = (UniqueConstraint("challenge_id", "user_id", name="uq_challenge_user"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    challenge_id: Mapped[str] = mapped_column(String(64), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    baseline_cadence: Mapped[float | None] = mapped_column(Float, nullable=True)
    baseline_vertical_oscillation: Mapped[float | None] = mapped_column(Float, nullable=True)
    baseline_overall_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)
    # C5: challenge check-in tracking
    last_check_in: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    check_in_count: Mapped[int] = mapped_column(Integer, default=0)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    latest_cadence: Mapped[float | None] = mapped_column(Float, nullable=True)
    latest_score: Mapped[float | None] = mapped_column(Float, nullable=True)

    user: Mapped[User] = relationship(back_populates="challenge_participations")


# ── RF-602: Coach code model ─────────────────────────────────────────────

class CoachCode(Base):
    __tablename__ = "coach_codes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    coach_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    student_limit: Mapped[int] = mapped_column(Integer, default=20)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)
    is_active: Mapped[bool] = mapped_column(default=True)

    coach_user: Mapped[User] = relationship(back_populates="created_coach_codes", foreign_keys=[coach_id])


# ── RF-602: Coach-student association model ─────────────────────────────

class CoachStudent(Base):
    __tablename__ = "coach_students"
    __table_args__ = (UniqueConstraint("coach_id", "student_id", name="uq_coach_student"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    coach_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utc_now)
    student_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    coach_user: Mapped[User] = relationship(back_populates="coach_students_as_coach", foreign_keys=[coach_id])
    student_user: Mapped[User] = relationship(back_populates="coach_students_as_student", foreign_keys=[student_id])
