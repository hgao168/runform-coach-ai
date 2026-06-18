"""idempotent fix: ensure email, password_hash, google_sub columns exist on users

Revision ID: 20260619_0010
Revises: 20260617_0009
Create Date: 2026-06-19 00:10:00

This migration uses IF NOT EXISTS so it's safe to run on both:
- production (where migration 0008 was stamped but columns are missing)
- staging (where columns already exist)
"""

from alembic import op

revision = "20260619_0010"
down_revision = "20260617_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub VARCHAR(255)")
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (email)")
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_google_sub ON users (google_sub)")


def downgrade() -> None:
    # Intentionally no-op: these columns may have been added by 0008 originally
    pass
