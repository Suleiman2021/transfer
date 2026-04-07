from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.features.cashboxes.models import Cashbox, CashboxType
from app.features.cashboxes.schemas import CashboxCreateRequest
from app.features.ledger.service import ensure_cashbox_ledger_account
from app.features.transfers.models import Transfer, TransferState, TransferType
from app.features.users.models import User, UserRole


MANAGED_CASHBOX_TYPES = {CashboxType.accredited, CashboxType.agent}


def _validate_manager_assignment(db: Session, data: CashboxCreateRequest) -> User | None:
    if data.type == CashboxType.treasury:
        return None

    if data.manager_user_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="This cashbox type requires manager_user_id",
        )

    manager = db.query(User).filter(User.id == data.manager_user_id).first()
    if not manager:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Manager user not found")

    expected_role = UserRole.accredited if data.type == CashboxType.accredited else UserRole.agent
    if manager.role != expected_role:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Only {expected_role.value} users can manage this cashbox type",
        )

    return manager


def _build_cashbox_creation_transfer(
    db: Session,
    *,
    cashbox: Cashbox,
    opening_balance: Decimal,
    actor: User,
    manager: User | None,
) -> Transfer | None:
    if cashbox.type == CashboxType.treasury:
        return None

    treasury = (
        db.query(Cashbox)
        .filter(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
        .first()
    )
    if treasury is None:
        return None

    performer = manager or actor
    operation_type = (
        TransferType.agent_funding
        if cashbox.type == CashboxType.agent
        else TransferType.topup
    )

    return Transfer(
        from_cashbox_id=treasury.id,
        to_cashbox_id=cashbox.id,
        treasury_cashbox_id=treasury.id,
        operation_type=operation_type,
        idempotency_key=f"cashbox-create-{cashbox.id}",
        state=TransferState.completed,
        amount=opening_balance,
        commission_role=performer.role,
        commission_percent=Decimal("0"),
        commission_amount=Decimal("0"),
        is_cross_country=False,
        agent_profit_percent=Decimal("0"),
        agent_profit_amount=Decimal("0"),
        net_amount=opening_balance,
        source_currency="SYP",
        destination_currency="SYP",
        exchange_rate=Decimal("1"),
        risk_score=Decimal("0"),
        review_required=False,
        performed_by_id=performer.id,
        note=f"إضافة صندوق جديد برصيد افتتاحي {opening_balance:.2f}",
    )


def create_cashbox(db: Session, data: CashboxCreateRequest, actor: User) -> Cashbox:
    existing = db.query(Cashbox).filter(Cashbox.name == data.name.strip()).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cashbox name already exists")

    manager = _validate_manager_assignment(db, data)

    if data.type == CashboxType.treasury:
        treasury_exists = (
            db.query(Cashbox)
            .filter(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
            .first()
        )
        if treasury_exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Treasury cashbox already exists")

    opening_balance = Decimal(data.opening_balance)
    if data.type == CashboxType.treasury and opening_balance < Decimal("0"):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Treasury opening balance cannot be negative")

    cashbox = Cashbox(
        name=data.name.strip(),
        city=data.city.strip().lower(),
        country=data.country.strip().lower(),
        type=data.type,
        manager_user_id=manager.id if manager else None,
        balance=opening_balance,
        is_active=True,
    )

    db.add(cashbox)
    db.flush()

    ensure_cashbox_ledger_account(db, cashbox)

    creation_transfer = _build_cashbox_creation_transfer(
        db,
        cashbox=cashbox,
        opening_balance=opening_balance,
        actor=actor,
        manager=manager,
    )
    if creation_transfer is not None:
        db.add(creation_transfer)

    db.commit()
    db.refresh(cashbox)
    return cashbox



def list_cashboxes(db: Session, only_active: bool = True) -> list[Cashbox]:
    query = db.query(Cashbox).order_by(Cashbox.created_at.desc())
    if only_active:
        query = query.filter(Cashbox.is_active == True)
    return query.all()



def list_visible_cashboxes_for_user(db: Session, user: User) -> list[Cashbox]:
    active_cashboxes = list_cashboxes(db, only_active=True)

    if user.role == UserRole.admin:
        return active_cashboxes

    if user.role == UserRole.agent:
        visible = [
            cashbox
            for cashbox in active_cashboxes
            if cashbox.type == CashboxType.accredited
            or cashbox.type == CashboxType.treasury
            or (cashbox.type == CashboxType.agent and cashbox.manager_user_id == user.id)
        ]
        return visible

    visible = [
        cashbox
        for cashbox in active_cashboxes
        if cashbox.type == CashboxType.agent
        or cashbox.type == CashboxType.treasury
        or cashbox.type == CashboxType.accredited
    ]
    return visible



def get_treasury_cashbox(db: Session) -> Cashbox:
    treasury = (
        db.query(Cashbox)
        .filter(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
        .first()
    )
    if not treasury:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Treasury cashbox is not configured",
        )
    return treasury
