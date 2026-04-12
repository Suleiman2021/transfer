from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_current_user_allow_inactive
from app.features.transfers.schemas import (
    TransferCancelRequest,
    DailyTransferReportRow,
    TransferCreateRequest,
    TransferResponse,
    TransferReviewRequest,
    TransferStateLogResponse,
)
from app.features.transfers.service import (
    cancel_transfer,
    create_transfer,
    daily_transfer_report,
    list_pending_transfers,
    list_transfer_state_logs,
    list_transfers,
    review_transfer,
)
from app.features.users.models import User


router = APIRouter(prefix="/transfers", tags=["Transfers"])


@router.post("/", response_model=TransferResponse)
def make_transfer(
    payload: TransferCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_transfer(db, payload, current_user)


@router.get("/", response_model=list[TransferResponse])
def read_transfers(
    limit: int = Query(default=100, ge=1, le=200),
    from_date: date | None = Query(default=None),
    to_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_allow_inactive),
):
    return list_transfers(
        db,
        current_user,
        limit=limit,
        from_date=from_date,
        to_date=to_date,
    )


@router.get("/pending", response_model=list[TransferResponse])
def read_pending_transfers(
    limit: int = Query(default=100, ge=1, le=200),
    from_date: date | None = Query(default=None),
    to_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_pending_transfers(
        db,
        current_user,
        limit=limit,
        from_date=from_date,
        to_date=to_date,
    )


@router.get("/reports/daily", response_model=list[DailyTransferReportRow])
def read_daily_report(
    from_date: date | None = Query(default=None),
    to_date: date | None = Query(default=None),
    limit_days: int = Query(default=30, ge=1, le=180),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_allow_inactive),
):
    return daily_transfer_report(
        db,
        current_user,
        from_date=from_date,
        to_date=to_date,
        limit_days=limit_days,
    )


@router.post("/{transfer_id}/review", response_model=TransferResponse)
def review_pending_transfer(
    transfer_id: UUID,
    payload: TransferReviewRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return review_transfer(db, transfer_id, payload, current_user)


@router.post("/{transfer_id}/cancel", response_model=TransferResponse)
def cancel_completed_transfer(
    transfer_id: UUID,
    payload: TransferCancelRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return cancel_transfer(db, transfer_id, payload, current_user)


@router.get("/{transfer_id}/states", response_model=list[TransferStateLogResponse])
def read_transfer_states(
    transfer_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_allow_inactive),
):
    return list_transfer_state_logs(db, transfer_id, current_user)
