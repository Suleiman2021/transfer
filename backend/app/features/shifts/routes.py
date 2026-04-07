from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.features.shifts.schemas import CashboxShiftResponse, ShiftCloseRequest, ShiftOpenRequest
from app.features.shifts.service import close_shift, get_current_shift, list_shift_history, open_shift
from app.features.users.models import User


router = APIRouter(prefix="/shifts", tags=["Shifts"])


@router.post("/open", response_model=CashboxShiftResponse)
def open_cashbox_shift(
    payload: ShiftOpenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return open_shift(db, payload, current_user)


@router.post("/close", response_model=CashboxShiftResponse)
def close_cashbox_shift(
    payload: ShiftCloseRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return close_shift(db, payload, current_user)


@router.get("/cashbox/{cashbox_id}/current", response_model=CashboxShiftResponse | None)
def read_current_shift(
    cashbox_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_current_shift(db, cashbox_id, current_user)


@router.get("/cashbox/{cashbox_id}/history", response_model=list[CashboxShiftResponse])
def read_shift_history(
    cashbox_id: UUID,
    limit: int = Query(default=100, ge=1, le=300),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_shift_history(db, cashbox_id, current_user, limit)
