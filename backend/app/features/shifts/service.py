from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.features.cashboxes.models import Cashbox, CashboxType
from app.features.shifts.models import CashboxShift, ShiftStatus
from app.features.shifts.schemas import ShiftCloseRequest, ShiftOpenRequest
from app.features.users.models import User, UserRole


MONEY_QUANT = Decimal("0.01")



def _q(value: Decimal) -> Decimal:
    return Decimal(value).quantize(MONEY_QUANT, rounding=ROUND_HALF_UP)



def _get_cashbox_or_404(db: Session, cashbox_id: UUID) -> Cashbox:
    cashbox = db.query(Cashbox).filter(Cashbox.id == cashbox_id).first()
    if not cashbox:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")
    return cashbox



def _validate_shift_access(cashbox: Cashbox, user: User) -> None:
    if user.role == UserRole.admin:
        return

    if cashbox.type == CashboxType.treasury:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admin can manage treasury shifts",
        )

    if cashbox.manager_user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can manage shifts only for your own managed cashboxes",
        )

    if user.role == UserRole.accredited and cashbox.type != CashboxType.accredited:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accredited user can manage accredited cashboxes only")

    if user.role == UserRole.agent and cashbox.type != CashboxType.agent:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Agent can manage agent cashboxes only")



def open_shift(db: Session, payload: ShiftOpenRequest, user: User) -> CashboxShift:
    cashbox = _get_cashbox_or_404(db, payload.cashbox_id)
    _validate_shift_access(cashbox, user)

    if not cashbox.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cashbox must be active")

    existing_open = (
        db.query(CashboxShift)
        .filter(CashboxShift.cashbox_id == cashbox.id, CashboxShift.status == ShiftStatus.open)
        .first()
    )
    if existing_open:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="There is already an open shift for this cashbox")

    shift = CashboxShift(
        cashbox_id=cashbox.id,
        opened_by_id=user.id,
        status=ShiftStatus.open,
        opening_balance=_q(cashbox.balance),
        opening_note=payload.opening_note.strip() if payload.opening_note else None,
    )

    db.add(shift)
    db.commit()
    db.refresh(shift)
    return shift



def close_shift(db: Session, payload: ShiftCloseRequest, user: User) -> CashboxShift:
    shift = db.query(CashboxShift).filter(CashboxShift.id == payload.shift_id).with_for_update().first()
    if not shift:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shift not found")

    if shift.status != ShiftStatus.open:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Shift is already closed")

    cashbox = _get_cashbox_or_404(db, shift.cashbox_id)
    _validate_shift_access(cashbox, user)

    expected = _q(cashbox.balance)
    actual = _q(payload.actual_closing_balance)
    over_short = _q(actual - expected)

    shift.status = ShiftStatus.closed
    shift.closed_by_id = user.id
    shift.closed_at = datetime.now(timezone.utc)
    shift.expected_closing_balance = expected
    shift.actual_closing_balance = actual
    shift.over_short_amount = over_short
    shift.closing_note = payload.closing_note.strip() if payload.closing_note else None
    shift.settlement_applied = payload.settlement_applied

    if payload.settlement_applied:
        cashbox.balance = actual

    db.commit()
    db.refresh(shift)
    return shift



def get_current_shift(db: Session, cashbox_id: UUID, user: User) -> CashboxShift | None:
    cashbox = _get_cashbox_or_404(db, cashbox_id)
    _validate_shift_access(cashbox, user)

    return (
        db.query(CashboxShift)
        .filter(CashboxShift.cashbox_id == cashbox.id, CashboxShift.status == ShiftStatus.open)
        .order_by(CashboxShift.opened_at.desc())
        .first()
    )



def list_shift_history(db: Session, cashbox_id: UUID, user: User, limit: int = 100) -> list[CashboxShift]:
    cashbox = _get_cashbox_or_404(db, cashbox_id)
    _validate_shift_access(cashbox, user)

    return (
        db.query(CashboxShift)
        .filter(CashboxShift.cashbox_id == cashbox.id)
        .order_by(CashboxShift.opened_at.desc())
        .limit(min(limit, 300))
        .all()
    )
