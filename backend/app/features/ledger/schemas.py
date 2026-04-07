from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel

from app.features.ledger.models import LedgerAccountType


class LedgerAccountResponse(BaseModel):
    id: UUID
    code: str
    name: str
    account_type: LedgerAccountType
    currency: str
    cashbox_id: UUID | None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class LedgerLineResponse(BaseModel):
    id: UUID
    account_id: UUID
    debit: Decimal
    credit: Decimal
    currency: str

    class Config:
        from_attributes = True


class LedgerEntryResponse(BaseModel):
    id: UUID
    transfer_id: UUID | None
    reference_type: str
    reference_id: UUID | None
    description: str | None
    created_by_id: UUID
    created_at: datetime
    lines: list[LedgerLineResponse]

    class Config:
        from_attributes = True


class TrialBalanceRowResponse(BaseModel):
    account_id: UUID
    account_code: str
    account_name: str
    account_type: LedgerAccountType
    debit: Decimal
    credit: Decimal
    balance: Decimal
