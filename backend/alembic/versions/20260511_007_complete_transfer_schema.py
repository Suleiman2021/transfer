"""complete transfer and commission schema sync

Revision ID: 20260511_007
Revises: 20260511_006
Create Date: 2026-05-11 20:00:00
"""

from typing import Sequence, Union

from alembic import op


revision: str = "20260511_007"
down_revision: Union[str, Sequence[str], None] = "20260511_006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE transfertype ADD VALUE IF NOT EXISTS 'customer_cashout'")

    op.execute(
        """
        ALTER TABLE transfers
        ADD COLUMN IF NOT EXISTS cashout_profit_percent
        NUMERIC(5, 2) NOT NULL DEFAULT 0
        """
    )
    op.execute(
        """
        ALTER TABLE transfers
        ADD COLUMN IF NOT EXISTS cashout_profit_amount
        NUMERIC(18, 2) NOT NULL DEFAULT 0
        """
    )
    op.execute("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS customer_name VARCHAR(120)")
    op.execute("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(40)")

    op.execute(
        """
        ALTER TABLE commission_rules
        ADD COLUMN IF NOT EXISTS treasury_to_accredited_fee_percent
        NUMERIC(5, 2) NOT NULL DEFAULT 0
        """
    )
    op.execute(
        """
        ALTER TABLE commission_rules
        ADD COLUMN IF NOT EXISTS treasury_to_agent_fee_percent
        NUMERIC(5, 2) NOT NULL DEFAULT 0
        """
    )
    op.execute(
        """
        ALTER TABLE commission_rules
        ADD COLUMN IF NOT EXISTS treasury_collection_from_accredited_fee_percent
        NUMERIC(5, 2) NOT NULL DEFAULT 0
        """
    )
    op.execute(
        """
        ALTER TABLE commission_rules
        ADD COLUMN IF NOT EXISTS treasury_collection_from_agent_fee_percent
        NUMERIC(5, 2) NOT NULL DEFAULT 0
        """
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE commission_rules "
        "DROP COLUMN IF EXISTS treasury_collection_from_agent_fee_percent"
    )
    op.execute(
        "ALTER TABLE commission_rules "
        "DROP COLUMN IF EXISTS treasury_collection_from_accredited_fee_percent"
    )
    op.execute(
        "ALTER TABLE commission_rules "
        "DROP COLUMN IF EXISTS treasury_to_agent_fee_percent"
    )
    op.execute(
        "ALTER TABLE commission_rules "
        "DROP COLUMN IF EXISTS treasury_to_accredited_fee_percent"
    )
    op.execute("ALTER TABLE transfers DROP COLUMN IF EXISTS customer_phone")
    op.execute("ALTER TABLE transfers DROP COLUMN IF EXISTS customer_name")
    op.execute("ALTER TABLE transfers DROP COLUMN IF EXISTS cashout_profit_amount")
    op.execute("ALTER TABLE transfers DROP COLUMN IF EXISTS cashout_profit_percent")
