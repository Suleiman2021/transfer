from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.features.cashboxes.models import CashboxType


class CashboxCreateRequest(BaseModel):
    name: str = Field(min_length=3, max_length=100)
    city: str = Field(min_length=2, max_length=100)
    country: str = Field(min_length=2, max_length=100)
    type: CashboxType = CashboxType.accredited
    manager_user_id: UUID | None = None
    opening_balance: Decimal = Field(default=Decimal("0"), ge=Decimal("0"))


class CashboxUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=3, max_length=100)
    city: str | None = Field(default=None, min_length=2, max_length=100)
    country: str | None = Field(default=None, min_length=2, max_length=100)
    is_active: bool | None = None


class CashboxResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    city: str
    country: str
    type: CashboxType
    manager_user_id: UUID | None
    manager_name: str | None
    balance: Decimal
    is_active: bool
    created_at: datetime
