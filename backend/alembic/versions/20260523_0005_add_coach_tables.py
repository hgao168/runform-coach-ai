"""add coach_codes and coach_students tables (RF-602)

Revision ID: 20260523_0005
Revises: 20260523_0004
Create Date: 2026-05-23 00:05:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260523_0005"
down_revision = "20260523_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── coach_codes (RF-602) ──────────────────────────────────────────
    op.create_table(
        "coach_codes",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("coach_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(8), nullable=False),
        sa.Column("student_limit", sa.Integer(), nullable=False, server_default="20"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="1"),
    )
    op.create_index("ix_coach_codes_code", "coach_codes", ["code"], unique=True)
    op.create_index("ix_coach_codes_coach_id", "coach_codes", ["coach_id"], unique=False)

    # ── coach_students (RF-602) ───────────────────────────────────────
    op.create_table(
        "coach_students",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("coach_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("student_id", sa.Integer(),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("student_note", sa.Text(), nullable=True),
    )
    op.create_index("ix_coach_students_coach_id", "coach_students", ["coach_id"], unique=False)
    op.create_index("ix_coach_students_student_id", "coach_students", ["student_id"], unique=False)
    op.create_unique_constraint("uq_coach_student", "coach_students",
                                ["coach_id", "student_id"])


def downgrade() -> None:
    op.drop_table("coach_students")
    op.drop_table("coach_codes")
