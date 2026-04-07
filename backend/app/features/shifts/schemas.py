from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field

from app.features.shifts.models import ShiftStatus


class ShiftOpenRequest(BaseModel):
    cashbox_id: UUID
    opening_note: str | None = Field(default=None, max_length=300)


class ShiftCloseRequest(BaseModel):
    shift_id: UUID
    actual_closing_balance: Decimal = Field(ge=Decimal("0"))
    closing_note: str | None = Field(default=None, max_length=300)
    settlement_applied: bool = True


class CashboxShiftResponse(BaseModel):
    id: UUID
    cashbox_id: UUID
    opened_by_id: UUID
    closed_by_id: UUID | None
    status: ShiftStatus

    opening_balance: Decimal
    expected_closing_balance: Decimal | None
    actual_closing_balance: Decimal | None
    over_short_amount: Decimal | None

    opening_note: str | None
    closing_note: str | None
    settlement_applied: bool

    opened_at: datetime
    closed_at: datetime | None

    class Config:
        from_attributes = True
