"""add super_admin to userrole enum

Revision ID: 20260528_008
Revises: 20260511_007
Create Date: 2026-05-28 00:00:00
"""

from typing import Sequence, Union

from alembic import op


revision: str = "20260528_008"
down_revision: Union[str, Sequence[str], None] = "20260511_007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'super_admin'")


def downgrade() -> None:
    # PostgreSQL does not support removing enum values; downgrade is a no-op.
    pass
