from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_roles
from app.features.ledger.schemas import LedgerAccountResponse, LedgerEntryResponse, TrialBalanceRowResponse
from app.features.ledger.service import get_entry, get_trial_balance_rows, list_accounts, list_entries
from app.features.users.models import User, UserRole


router = APIRouter(prefix="/ledger", tags=["Ledger"])


@router.get("/accounts", response_model=list[LedgerAccountResponse])
def read_ledger_accounts(
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return list_accounts(db)


@router.get("/entries", response_model=list[LedgerEntryResponse])
def read_ledger_entries(
    limit: int = Query(default=100, ge=1, le=300),
    transfer_id: UUID | None = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return list_entries(db, limit=limit, transfer_id=transfer_id)


@router.get("/entries/{entry_id}", response_model=LedgerEntryResponse)
def read_ledger_entry(
    entry_id: UUID,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return get_entry(db, entry_id)


@router.get("/trial-balance", response_model=list[TrialBalanceRowResponse])
def read_trial_balance(
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return get_trial_balance_rows(db)
