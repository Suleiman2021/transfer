"""add exchange_rates table

Revision ID: 20260528_009
Revises: 20260528_008
Create Date: 2026-05-28 10:00:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260528_009"
down_revision: Union[str, Sequence[str], None] = "20260528_008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "exchange_rates",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False, default=sa.text("gen_random_uuid()")),
        sa.Column("currency", sa.String(10), nullable=False),
        sa.Column("rate_to_syp", sa.Numeric(18, 4), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("currency"),
    )
    op.create_index("ix_exchange_rates_currency", "exchange_rates", ["currency"])

    op.execute("""
        INSERT INTO exchange_rates (id, currency, rate_to_syp)
        VALUES
            (gen_random_uuid(), 'SYP',  1.0),
            (gen_random_uuid(), 'USD',  14000.0),
            (gen_random_uuid(), 'EUR',  15500.0),
            (gen_random_uuid(), 'USDT', 14000.0)
    """)


def downgrade() -> None:
    op.drop_index("ix_exchange_rates_currency", table_name="exchange_rates")
    op.drop_table("exchange_rates")
