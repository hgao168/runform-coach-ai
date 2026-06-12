"""add email, password_hash, google_sub columns to users

Revision ID: 20260612_0008
Revises: 20260523_0007
Create Date: 2026-06-12 00:08:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260612_0008"
down_revision = "20260523_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("email", sa.String(255), unique=True, nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("password_hash", sa.String(255), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("google_sub", sa.String(255), unique=True, nullable=True),
    )
    # Create indexes for lookups by email and google_sub
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_google_sub", "users", ["google_sub"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_users_google_sub", table_name="users")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_column("users", "google_sub")
    op.drop_column("users", "password_hash")
    op.drop_column("users", "email")
