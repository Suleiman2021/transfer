import enum
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.features.cashboxes.models import CashboxType
from app.features.transfers.models import TransferState, TransferType
from app.features.users.models import UserRole


class RemittanceCreateRequest(BaseModel):
    from_cashbox_id: UUID
    to_cashbox_id: UUID
    amount: Decimal = Field(gt=Decimal("0"))

    sender_name: str = Field(min_length=1, max_length=120)
    sender_phone: str = Field(min_length=1, max_length=40)
    sender_country: str = Field(min_length=1, max_length=80)
    sender_city: str = Field(min_length=1, max_length=80)

    receiver_name: str = Field(min_length=1, max_length=120)
    receiver_phone: str = Field(min_length=1, max_length=40)
    receiver_country: str = Field(min_length=1, max_length=80)
    receiver_city: str = Field(min_length=1, max_length=80)

    note: str | None = Field(default=None, max_length=500)
    idempotency_key: str | None = Field(default=None, min_length=8, max_length=120)
    source_currency: str = Field(default="SYP", min_length=3, max_length=4)

    @field_validator("source_currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        normalized = value.strip().upper()
        if not (3 <= len(normalized) <= 4):
            raise ValueError("currency code must be 3 or 4 characters")
        return normalized

    @field_validator("idempotency_key")
    @classmethod
    def normalize_idempotency_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None


class TransferCreateRequest(BaseModel):
    from_cashbox_id: UUID
    to_cashbox_id: UUID
    amount: Decimal = Field(gt=Decimal("0"))
    operation_type: TransferType = TransferType.topup

    idempotency_key: str | None = Field(default=None, min_length=8, max_length=120)
    source_currency: str = Field(default="SYP", min_length=3, max_length=4)

    note: str | None = Field(default=None, max_length=500)
    commission_percent: Decimal | None = Field(
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

    @field_validator("source_currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        normalized = value.strip().upper()
        if not (3 <= len(normalized) <= 4):
            raise ValueError("currency code must be 3 or 4 characters (e.g. SYP, USD, USDT)")
        return normalized


class TransferReviewAction(str, enum.Enum):
    approve = "approve"
    reject = "reject"


class TransferReviewRequest(BaseModel):
    action: TransferReviewAction
    note: str | None = Field(default=None, max_length=500)
    approval_code: str | None = Field(default=None, min_length=4, max_length=12)

    @field_validator("approval_code")
    @classmethod
    def normalize_approval_code(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = "".join(ch for ch in value.strip() if ch.isdigit())
        return normalized or None


class TransferCancelRequest(BaseModel):
    note: str | None = Field(default=None, max_length=500)


class TransferResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

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
    net_amount: Decimal

    sender_name: str | None = None
    sender_phone: str | None = None
    sender_country: str | None = None
    sender_city: str | None = None
    receiver_name: str | None = None
    receiver_phone: str | None = None
    receiver_country: str | None = None
    receiver_city: str | None = None
    receiver_commission_percent: Decimal = Decimal("0")
    receiver_commission_amount: Decimal = Decimal("0")
    sender_commission_percent: Decimal = Decimal("0")
    sender_commission_amount: Decimal = Decimal("0")

    source_currency: str
    snapshot_at: datetime

    risk_score: Decimal
    review_required: bool
    approval_code_required: bool
    approval_code: str | None = None
    reviewed_by_id: UUID | None
    reviewed_at: datetime | None
    review_note: str | None

    performed_by_id: UUID
    note: str | None
    created_at: datetime


class DailyTransferReportRow(BaseModel):
    date: str
    transfers_count: int
    completed_count: int
    pending_count: int
    total_amount: Decimal
    total_commission: Decimal
    total_agent_profit: Decimal


class TransferStateLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    transfer_id: UUID
    state: TransferState
    actor_user_id: UUID | None
    reason: str | None
    context: dict | None
    created_at: datetime
