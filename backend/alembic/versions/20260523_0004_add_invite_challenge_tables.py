"""add invite_codes and challenge_participants tables (RF-600 / RF-601)

Revision ID: 20260523_0004
Revises: 20260516_0003
Create Date: 2026-05-23 00:04:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260523_0004"
down_revision = "20260516_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── invite_codes (RF-600) ──────────────────────────────────────────
    op.create_table(
        "invite_codes",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("code", sa.String(8), nullable=False),
        sa.Column("creator_user_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("redeemed_by", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("redeemed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_invite_codes_code", "invite_codes", ["code"], unique=True)
    op.create_index("ix_invite_codes_creator_user_id", "invite_codes", ["creator_user_id"], unique=False)
    op.create_index("ix_invite_codes_redeemed_by", "invite_codes", ["redeemed_by"], unique=False)

    # ── challenge_participants (RF-601) ────────────────────────────────
    op.create_table(
        "challenge_participants",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("challenge_id", sa.String(64), nullable=False),
        sa.Column("user_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("baseline_cadence", sa.Float(), nullable=True),
        sa.Column("baseline_vertical_oscillation", sa.Float(), nullable=True),
        sa.Column("baseline_overall_score", sa.Float(), nullable=True),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_challenge_participants_challenge_id", "challenge_participants",
                    ["challenge_id"], unique=False)
    op.create_index("ix_challenge_participants_user_id", "challenge_participants",
                    ["user_id"], unique=False)
    op.create_unique_constraint("uq_challenge_user", "challenge_participants",
                                ["challenge_id", "user_id"])


def downgrade() -> None:
    op.drop_table("challenge_participants")
    op.drop_table("invite_codes")
