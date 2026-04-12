import enum
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.features.cashboxes.models import CashboxType
from app.features.transfers.models import TransferState, TransferType
from app.features.users.models import UserRole


class TransferCreateRequest(BaseModel):
    from_cashbox_id: UUID
    to_cashbox_id: UUID
    amount: Decimal = Field(gt=Decimal("0"))
    operation_type: TransferType = TransferType.network_transfer

    idempotency_key: str | None = Field(default=None, min_length=8, max_length=120)
    source_currency: str = Field(default="SYP", min_length=3, max_length=3)
    destination_currency: str = Field(default="SYP", min_length=3, max_length=3)
    exchange_rate: Decimal = Field(default=Decimal("1"), gt=Decimal("0"))

    note: str | None = Field(default=None, max_length=500)
    customer_name: str | None = Field(default=None, max_length=120)
    customer_phone: str | None = Field(default=None, max_length=40)
    commission_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    cashout_profit_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )

    @field_validator("idempotency_key")
    @classmethod
    def normalize_idempotency_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @field_validator("source_currency", "destination_currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        normalized = value.strip().upper()
        if len(normalized) != 3:
            raise ValueError("currency must be 3 letters")
        return normalized


class TransferReviewAction(str, enum.Enum):
    approve = "approve"
    reject = "reject"


class TransferReviewRequest(BaseModel):
    action: TransferReviewAction
    note: str | None = Field(default=None, max_length=500)


class TransferCancelRequest(BaseModel):
    note: str | None = Field(default=None, max_length=500)


class TransferResponse(BaseModel):
    id: UUID
    from_cashbox_id: UUID
    to_cashbox_id: UUID
    treasury_cashbox_id: UUID

    operation_type: TransferType
    idempotency_key: str | None
    state: TransferState

    from_cashbox_name: str | None
    to_cashbox_name: str | None
    from_cashbox_type: CashboxType | None
    to_cashbox_type: CashboxType | None

    amount: Decimal
    commission_role: UserRole
    commission_percent: Decimal
    commission_amount: Decimal
    is_cross_country: bool
    agent_profit_percent: Decimal
    agent_profit_amount: Decimal
    cashout_profit_percent: Decimal
    cashout_profit_amount: Decimal
    net_amount: Decimal
    customer_name: str | None
    customer_phone: str | None

    source_currency: str
    destination_currency: str
    exchange_rate: Decimal
    snapshot_at: datetime

    risk_score: Decimal
    review_required: bool
    reviewed_by_id: UUID | None
    reviewed_at: datetime | None
    review_note: str | None

    performed_by_id: UUID
    note: str | None
    created_at: datetime

    class Config:
        from_attributes = True


class DailyTransferReportRow(BaseModel):
    date: str
    transfers_count: int
    completed_count: int
    pending_count: int
    total_amount: Decimal
    total_commission: Decimal
    total_agent_profit: Decimal
    total_cashout_profit: Decimal


class TransferStateLogResponse(BaseModel):
    id: UUID
    transfer_id: UUID
    state: TransferState
    actor_user_id: UUID | None
    reason: str | None
    context: dict | None
    created_at: datetime

    class Config:
        from_attributes = True
