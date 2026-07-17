from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.cashboxes.models import Cashbox, CashboxType
from app.features.cashboxes.schemas import CashboxCreateRequest, CashboxUpdateRequest
from app.features.ledger.service import ensure_cashbox_ledger_account, post_transfer_ledger_entry
from app.features.transfers.models import Transfer, TransferState, TransferType
from app.features.users.models import User, UserRole, is_admin_role


MANAGED_CASHBOX_TYPES = {CashboxType.accredited, CashboxType.agent}

_MONEY_QUANT = Decimal("0.01")


def _q(value: Decimal) -> Decimal:
    return Decimal(value).quantize(_MONEY_QUANT, rounding=ROUND_HALF_UP)


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


def _adjust_currency_balance(cashbox: Cashbox, currency: str, delta: Decimal) -> None:
    balances = dict(cashbox.currency_balances or {})
    current = Decimal(str(balances.get(currency, "0")))
    updated = _q(current + delta)
    if updated == Decimal("0"):
        balances.pop(currency, None)
    else:
        balances[currency] = str(updated)
    cashbox.currency_balances = balances


def _apply_opening_balance_from_treasury(
    db: Session,
    *,
    cashbox: Cashbox,
    opening_balance: Decimal,
    opening_currency: str,
    actor: User,
    manager: User | None,
) -> None:
    """Deduct opening_balance from treasury, credit new cashbox, and post a ledger entry."""
    treasury_stmt = (
        select(Cashbox)
        .where(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
        .with_for_update()
    )
    treasury = db.execute(treasury_stmt).scalar_one_or_none()
    if not treasury:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Treasury cashbox is not configured",
        )

    currency = (opening_currency or "SYP").upper()
    treasury_balance = _q(Decimal(str((treasury.currency_balances or {}).get(currency, "0"))))
    if treasury_balance < opening_balance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Treasury {currency} balance is insufficient for the opening balance "
                f"(available: {treasury_balance:.2f})"
            ),
        )

    _adjust_currency_balance(treasury, currency, -opening_balance)
    _adjust_currency_balance(cashbox, currency, opening_balance)

    performer = manager or actor
    operation_type = (
        TransferType.agent_funding
        if cashbox.type == CashboxType.agent
        else TransferType.topup
    )

    creation_transfer = Transfer(
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
        source_currency=currency,
        risk_score=Decimal("0"),
        review_required=False,
        performed_by_id=performer.id,
        note=f"إضافة صندوق جديد برصيد افتتاحي {opening_balance:.2f} {currency}",
    )
    db.add(creation_transfer)
    db.flush()
    ensure_cashbox_ledger_account(db, treasury)
    post_transfer_ledger_entry(db, creation_transfer, actor.id)


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

    opening_balance = _q(Decimal(data.opening_balance))
    opening_currency = (data.opening_currency or "SYP").upper()
    if data.type == CashboxType.treasury and opening_balance < Decimal("0"):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Treasury opening balance cannot be negative")

    # Treasury opening balance is a direct equity injection; non-treasury cashboxes
    # start empty and are funded via a real transfer from treasury (see below).
    initial_currency_balances = (
        {opening_currency: str(opening_balance)}
        if data.type == CashboxType.treasury and opening_balance > Decimal("0")
        else {}
    )

    cashbox = Cashbox(
        name=data.name.strip(),
        city=data.city.strip().lower(),
        country=data.country.strip().lower(),
        type=data.type,
        manager_user_id=manager.id if manager else None,
        currency_balances=initial_currency_balances,
        is_active=True,
    )

    db.add(cashbox)
    db.flush()

    ensure_cashbox_ledger_account(db, cashbox)

    if data.type != CashboxType.treasury and opening_balance > Decimal("0"):
        _apply_opening_balance_from_treasury(
            db,
            cashbox=cashbox,
            opening_balance=opening_balance,
            opening_currency=opening_currency,
            actor=actor,
            manager=manager,
        )

    db.commit()
    db.refresh(cashbox)
    return cashbox


def list_cashboxes(db: Session, only_active: bool = True) -> list[Cashbox]:
    query = db.query(Cashbox).order_by(Cashbox.created_at.desc())
    if only_active:
        query = query.filter(Cashbox.is_active == True)
    return query.all()


def update_cashbox_by_admin(db: Session, cashbox_id, data: CashboxUpdateRequest, actor: User) -> Cashbox:
    cashbox = db.query(Cashbox).filter(Cashbox.id == cashbox_id).first()
    if not cashbox:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if data.name is not None:
        name = data.name.strip()
        exists = db.query(Cashbox).filter(Cashbox.name == name, Cashbox.id != cashbox.id).first()
        if exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cashbox name already exists")
        cashbox.name = name
    if data.city is not None:
        cashbox.city = data.city.strip().lower()
    if data.country is not None:
        cashbox.country = data.country.strip().lower()
    if data.is_active is not None:
        cashbox.is_active = data.is_active

    db.commit()
    db.refresh(cashbox)
    return cashbox


def list_visible_cashboxes_for_user(db: Session, user: User) -> list[Cashbox]:
    active_cashboxes = list_cashboxes(db, only_active=True)

    if is_admin_role(user.role):
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
