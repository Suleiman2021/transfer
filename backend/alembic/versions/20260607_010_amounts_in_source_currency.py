"""store Transfer amounts in source_currency instead of SYP

Revision ID: 20260607_010
Revises: 20260528_009
Create Date: 2026-06-07 00:00:00
"""

from typing import Sequence, Union
from alembic import op


revision: str = "20260607_010"
down_revision: Union[str, Sequence[str], None] = "20260528_009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Convert amount fields from SYP to source_currency for non-SYP transfers.
    # Only rows where source_currency != 'SYP' and exchange_rate > 1 are affected.
    op.execute("""
        UPDATE transfers
        SET
            amount             = ROUND(CAST(amount              AS NUMERIC) / NULLIF(CAST(exchange_rate AS NUMERIC), 0), 2),
            commission_amount  = ROUND(CAST(commission_amount   AS NUMERIC) / NULLIF(CAST(exchange_rate AS NUMERIC), 0), 2),
            agent_profit_amount   = ROUND(CAST(agent_profit_amount    AS NUMERIC) / NULLIF(CAST(exchange_rate AS NUMERIC), 0), 2),
            cashout_profit_amount = ROUND(CAST(cashout_profit_amount  AS NUMERIC) / NULLIF(CAST(exchange_rate AS NUMERIC), 0), 2),
            net_amount         = ROUND(CAST(net_amount          AS NUMERIC) / NULLIF(CAST(exchange_rate AS NUMERIC), 0), 2)
        WHERE source_currency != 'SYP'
          AND CAST(exchange_rate AS NUMERIC) > 1
    """)


def downgrade() -> None:
    # Revert: multiply source_currency amounts back to SYP.
    op.execute("""
        UPDATE transfers
        SET
            amount             = ROUND(CAST(amount              AS NUMERIC) * CAST(exchange_rate AS NUMERIC), 2),
            commission_amount  = ROUND(CAST(commission_amount   AS NUMERIC) * CAST(exchange_rate AS NUMERIC), 2),
            agent_profit_amount   = ROUND(CAST(agent_profit_amount    AS NUMERIC) * CAST(exchange_rate AS NUMERIC), 2),
            cashout_profit_amount = ROUND(CAST(cashout_profit_amount  AS NUMERIC) * CAST(exchange_rate AS NUMERIC), 2),
            net_amount         = ROUND(CAST(net_amount          AS NUMERIC) * CAST(exchange_rate AS NUMERIC), 2)
        WHERE source_currency != 'SYP'
          AND CAST(exchange_rate AS NUMERIC) > 1
    """)
