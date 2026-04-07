"""feature based rebuild baseline

Revision ID: 20260325_001
Revises:
Create Date: 2026-03-25 01:05:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260325_001"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


user_role = postgresql.ENUM("admin", "accredited", "agent", name="userrole", create_type=False)
cashbox_type = postgresql.ENUM("treasury", "accredited", name="cashboxtype", create_type=False)
transfer_state = postgresql.ENUM(
    "initiated",
    "pending_review",
    "approved",
    "completed",
    "rejected",
    "failed",
    name="transferstate",
    create_type=False,
)
risk_alert_severity = postgresql.ENUM("low", "medium", "high", name="riskalertseverity", create_type=False)
shift_status = postgresql.ENUM("open", "closed", name="shiftstatus", create_type=False)
ledger_account_type = postgresql.ENUM(
    "asset",
    "liability",
    "equity",
    "revenue",
    "expense",
    name="ledgeraccounttype",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    user_role.create(bind, checkfirst=True)
    cashbox_type.create(bind, checkfirst=True)
    transfer_state.create(bind, checkfirst=True)
    risk_alert_severity.create(bind, checkfirst=True)
    shift_status.create(bind, checkfirst=True)
    ledger_account_type.create(bind, checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("username", sa.String(length=50), nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("role", user_role, nullable=False),
        sa.Column("city", sa.String(length=100), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_by_id", sa.UUID(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("username"),
    )
    op.create_index("ix_users_username", "users", ["username"], unique=False)

    op.create_table(
        "cashboxes",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("city", sa.String(length=100), nullable=False),
        sa.Column("type", cashbox_type, nullable=False),
        sa.Column("manager_user_id", sa.UUID(), nullable=True),
        sa.Column("balance", sa.Numeric(precision=18, scale=2), nullable=False, server_default=sa.text("0")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["manager_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    op.create_index("ix_cashboxes_city", "cashboxes", ["city"], unique=False)
    op.create_index("ix_cashboxes_manager_user_id", "cashboxes", ["manager_user_id"], unique=False)

    op.create_table(
        "commission_rules",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("role", user_role, nullable=False),
        sa.Column("fee_percent", sa.Numeric(precision=5, scale=2), nullable=False, server_default=sa.text("0")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True, server_default=sa.text("now()")),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("role"),
    )

    op.create_table(
        "risk_profiles",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("daily_amount_limit", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("daily_transfer_limit", sa.Integer(), nullable=False),
        sa.Column("single_transfer_soft_limit", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("single_transfer_hard_limit", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("requires_review_for_cross_city", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", name="uq_risk_profile_user"),
    )
    op.create_index("ix_risk_profiles_user_id", "risk_profiles", ["user_id"], unique=False)

    op.create_table(
        "transfers",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("from_cashbox_id", sa.UUID(), nullable=False),
        sa.Column("to_cashbox_id", sa.UUID(), nullable=False),
        sa.Column("treasury_cashbox_id", sa.UUID(), nullable=False),
        sa.Column("idempotency_key", sa.String(length=120), nullable=True),
        sa.Column("state", transfer_state, nullable=False),
        sa.Column("amount", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("commission_role", user_role, nullable=False),
        sa.Column("commission_percent", sa.Numeric(precision=5, scale=2), nullable=False, server_default=sa.text("0")),
        sa.Column("commission_amount", sa.Numeric(precision=18, scale=2), nullable=False, server_default=sa.text("0")),
        sa.Column("net_amount", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("source_currency", sa.String(length=3), nullable=False, server_default=sa.text("'SYP'")),
        sa.Column("destination_currency", sa.String(length=3), nullable=False, server_default=sa.text("'SYP'")),
        sa.Column("exchange_rate", sa.Numeric(precision=18, scale=6), nullable=False, server_default=sa.text("1")),
        sa.Column("snapshot_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("risk_score", sa.Numeric(precision=5, scale=2), nullable=False, server_default=sa.text("0")),
        sa.Column("review_required", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("reviewed_by_id", sa.UUID(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("review_note", sa.Text(), nullable=True),
        sa.Column("performed_by_id", sa.UUID(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["from_cashbox_id"], ["cashboxes.id"]),
        sa.ForeignKeyConstraint(["to_cashbox_id"], ["cashboxes.id"]),
        sa.ForeignKeyConstraint(["treasury_cashbox_id"], ["cashboxes.id"]),
        sa.ForeignKeyConstraint(["reviewed_by_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["performed_by_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("performed_by_id", "idempotency_key", name="uq_transfer_performer_idempotency"),
    )
    op.create_index("ix_transfers_from_cashbox_id", "transfers", ["from_cashbox_id"], unique=False)
    op.create_index("ix_transfers_to_cashbox_id", "transfers", ["to_cashbox_id"], unique=False)
    op.create_index("ix_transfers_idempotency_key", "transfers", ["idempotency_key"], unique=False)
    op.create_index("ix_transfers_state", "transfers", ["state"], unique=False)
    op.create_index("ix_transfers_reviewed_by_id", "transfers", ["reviewed_by_id"], unique=False)
    op.create_index("ix_transfers_performed_by_id", "transfers", ["performed_by_id"], unique=False)
    op.create_index("ix_transfers_created_at", "transfers", ["created_at"], unique=False)

    op.create_table(
        "transfer_state_logs",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("transfer_id", sa.UUID(), nullable=False),
        sa.Column("state", transfer_state, nullable=False),
        sa.Column("actor_user_id", sa.UUID(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("context", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["transfer_id"], ["transfers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_transfer_state_logs_transfer_id", "transfer_state_logs", ["transfer_id"], unique=False)
    op.create_index("ix_transfer_state_logs_state", "transfer_state_logs", ["state"], unique=False)
    op.create_index("ix_transfer_state_logs_actor_user_id", "transfer_state_logs", ["actor_user_id"], unique=False)
    op.create_index("ix_transfer_state_logs_created_at", "transfer_state_logs", ["created_at"], unique=False)

    op.create_table(
        "risk_alerts",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("transfer_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("code", sa.String(length=80), nullable=False),
        sa.Column("severity", risk_alert_severity, nullable=False),
        sa.Column("message", sa.String(length=300), nullable=False),
        sa.Column("requires_review", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("resolved", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["transfer_id"], ["transfers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_risk_alerts_transfer_id", "risk_alerts", ["transfer_id"], unique=False)
    op.create_index("ix_risk_alerts_user_id", "risk_alerts", ["user_id"], unique=False)

    op.create_table(
        "cashbox_shifts",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("cashbox_id", sa.UUID(), nullable=False),
        sa.Column("opened_by_id", sa.UUID(), nullable=False),
        sa.Column("closed_by_id", sa.UUID(), nullable=True),
        sa.Column("status", shift_status, nullable=False),
        sa.Column("opening_balance", sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column("expected_closing_balance", sa.Numeric(precision=18, scale=2), nullable=True),
        sa.Column("actual_closing_balance", sa.Numeric(precision=18, scale=2), nullable=True),
        sa.Column("over_short_amount", sa.Numeric(precision=18, scale=2), nullable=True),
        sa.Column("opening_note", sa.Text(), nullable=True),
        sa.Column("closing_note", sa.Text(), nullable=True),
        sa.Column("settlement_applied", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("opened_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["cashbox_id"], ["cashboxes.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["opened_by_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["closed_by_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_cashbox_shifts_cashbox_id", "cashbox_shifts", ["cashbox_id"], unique=False)
    op.create_index("ix_cashbox_shifts_opened_by_id", "cashbox_shifts", ["opened_by_id"], unique=False)
    op.create_index("ix_cashbox_shifts_closed_by_id", "cashbox_shifts", ["closed_by_id"], unique=False)
    op.create_index("ix_cashbox_shifts_status", "cashbox_shifts", ["status"], unique=False)

    op.create_table(
        "ledger_accounts",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("code", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("account_type", ledger_account_type, nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False, server_default=sa.text("'SYP'")),
        sa.Column("cashbox_id", sa.UUID(), nullable=True),
        sa.Column("is_system", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["cashbox_id"], ["cashboxes.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
        sa.UniqueConstraint("cashbox_id"),
    )
    op.create_index("ix_ledger_accounts_code", "ledger_accounts", ["code"], unique=False)
    op.create_index("ix_ledger_accounts_cashbox_id", "ledger_accounts", ["cashbox_id"], unique=False)

    op.create_table(
        "ledger_entries",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("transfer_id", sa.UUID(), nullable=True),
        sa.Column("reference_type", sa.String(length=50), nullable=False, server_default=sa.text("'transfer'")),
        sa.Column("reference_id", sa.UUID(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_by_id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["transfer_id"], ["transfers.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("transfer_id"),
    )
    op.create_index("ix_ledger_entries_transfer_id", "ledger_entries", ["transfer_id"], unique=False)
    op.create_index("ix_ledger_entries_reference_id", "ledger_entries", ["reference_id"], unique=False)
    op.create_index("ix_ledger_entries_created_by_id", "ledger_entries", ["created_by_id"], unique=False)
    op.create_index("ix_ledger_entries_created_at", "ledger_entries", ["created_at"], unique=False)

    op.create_table(
        "ledger_lines",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("entry_id", sa.UUID(), nullable=False),
        sa.Column("account_id", sa.UUID(), nullable=False),
        sa.Column("debit", sa.Numeric(precision=18, scale=2), nullable=False, server_default=sa.text("0")),
        sa.Column("credit", sa.Numeric(precision=18, scale=2), nullable=False, server_default=sa.text("0")),
        sa.Column("currency", sa.String(length=3), nullable=False, server_default=sa.text("'SYP'")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["entry_id"], ["ledger_entries.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["account_id"], ["ledger_accounts.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_ledger_lines_entry_id", "ledger_lines", ["entry_id"], unique=False)
    op.create_index("ix_ledger_lines_account_id", "ledger_lines", ["account_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_ledger_lines_account_id", table_name="ledger_lines")
    op.drop_index("ix_ledger_lines_entry_id", table_name="ledger_lines")
    op.drop_table("ledger_lines")

    op.drop_index("ix_ledger_entries_created_at", table_name="ledger_entries")
    op.drop_index("ix_ledger_entries_created_by_id", table_name="ledger_entries")
    op.drop_index("ix_ledger_entries_reference_id", table_name="ledger_entries")
    op.drop_index("ix_ledger_entries_transfer_id", table_name="ledger_entries")
    op.drop_table("ledger_entries")

    op.drop_index("ix_ledger_accounts_cashbox_id", table_name="ledger_accounts")
    op.drop_index("ix_ledger_accounts_code", table_name="ledger_accounts")
    op.drop_table("ledger_accounts")

    op.drop_index("ix_cashbox_shifts_status", table_name="cashbox_shifts")
    op.drop_index("ix_cashbox_shifts_closed_by_id", table_name="cashbox_shifts")
    op.drop_index("ix_cashbox_shifts_opened_by_id", table_name="cashbox_shifts")
    op.drop_index("ix_cashbox_shifts_cashbox_id", table_name="cashbox_shifts")
    op.drop_table("cashbox_shifts")

    op.drop_index("ix_risk_alerts_user_id", table_name="risk_alerts")
    op.drop_index("ix_risk_alerts_transfer_id", table_name="risk_alerts")
    op.drop_table("risk_alerts")

    op.drop_index("ix_transfer_state_logs_created_at", table_name="transfer_state_logs")
    op.drop_index("ix_transfer_state_logs_actor_user_id", table_name="transfer_state_logs")
    op.drop_index("ix_transfer_state_logs_state", table_name="transfer_state_logs")
    op.drop_index("ix_transfer_state_logs_transfer_id", table_name="transfer_state_logs")
    op.drop_table("transfer_state_logs")

    op.drop_index("ix_transfers_created_at", table_name="transfers")
    op.drop_index("ix_transfers_performed_by_id", table_name="transfers")
    op.drop_index("ix_transfers_reviewed_by_id", table_name="transfers")
    op.drop_index("ix_transfers_state", table_name="transfers")
    op.drop_index("ix_transfers_idempotency_key", table_name="transfers")
    op.drop_index("ix_transfers_to_cashbox_id", table_name="transfers")
    op.drop_index("ix_transfers_from_cashbox_id", table_name="transfers")
    op.drop_table("transfers")

    op.drop_index("ix_risk_profiles_user_id", table_name="risk_profiles")
    op.drop_table("risk_profiles")

    op.drop_table("commission_rules")

    op.drop_index("ix_cashboxes_manager_user_id", table_name="cashboxes")
    op.drop_index("ix_cashboxes_city", table_name="cashboxes")
    op.drop_table("cashboxes")

    op.drop_index("ix_users_username", table_name="users")
    op.drop_table("users")

    bind = op.get_bind()
    ledger_account_type.drop(bind, checkfirst=True)
    shift_status.drop(bind, checkfirst=True)
    risk_alert_severity.drop(bind, checkfirst=True)
    transfer_state.drop(bind, checkfirst=True)
    cashbox_type.drop(bind, checkfirst=True)
    user_role.drop(bind, checkfirst=True)
