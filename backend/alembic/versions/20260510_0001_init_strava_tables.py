"""init strava integration tables

Revision ID: 20260510_0001
Revises:
Create Date: 2026-05-10 00:00:00
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "20260510_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("ios_user_id", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_ios_user_id", "users", ["ios_user_id"], unique=True)

    op.create_table(
        "oauth_connections",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("provider_athlete_id", sa.String(length=64), nullable=False),
        sa.Column("access_token_encrypted", sa.Text(), nullable=False),
        sa.Column("refresh_token_encrypted", sa.Text(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("scope", sa.Text(), nullable=True),
        sa.Column("connected_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_refresh_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("provider", "provider_athlete_id", name="uq_oauth_provider_athlete"),
    )
    op.create_index("ix_oauth_connections_user_id", "oauth_connections", ["user_id"], unique=False)
    op.create_index("ix_oauth_connections_provider", "oauth_connections", ["provider"], unique=False)
    op.create_index("ix_oauth_connections_provider_athlete_id", "oauth_connections", ["provider_athlete_id"], unique=False)

    op.create_table(
        "strava_runs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("strava_activity_id", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=True),
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("distance_m", sa.Float(), nullable=False),
        sa.Column("moving_time_s", sa.Integer(), nullable=False),
        sa.Column("elapsed_time_s", sa.Integer(), nullable=True),
        sa.Column("average_speed_mps", sa.Float(), nullable=True),
        sa.Column("max_speed_mps", sa.Float(), nullable=True),
        sa.Column("average_hr", sa.Float(), nullable=True),
        sa.Column("total_elevation_gain_m", sa.Float(), nullable=True),
        sa.Column("trainer", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("commute", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("raw_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_strava_runs_user_id", "strava_runs", ["user_id"], unique=False)
    op.create_index("ix_strava_runs_start_date", "strava_runs", ["start_date"], unique=False)
    op.create_index("ix_strava_runs_strava_activity_id", "strava_runs", ["strava_activity_id"], unique=True)

    op.create_table(
        "strava_weekly_stats",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("week_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("total_distance_m", sa.Float(), nullable=False, server_default=sa.text("0")),
        sa.Column("run_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("longest_run_m", sa.Float(), nullable=False, server_default=sa.text("0")),
        sa.Column("avg_pace_s_per_km", sa.Float(), nullable=True),
        sa.Column("intensity_score", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "week_start", name="uq_weekly_user_week"),
    )
    op.create_index("ix_strava_weekly_stats_user_id", "strava_weekly_stats", ["user_id"], unique=False)
    op.create_index("ix_strava_weekly_stats_week_start", "strava_weekly_stats", ["week_start"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_strava_weekly_stats_week_start", table_name="strava_weekly_stats")
    op.drop_index("ix_strava_weekly_stats_user_id", table_name="strava_weekly_stats")
    op.drop_table("strava_weekly_stats")

    op.drop_index("ix_strava_runs_strava_activity_id", table_name="strava_runs")
    op.drop_index("ix_strava_runs_start_date", table_name="strava_runs")
    op.drop_index("ix_strava_runs_user_id", table_name="strava_runs")
    op.drop_table("strava_runs")

    op.drop_index("ix_oauth_connections_provider_athlete_id", table_name="oauth_connections")
    op.drop_index("ix_oauth_connections_provider", table_name="oauth_connections")
    op.drop_index("ix_oauth_connections_user_id", table_name="oauth_connections")
    op.drop_table("oauth_connections")

    op.drop_index("ix_users_ios_user_id", table_name="users")
    op.drop_table("users")
