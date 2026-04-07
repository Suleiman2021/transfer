from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field

from app.features.risk.models import RiskAlertSeverity


class RiskProfileUpsertRequest(BaseModel):
    daily_amount_limit: Decimal | None = Field(default=None, ge=Decimal("0"))
    daily_transfer_limit: int | None = Field(default=None, ge=1, le=10000)
    single_transfer_soft_limit: Decimal | None = Field(default=None, ge=Decimal("0"))
    single_transfer_hard_limit: Decimal | None = Field(default=None, ge=Decimal("0"))
    requires_review_for_cross_city: bool | None = None
    is_active: bool | None = None


class RiskProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    daily_amount_limit: Decimal
    daily_transfer_limit: int
    single_transfer_soft_limit: Decimal
    single_transfer_hard_limit: Decimal
    requires_review_for_cross_city: bool
    is_active: bool
    updated_at: datetime

    class Config:
        from_attributes = True


class RiskAlertResponse(BaseModel):
    id: UUID
    transfer_id: UUID
    user_id: UUID
    code: str
    severity: RiskAlertSeverity
    message: str
    requires_review: bool
    resolved: bool
    created_at: datetime

    class Config:
        from_attributes = True
