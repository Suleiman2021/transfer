"""agent flow refresh

Revision ID: 20260327_002
Revises: 20260325_001
Create Date: 2026-03-27 12:10:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260327_002"
down_revision: Union[str, Sequence[str], None] = "20260325_001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


transfer_type = postgresql.ENUM(
    "network_transfer",
    "topup",
    "collection",
    name="transfertype",
    create_type=False,
)



def upgrade() -> None:
    bind = op.get_bind()

    op.execute("ALTER TYPE cashboxtype ADD VALUE IF NOT EXISTS 'agent'")
    transfer_type.create(bind, checkfirst=True)

    op.add_column(
        "transfers",
        sa.Column(
            "operation_type",
            transfer_type,
            nullable=False,
            server_default=sa.text("'network_transfer'"),
        ),
    )
    op.create_index("ix_transfers_operation_type", "transfers", ["operation_type"], unique=False)

    op.execute(
        """
        UPDATE transfers
        SET operation_type = CASE
            WHEN from_cashbox.type = 'accredited' AND to_cashbox.type = 'accredited' THEN 'network_transfer'::transfertype
            WHEN from_cashbox.type = 'treasury' AND to_cashbox.type = 'accredited' THEN 'topup'::transfertype
            ELSE 'collection'::transfertype
        END
        FROM cashboxes AS from_cashbox, cashboxes AS to_cashbox
        WHERE transfers.from_cashbox_id = from_cashbox.id
          AND transfers.to_cashbox_id = to_cashbox.id
        """
    )

    op.alter_column("transfers", "operation_type", server_default=None)



def downgrade() -> None:
    op.drop_index("ix_transfers_operation_type", table_name="transfers")
    op.drop_column("transfers", "operation_type")

    bind = op.get_bind()
    transfer_type.drop(bind, checkfirst=True)

