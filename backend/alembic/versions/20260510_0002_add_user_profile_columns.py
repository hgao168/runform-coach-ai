"""add user profile columns

Revision ID: 20260510_0002
Revises: 20260510_0001
Create Date: 2026-05-10 00:01:00
"""

from alembic import op
import sqlalchemy as sa

revision = "20260510_0002"
down_revision = "20260510_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("first_name", sa.String(128), nullable=True))
    op.add_column("users", sa.Column("last_name", sa.String(128), nullable=True))
    op.add_column("users", sa.Column("nickname", sa.String(128), nullable=True))
    op.add_column("users", sa.Column("level", sa.String(32), nullable=True))
    op.add_column("users", sa.Column("weekly_mileage_km", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("running_days_per_week", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("height_cm", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("weight_kg", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("target", sa.String(64), nullable=True))
    op.add_column("users", sa.Column("injury_note", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("gender", sa.String(32), nullable=True))
    op.add_column("users", sa.Column("shoe_size", sa.String(32), nullable=True))
    op.add_column("users", sa.Column("shoe_brand_model", sa.String(128), nullable=True))
    op.add_column("users", sa.Column("leg_length_cm", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("date_of_birth", sa.String(32), nullable=True))
    op.add_column("users", sa.Column("weekly_exercise_hours", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "weekly_exercise_hours")
    op.drop_column("users", "date_of_birth")
    op.drop_column("users", "leg_length_cm")
    op.drop_column("users", "shoe_brand_model")
    op.drop_column("users", "shoe_size")
    op.drop_column("users", "gender")
    op.drop_column("users", "injury_note")
    op.drop_column("users", "target")
    op.drop_column("users", "weight_kg")
    op.drop_column("users", "height_cm")
    op.drop_column("users", "running_days_per_week")
    op.drop_column("users", "weekly_mileage_km")
    op.drop_column("users", "level")
    op.drop_column("users", "nickname")
    op.drop_column("users", "last_name")
    op.drop_column("users", "first_name")
