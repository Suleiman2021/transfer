from decimal import Decimal

from sqlalchemy import inspect, text

from app.core.config import settings
from app.core.database import Base, SessionLocal, engine
from app.core.security import hash_password
from app.features.cashboxes import models as cashboxes_models  # noqa: F401
from app.features.cashboxes.models import Cashbox, CashboxType
from app.features.commissions import models as commissions_models  # noqa: F401
from app.features.commissions.models import CommissionRule
from app.features.ledger import models as ledger_models  # noqa: F401
from app.features.ledger.service import ensure_default_ledger_accounts, sync_cashbox_ledger_accounts
from app.features.risk import models as risk_models  # noqa: F401
from app.features.risk.service import ensure_default_risk_profiles
from app.features.shifts import models as shifts_models  # noqa: F401
from app.features.transfers import models as transfers_models  # noqa: F401
from app.features.users import models as users_models  # noqa: F401
from app.features.users.models import User, UserRole


def _apply_incremental_schema_updates() -> None:
    if engine.dialect.name != "postgresql":
        return

    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    if not tables:
        return

    if "transfers" in tables:
        with engine.connect() as conn:
            conn.execution_options(isolation_level="AUTOCOMMIT").execute(
                text("ALTER TYPE transfertype ADD VALUE IF NOT EXISTS 'remittance'")
            )

        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS sender_name VARCHAR(120)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS sender_phone VARCHAR(40)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS sender_country VARCHAR(80)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS sender_city VARCHAR(80)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS receiver_name VARCHAR(120)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS receiver_phone VARCHAR(40)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS receiver_country VARCHAR(80)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS receiver_city VARCHAR(80)"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS receiver_commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS receiver_commission_amount NUMERIC(18, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS sender_commission_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE transfers ADD COLUMN IF NOT EXISTS sender_commission_amount NUMERIC(18, 2) NOT NULL DEFAULT 0"))
            conn.execute(
                text(
                    "ALTER TABLE transfers "
                    "ADD COLUMN IF NOT EXISTS approval_code_required BOOLEAN NOT NULL DEFAULT FALSE"
                )
            )
            # إزالة عملية صرف رصيد العميل (customer_cashout) نهائياً وأعمدتها.
            conn.execute(text("ALTER TABLE transfers DROP COLUMN IF EXISTS cashout_profit_percent"))
            conn.execute(text("ALTER TABLE transfers DROP COLUMN IF EXISTS cashout_profit_amount"))
            conn.execute(text("ALTER TABLE transfers DROP COLUMN IF EXISTS customer_name"))
            conn.execute(text("ALTER TABLE transfers DROP COLUMN IF EXISTS customer_phone"))
            conn.execute(
                text(
                    "ALTER TABLE transfers "
                    "ADD COLUMN IF NOT EXISTS approval_code_hash VARCHAR(255)"
                )
            )
            # توسيع عمود العملة من VARCHAR(3) إلى VARCHAR(4) لدعم USDT
            conn.execute(
                text(
                    "ALTER TABLE transfers "
                    "ALTER COLUMN source_currency TYPE VARCHAR(4)"
                )
            )
            # إزالة كل ما يخص التحويل بين العملات: لا يوجد سعر صرف ولا عملة وجهة.
            conn.execute(text("ALTER TABLE transfers DROP COLUMN IF EXISTS destination_currency"))
            conn.execute(text("ALTER TABLE transfers DROP COLUMN IF EXISTS exchange_rate"))

    if "cashboxes" in tables:
        # Reflect columns BEFORE opening the transaction: doing it inside the
        # `engine.begin()` block (which holds ACCESS EXCLUSIVE on cashboxes after
        # ADD COLUMN) would open a second pooled connection that blocks on that
        # lock — a self-deadlock Postgres cannot detect.
        cashbox_columns = {col["name"] for col in inspector.get_columns("cashboxes")}
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE cashboxes "
                    "ADD COLUMN IF NOT EXISTS currency_balances JSONB NOT NULL DEFAULT '{}'"
                )
            )
            # Migrate the legacy single SYP balance into per-currency balances, then
            # drop it: each currency now keeps its own independent balance.
            if "balance" in cashbox_columns:
                conn.execute(
                    text(
                        "UPDATE cashboxes "
                        "SET currency_balances = jsonb_build_object('SYP', balance::text) "
                        "WHERE currency_balances = '{}' AND balance > 0"
                    )
                )
                conn.execute(text("ALTER TABLE cashboxes DROP COLUMN IF EXISTS balance"))

    if "cashbox_shifts" in tables:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE cashbox_shifts "
                    "ADD COLUMN IF NOT EXISTS currency VARCHAR(4) NOT NULL DEFAULT 'SYP'"
                )
            )

    if "users" in tables:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(40)"))
            conn.execute(
                text("CREATE INDEX IF NOT EXISTS ix_users_phone ON users (phone)")
            )

    if "ledger_accounts" in tables:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE ledger_accounts "
                    "ALTER COLUMN currency TYPE VARCHAR(4)"
                )
            )

    if "ledger_lines" in tables:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE ledger_lines "
                    "ALTER COLUMN currency TYPE VARCHAR(4)"
                )
            )

    if "commission_rules" in tables:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE commission_rules "
                    "ADD COLUMN IF NOT EXISTS treasury_to_accredited_fee_percent "
                    "NUMERIC(5, 2) NOT NULL DEFAULT 0"
                )
            )
            conn.execute(
                text(
                    "ALTER TABLE commission_rules "
                    "ADD COLUMN IF NOT EXISTS treasury_to_agent_fee_percent "
                    "NUMERIC(5, 2) NOT NULL DEFAULT 0"
                )
            )
            conn.execute(text("ALTER TABLE commission_rules ADD COLUMN IF NOT EXISTS treasury_to_agent_internal_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE commission_rules ADD COLUMN IF NOT EXISTS treasury_to_agent_external_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE commission_rules ADD COLUMN IF NOT EXISTS treasury_to_accredited_internal_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE commission_rules ADD COLUMN IF NOT EXISTS treasury_to_accredited_external_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE commission_rules ADD COLUMN IF NOT EXISTS remittance_treasury_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE commission_rules ADD COLUMN IF NOT EXISTS remittance_sender_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            conn.execute(text("ALTER TABLE commission_rules ADD COLUMN IF NOT EXISTS remittance_receiver_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"))
            # عمليات الشبكة بين المعتمدين أُزيلت (استُبدلت بحوالات العملاء): إسقاط عمولاتها.
            conn.execute(text("ALTER TABLE commission_rules DROP COLUMN IF EXISTS agent_topup_profit_internal_percent"))
            conn.execute(text("ALTER TABLE commission_rules DROP COLUMN IF EXISTS agent_topup_profit_external_percent"))
            conn.execute(text("ALTER TABLE commission_rules DROP COLUMN IF EXISTS agent_topup_profit_percent"))


def _feature_schema_mismatch() -> bool:
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    if not tables:
        return False

    required_tables = {
        "users",
        "cashboxes",
        "commission_rules",
        "transfers",
        "transfer_state_logs",
        "risk_profiles",
        "risk_alerts",
        "cashbox_shifts",
        "ledger_accounts",
        "ledger_entries",
        "ledger_lines",
    }
    if not required_tables.issubset(tables):
        return True

    cashbox_columns = {col["name"] for col in inspector.get_columns("cashboxes")}
    if "currency_balances" not in cashbox_columns:
        return True

    user_columns = {col["name"] for col in inspector.get_columns("users")}
    if not {"full_name", "role", "city", "country", "phone", "password_hash"}.issubset(user_columns):
        return True

    transfer_columns = {col["name"] for col in inspector.get_columns("transfers")}
    required_transfer_columns = {
        "operation_type",
        "idempotency_key",
        "state",
        "source_currency",
        "snapshot_at",
        "risk_score",
        "review_required",
        "approval_code_required",
        "approval_code_hash",
        "reviewed_by_id",
        "reviewed_at",
        "review_note",
        "is_cross_country",
        "agent_profit_percent",
        "agent_profit_amount",
    }
    if not required_transfer_columns.issubset(transfer_columns):
        return True

    commission_columns = {col["name"] for col in inspector.get_columns("commission_rules")}
    required_commission_columns = {
        "internal_fee_percent",
        "external_fee_percent",
        "treasury_to_accredited_fee_percent",
        "treasury_to_agent_fee_percent",
        "treasury_to_agent_internal_fee_percent",
        "treasury_to_agent_external_fee_percent",
        "treasury_to_accredited_internal_fee_percent",
        "treasury_to_accredited_external_fee_percent",
        "remittance_treasury_percent",
        "remittance_sender_percent",
        "remittance_receiver_percent",
    }
    if not required_commission_columns.issubset(commission_columns):
        return True

    transfer_columns_for_remittance = {
        "sender_name", "sender_phone", "sender_country", "sender_city",
        "receiver_name", "receiver_phone", "receiver_country", "receiver_city",
        "receiver_commission_percent", "receiver_commission_amount",
        "sender_commission_percent", "sender_commission_amount",
    }
    return not transfer_columns_for_remittance.issubset(transfer_columns)


def _drop_feature_schema() -> None:
    statements = [
        "DROP TABLE IF EXISTS ledger_lines CASCADE",
        "DROP TABLE IF EXISTS ledger_entries CASCADE",
        "DROP TABLE IF EXISTS ledger_accounts CASCADE",
        "DROP TABLE IF EXISTS risk_alerts CASCADE",
        "DROP TABLE IF EXISTS transfer_state_logs CASCADE",
        "DROP TABLE IF EXISTS transfers CASCADE",
        "DROP TABLE IF EXISTS cashbox_shifts CASCADE",
        "DROP TABLE IF EXISTS risk_profiles CASCADE",
        "DROP TABLE IF EXISTS commission_rules CASCADE",
        "DROP TABLE IF EXISTS cashboxes CASCADE",
        "DROP TABLE IF EXISTS users CASCADE",
        "DROP TYPE IF EXISTS ledgeraccounttype CASCADE",
        "DROP TYPE IF EXISTS riskalertseverity CASCADE",
        "DROP TYPE IF EXISTS transfertype CASCADE",
        "DROP TYPE IF EXISTS transferstate CASCADE",
        "DROP TYPE IF EXISTS shiftstatus CASCADE",
        "DROP TYPE IF EXISTS cashboxtype CASCADE",
        "DROP TYPE IF EXISTS userrole CASCADE",
    ]
    with engine.begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt))


def _ensure_schema() -> None:
    _apply_incremental_schema_updates()

    should_reset = settings.FORCE_REBUILD_SCHEMA
    schema_mismatch = _feature_schema_mismatch()

    if schema_mismatch and settings.AUTO_RESET_SCHEMA_ON_MISMATCH:
        should_reset = True

    if should_reset:
        _drop_feature_schema()
    elif schema_mismatch:
        raise RuntimeError(
            "Database schema does not match the application models. "
            "Run the Alembic migrations or use FORCE_REBUILD_SCHEMA only on a disposable database."
        )

    Base.metadata.create_all(bind=engine)


def bootstrap_system() -> None:
    _ensure_schema()

    db = SessionLocal()
    try:
        admin = db.query(User).filter(
            User.role.in_([UserRole.super_admin, UserRole.admin])
        ).first()
        if not admin and not settings.BOOTSTRAP_ADMIN_PASSWORD.strip():
            raise RuntimeError(
                "BOOTSTRAP_ADMIN_PASSWORD must be set to seed the initial admin account."
            )
        if not admin:
            admin = User(
                username=settings.BOOTSTRAP_ADMIN_USERNAME.strip().lower(),
                full_name=settings.BOOTSTRAP_ADMIN_FULL_NAME.strip(),
                role=UserRole.super_admin,
                city=settings.BOOTSTRAP_ADMIN_CITY.strip(),
                country=settings.BOOTSTRAP_ADMIN_COUNTRY.strip(),
                password_hash=hash_password(settings.BOOTSTRAP_ADMIN_PASSWORD),
                is_active=True,
            )
            db.add(admin)
            db.commit()
            db.refresh(admin)

        treasury = db.query(Cashbox).filter(Cashbox.type == CashboxType.treasury).first()
        if not treasury:
            treasury = Cashbox(
                name=settings.BOOTSTRAP_TREASURY_NAME.strip(),
                city=settings.BOOTSTRAP_ADMIN_CITY.strip(),
                country=settings.BOOTSTRAP_ADMIN_COUNTRY.strip(),
                type=CashboxType.treasury,
                manager_user_id=None,
                currency_balances={},
                is_active=True,
            )
            db.add(treasury)
            db.commit()

        existing_roles = {role for (role,) in db.query(CommissionRule.role).all()}
        defaults = {
            UserRole.admin: {
                "internal": Decimal("0"),
                "external": Decimal("0"),
                "treasury_to_accredited": Decimal("0"),
                "treasury_to_agent": Decimal("0"),

                "agent_profit_internal": Decimal("0"),
                "agent_profit_external": Decimal("0"),
                "treasury_to_agent_internal": Decimal("0"),
                "treasury_to_agent_external": Decimal("0"),
                "treasury_to_accredited_internal": Decimal("0"),
                "treasury_to_accredited_external": Decimal("0"),
                "remittance_treasury": Decimal("0"),
                "remittance_sender": Decimal("0"),
                "remittance_receiver": Decimal("0"),
            },
            UserRole.accredited: {
                "internal": Decimal("1.25"),
                "external": Decimal("1.75"),
                "treasury_to_accredited": Decimal("0"),
                "treasury_to_agent": Decimal("0"),

                "agent_profit_internal": Decimal("0"),
                "agent_profit_external": Decimal("0"),
                "treasury_to_agent_internal": Decimal("0"),
                "treasury_to_agent_external": Decimal("0"),
                "treasury_to_accredited_internal": Decimal("0"),
                "treasury_to_accredited_external": Decimal("0"),
                "remittance_treasury": Decimal("0"),
                "remittance_sender": Decimal("0"),
                "remittance_receiver": Decimal("0"),
            },
            UserRole.agent: {
                "internal": Decimal("2.00"),
                "external": Decimal("2.50"),
                "treasury_to_accredited": Decimal("0"),
                "treasury_to_agent": Decimal("0"),

                "agent_profit_internal": Decimal("0.75"),
                "agent_profit_external": Decimal("1.00"),
                "treasury_to_agent_internal": Decimal("0"),
                "treasury_to_agent_external": Decimal("0"),
                "treasury_to_accredited_internal": Decimal("0"),
                "treasury_to_accredited_external": Decimal("0"),
                "remittance_treasury": Decimal("0"),
                "remittance_sender": Decimal("0"),
                "remittance_receiver": Decimal("0"),
            },
        }
        for role, fees in defaults.items():
            if role not in existing_roles:
                db.add(
                    CommissionRule(
                        role=role,
                        internal_fee_percent=fees["internal"],
                        external_fee_percent=fees["external"],
                        treasury_to_accredited_fee_percent=fees["treasury_to_accredited"],
                        treasury_to_agent_fee_percent=fees["treasury_to_agent"],
                        treasury_to_agent_internal_fee_percent=fees["treasury_to_agent_internal"],
                        treasury_to_agent_external_fee_percent=fees["treasury_to_agent_external"],
                        treasury_to_accredited_internal_fee_percent=fees["treasury_to_accredited_internal"],
                        treasury_to_accredited_external_fee_percent=fees["treasury_to_accredited_external"],
                        remittance_treasury_percent=fees["remittance_treasury"],
                        remittance_sender_percent=fees["remittance_sender"],
                        remittance_receiver_percent=fees["remittance_receiver"],
                        is_active=True,
                    )
                )

        db.flush()
        ensure_default_ledger_accounts(db)
        sync_cashbox_ledger_accounts(db)

        db.commit()

        ensure_default_risk_profiles(db)
        db.commit()
    finally:
        db.close()
