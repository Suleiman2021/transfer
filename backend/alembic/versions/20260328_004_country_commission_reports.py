"""country and advanced commission/report fields

Revision ID: 20260328_004
Revises: 20260327_003
Create Date: 2026-03-28 09:30:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260328_004"
down_revision: Union[str, Sequence[str], None] = "20260327_003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("country", sa.String(length=100), nullable=True))
    op.execute("UPDATE users SET country = COALESCE(NULLIF(city, ''), 'syria')")
    op.alter_column("users", "country", existing_type=sa.String(length=100), nullable=False)
    op.create_index("ix_users_country", "users", ["country"], unique=False)

    op.add_column("cashboxes", sa.Column("country", sa.String(length=100), nullable=True))
    op.execute("UPDATE cashboxes SET country = COALESCE(NULLIF(city, ''), 'syria')")
    op.alter_column("cashboxes", "country", existing_type=sa.String(length=100), nullable=False)
    op.create_index("ix_cashboxes_country", "cashboxes", ["country"], unique=False)

    op.add_column(
        "commission_rules",
        sa.Column(
            "internal_fee_percent",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "commission_rules",
        sa.Column(
            "external_fee_percent",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "commission_rules",
        sa.Column(
            "agent_topup_profit_percent",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.execute(
        """
        UPDATE commission_rules
        SET internal_fee_percent = COALESCE(fee_percent, 0),
            external_fee_percent = COALESCE(fee_percent, 0),
            agent_topup_profit_percent = 0
        """
    )
    op.drop_column("commission_rules", "fee_percent")

    op.add_column(
        "transfers",
        sa.Column("is_cross_country", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "transfers",
        sa.Column(
            "agent_profit_percent",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.add_column(
        "transfers",
        sa.Column(
            "agent_profit_amount",
            sa.Numeric(precision=18, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.execute(
        """
        UPDATE transfers AS t
        SET is_cross_country = (COALESCE(fc.country, '') <> COALESCE(tc.country, ''))
        FROM cashboxes AS fc, cashboxes AS tc
        WHERE t.from_cashbox_id = fc.id
          AND t.to_cashbox_id = tc.id
        """
    )


def downgrade() -> None:
    op.drop_column("transfers", "agent_profit_amount")
    op.drop_column("transfers", "agent_profit_percent")
    op.drop_column("transfers", "is_cross_country")

    op.add_column(
        "commission_rules",
        sa.Column(
            "fee_percent",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.execute(
        """
        UPDATE commission_rules
        SET fee_percent = COALESCE(internal_fee_percent, 0)
        """
    )
    op.drop_column("commission_rules", "agent_topup_profit_percent")
    op.drop_column("commission_rules", "external_fee_percent")
    op.drop_column("commission_rules", "internal_fee_percent")

    op.drop_index("ix_cashboxes_country", table_name="cashboxes")
    op.drop_column("cashboxes", "country")

    op.drop_index("ix_users_country", table_name="users")
    op.drop_column("users", "country")
