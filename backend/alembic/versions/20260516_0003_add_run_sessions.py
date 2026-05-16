"""add run_sessions table for session CRUD and trends

Revision ID: 20260516_0003
Revises: 20260510_0002
Create Date: 2026-05-16 00:03:00
"""

from alembic import op
import sqlalchemy as sa

revision = "20260516_0003"
down_revision = "20260510_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "run_sessions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_sec", sa.Float(), nullable=True),
        sa.Column("avg_cadence", sa.Float(), nullable=True),
        sa.Column("avg_vertical_oscillation", sa.Float(), nullable=True),
        sa.Column("avg_gct", sa.Float(), nullable=True),
        sa.Column("metrics_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_run_sessions_user_id", "run_sessions", ["user_id"], unique=False)
    op.create_index("ix_run_sessions_start_time", "run_sessions", ["start_time"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_run_sessions_start_time", table_name="run_sessions")
    op.drop_index("ix_run_sessions_user_id", table_name="run_sessions")
    op.drop_table("run_sessions")
