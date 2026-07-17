"""remove cross-currency conversion (exchange rates, destination currency, legacy balance)

Each currency keeps its own independent balance per cashbox. There is no
conversion between currencies, so the exchange-rate / destination-currency
machinery and the single legacy SYP balance column are removed.

Revision ID: 20260615_011
Revises: 20260607_010
Create Date: 2026-06-15 00:00:00
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "20260615_011"
down_revision: Union[str, Sequence[str], None] = "20260607_010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    # Transfers: drop conversion columns and the removed customer-cashout columns.
    transfer_columns = {c["name"] for c in inspector.get_columns("transfers")}
    for col in (
        "destination_currency",
        "exchange_rate",
        "cashout_profit_percent",
        "cashout_profit_amount",
        "customer_name",
        "customer_phone",
    ):
        if col in transfer_columns:
            op.drop_column("transfers", col)

    # Cashbox shifts: reconcile a single currency per shift.
    shift_columns = {c["name"] for c in inspector.get_columns("cashbox_shifts")}
    if "currency" not in shift_columns:
        op.add_column(
            "cashbox_shifts",
            sa.Column("currency", sa.String(length=4), nullable=False, server_default="SYP"),
        )

    # Cashboxes: migrate the legacy SYP balance into per-currency balances, then drop it.
    cashbox_columns = {c["name"] for c in inspector.get_columns("cashboxes")}
    if "currency_balances" not in cashbox_columns:
        op.add_column(
            "cashboxes",
            sa.Column("currency_balances", sa.JSON(), nullable=False, server_default="{}"),
        )
    if "balance" in cashbox_columns:
        op.execute(
            "UPDATE cashboxes "
            "SET currency_balances = jsonb_build_object('SYP', balance::text) "
            "WHERE (currency_balances = '{}' OR currency_balances IS NULL) AND balance > 0"
        )
        op.drop_column("cashboxes", "balance")

    # Network transfers between accredited cashboxes were removed (replaced by
    # customer remittances): drop their dedicated agent-topup-profit commissions.
    commission_columns = {c["name"] for c in inspector.get_columns("commission_rules")}
    for col in (
        "agent_topup_profit_internal_percent",
        "agent_topup_profit_external_percent",
        "agent_topup_profit_percent",
    ):
        if col in commission_columns:
            op.drop_column("commission_rules", col)

    # Drop the dedicated exchange-rates table if it still exists.
    if "exchange_rates" in tables:
        op.execute("DROP INDEX IF EXISTS ix_exchange_rates_currency")
        op.drop_table("exchange_rates")


def downgrade() -> None:
    # Restore the columns (data is not reconstructed; conversion is no longer supported).
    op.add_column(
        "cashboxes",
        sa.Column("balance", sa.Numeric(18, 2), nullable=False, server_default="0"),
    )
    op.execute(
        "UPDATE cashboxes "
        "SET balance = COALESCE((currency_balances ->> 'SYP')::numeric, 0)"
    )
    op.drop_column("cashbox_shifts", "currency")
    op.add_column(
        "transfers",
        sa.Column("exchange_rate", sa.Numeric(18, 6), nullable=False, server_default="1"),
    )
    op.add_column(
        "transfers",
        sa.Column("destination_currency", sa.String(length=4), nullable=False, server_default="SYP"),
    )
    op.add_column(
        "transfers",
        sa.Column("cashout_profit_percent", sa.Numeric(5, 2), nullable=False, server_default="0"),
    )
    op.add_column(
        "transfers",
        sa.Column("cashout_profit_amount", sa.Numeric(18, 2), nullable=False, server_default="0"),
    )
    op.add_column("transfers", sa.Column("customer_name", sa.String(length=120), nullable=True))
    op.add_column("transfers", sa.Column("customer_phone", sa.String(length=40), nullable=True))
    for col in (
        "agent_topup_profit_internal_percent",
        "agent_topup_profit_external_percent",
        "agent_topup_profit_percent",
    ):
        op.add_column(
            "commission_rules",
            sa.Column(col, sa.Numeric(5, 2), nullable=False, server_default="0"),
        )
