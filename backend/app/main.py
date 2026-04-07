from decimal import Decimal

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text

from app.core.config import settings
from app.core.database import Base, SessionLocal, engine
from app.core.security import hash_password
from app.features.admin.routes import router as admin_router
from app.features.auth.routes import router as auth_router
from app.features.cashboxes.models import Cashbox, CashboxType
from app.features.cashboxes.routes import router as cashboxes_router
from app.features.commissions.models import CommissionRule
from app.features.commissions.routes import router as commissions_router
from app.features.ledger.routes import router as ledger_router
from app.features.ledger.service import ensure_default_ledger_accounts, sync_cashbox_ledger_accounts
from app.features.risk.routes import router as risk_router
from app.features.risk.service import ensure_default_risk_profiles
from app.features.shifts.routes import router as shifts_router
from app.features.transfers.routes import router as transfers_router
from app.features.users.models import User, UserRole


app = FastAPI(
    title=f"{settings.COMPANY_NAME} API",
    description="Feature-based remittance system for a single-company cashbox network",
    version="2.3.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(cashboxes_router)
app.include_router(commissions_router)
app.include_router(transfers_router)
app.include_router(risk_router)
app.include_router(shifts_router)
app.include_router(ledger_router)



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
                text(
                    "ALTER TYPE transfertype ADD VALUE IF NOT EXISTS 'customer_cashout'"
                )
            )

        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE transfers "
                    "ADD COLUMN IF NOT EXISTS cashout_profit_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"
                )
            )
            conn.execute(
                text(
                    "ALTER TABLE transfers "
                    "ADD COLUMN IF NOT EXISTS cashout_profit_amount NUMERIC(18, 2) NOT NULL DEFAULT 0"
                )
            )
            conn.execute(
                text(
                    "ALTER TABLE transfers "
                    "ADD COLUMN IF NOT EXISTS customer_name VARCHAR(120)"
                )
            )
            conn.execute(
                text(
                    "ALTER TABLE transfers "
                    "ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(40)"
                )
            )
    if "commission_rules" in tables:
        with engine.begin() as conn:
            conn.execute(
                text(
                    "ALTER TABLE commission_rules "
                    "ADD COLUMN IF NOT EXISTS treasury_to_accredited_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"
                )
            )
            conn.execute(
                text(
                    "ALTER TABLE commission_rules "
                    "ADD COLUMN IF NOT EXISTS treasury_to_agent_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"
                )
            )
            conn.execute(
                text(
                    "ALTER TABLE commission_rules "
                    "ADD COLUMN IF NOT EXISTS treasury_collection_from_accredited_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"
                )
            )
            conn.execute(
                text(
                    "ALTER TABLE commission_rules "
                    "ADD COLUMN IF NOT EXISTS treasury_collection_from_agent_fee_percent NUMERIC(5, 2) NOT NULL DEFAULT 0"
                )
            )


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

    user_columns = {col["name"] for col in inspector.get_columns("users")}
    required_user_columns = {"full_name", "role", "city", "country", "password_hash"}
    if not required_user_columns.issubset(user_columns):
        return True

    transfer_columns = {col["name"] for col in inspector.get_columns("transfers")}
    required_transfer_columns = {
        "operation_type",
        "idempotency_key",
        "state",
        "source_currency",
        "destination_currency",
        "exchange_rate",
        "snapshot_at",
        "risk_score",
        "review_required",
        "reviewed_by_id",
        "reviewed_at",
        "review_note",
        "is_cross_country",
        "agent_profit_percent",
        "agent_profit_amount",
        "cashout_profit_percent",
        "cashout_profit_amount",
        "customer_name",
        "customer_phone",
    }
    if not required_transfer_columns.issubset(transfer_columns):
        return True

    commission_columns = {
        col["name"] for col in inspector.get_columns("commission_rules")
    }
    required_commission_columns = {
        "internal_fee_percent",
        "external_fee_percent",
        "treasury_to_accredited_fee_percent",
        "treasury_to_agent_fee_percent",
        "treasury_collection_from_accredited_fee_percent",
        "treasury_collection_from_agent_fee_percent",
        "agent_topup_profit_internal_percent",
        "agent_topup_profit_external_percent",
    }
    if not required_commission_columns.issubset(commission_columns):
        return True

    return False



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
        admin = db.query(User).filter(User.role == UserRole.admin).first()
        if not admin:
            admin = User(
                username=settings.BOOTSTRAP_ADMIN_USERNAME.strip().lower(),
                full_name=settings.BOOTSTRAP_ADMIN_FULL_NAME.strip(),
                role=UserRole.admin,
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
                balance=Decimal("0.00"),
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
                "treasury_collection_from_accredited": Decimal("0"),
                "treasury_collection_from_agent": Decimal("0"),
                "agent_profit_internal": Decimal("0"),
                "agent_profit_external": Decimal("0"),
            },
            UserRole.accredited: {
                "internal": Decimal("1.25"),
                "external": Decimal("1.75"),
                "treasury_to_accredited": Decimal("0"),
                "treasury_to_agent": Decimal("0"),
                "treasury_collection_from_accredited": Decimal("0"),
                "treasury_collection_from_agent": Decimal("0"),
                "agent_profit_internal": Decimal("0"),
                "agent_profit_external": Decimal("0"),
            },
            UserRole.agent: {
                "internal": Decimal("2.00"),
                "external": Decimal("2.50"),
                "treasury_to_accredited": Decimal("0"),
                "treasury_to_agent": Decimal("0"),
                "treasury_collection_from_accredited": Decimal("0"),
                "treasury_collection_from_agent": Decimal("0"),
                "agent_profit_internal": Decimal("0.75"),
                "agent_profit_external": Decimal("1.00"),
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
                        treasury_collection_from_accredited_fee_percent=fees[
                            "treasury_collection_from_accredited"
                        ],
                        treasury_collection_from_agent_fee_percent=fees[
                            "treasury_collection_from_agent"
                        ],
                        agent_topup_profit_internal_percent=fees[
                            "agent_profit_internal"
                        ],
                        agent_topup_profit_external_percent=fees[
                            "agent_profit_external"
                        ],
                        agent_topup_profit_percent=fees["agent_profit_internal"],
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


@app.on_event("startup")
def on_startup():
    bootstrap_system()


@app.get("/")
def root():
    return {
        "service": settings.COMPANY_NAME,
        "status": "running",
        "architecture": "feature-based",
        "notes": [
            "Self-registration is disabled",
            "Only admins can create users and cashboxes",
            "Treasury is managed by the admin and can fund or collect from the network",
            "Accredited users can manage multiple cashboxes and transfer between accredited cashboxes",
            "Agents operate as intermediaries with their own cashboxes and commissions",
            "Top-up and collection requests can wait for agent or admin approval",
            "Double-entry ledger posting is enabled for completed transfers",
        ],
    }


@app.api_route("/healthz", methods=["GET", "HEAD"])
def healthz():
    return {"status": "ok"}
