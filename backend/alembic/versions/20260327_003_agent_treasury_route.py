"""agent treasury route

Revision ID: 20260327_003
Revises: 20260327_002
Create Date: 2026-03-27 13:25:00
"""

from typing import Sequence, Union

from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260327_003"
down_revision: Union[str, Sequence[str], None] = "20260327_002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


transfer_type = postgresql.ENUM(
    "network_transfer",
    "topup",
    "collection",
    "agent_funding",
    "agent_collection",
    name="transfertype",
    create_type=False,
)



def upgrade() -> None:
    op.execute("ALTER TYPE transfertype ADD VALUE IF NOT EXISTS 'agent_funding'")
    op.execute("ALTER TYPE transfertype ADD VALUE IF NOT EXISTS 'agent_collection'")



def downgrade() -> None:
    pass
