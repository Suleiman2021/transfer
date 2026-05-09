"""add transfer approval codes

Revision ID: 20260426_005
Revises: 20260328_004
Create Date: 2026-04-26 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "20260426_005"
down_revision: str | None = "20260328_004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "transfers",
        sa.Column(
            "approval_code_required",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )
    op.add_column(
        "transfers",
        sa.Column("approval_code_hash", sa.String(length=255), nullable=True),
    )
    op.alter_column("transfers", "approval_code_required", server_default=None)


def downgrade() -> None:
    op.drop_column("transfers", "approval_code_hash")
    op.drop_column("transfers", "approval_code_required")
