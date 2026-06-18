"""add check-in tracking fields to challenge_participants (C5)

Revision ID: 20260523_0006
Revises: 20260523_0005
Create Date: 2026-05-23 00:06:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260523_0006"
down_revision = "20260523_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("challenge_participants", sa.Column("last_check_in", sa.DateTime(timezone=True), nullable=True))
    op.add_column("challenge_participants", sa.Column("check_in_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("challenge_participants", sa.Column("current_streak", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("challenge_participants", sa.Column("latest_cadence", sa.Float(), nullable=True))
    op.add_column("challenge_participants", sa.Column("latest_score", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("challenge_participants", "latest_score")
    op.drop_column("challenge_participants", "latest_cadence")
    op.drop_column("challenge_participants", "current_streak")
    op.drop_column("challenge_participants", "check_in_count")
    op.drop_column("challenge_participants", "last_check_in")
