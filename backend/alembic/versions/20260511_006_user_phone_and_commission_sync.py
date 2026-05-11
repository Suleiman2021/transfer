"""user phone and commission model sync

Revision ID: 20260511_006
Revises: 20260426_005
Create Date: 2026-05-11 12:00:00
"""

from typing import Sequence, Union

from alembic import op


revision: str = "20260511_006"
down_revision: Union[str, Sequence[str], None] = "20260426_005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(40)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_users_phone ON users (phone)")

    op.execute(
        """
        ALTER TABLE commission_rules
        ADD COLUMN IF NOT EXISTS agent_topup_profit_internal_percent
        NUMERIC(5, 2) NOT NULL DEFAULT 0
        """
    )
    op.execute(
        """
        ALTER TABLE commission_rules
        ADD COLUMN IF NOT EXISTS agent_topup_profit_external_percent
        NUMERIC(5, 2) NOT NULL DEFAULT 0
        """
    )
    op.execute(
        """
        UPDATE commission_rules
        SET agent_topup_profit_internal_percent = COALESCE(agent_topup_profit_percent, 0),
            agent_topup_profit_external_percent = COALESCE(agent_topup_profit_percent, 0)
        """
    )


def downgrade() -> None:
    op.drop_column("commission_rules", "agent_topup_profit_external_percent")
    op.drop_column("commission_rules", "agent_topup_profit_internal_percent")
    op.drop_index("ix_users_phone", table_name="users")
    op.drop_column("users", "phone")
