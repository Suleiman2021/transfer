from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.features.users.models import UserRole


class CommissionRuleUpsertRequest(BaseModel):
    role: UserRole
    # Legacy field kept for backward compatibility. If set, it is applied to
    # both internal and external fee unless the explicit values are provided.
    fee_percent: Decimal | None = Field(default=None, ge=Decimal("0"), le=Decimal("100"))
    internal_fee_percent: Decimal | None = Field(default=None, ge=Decimal("0"), le=Decimal("100"))
    external_fee_percent: Decimal | None = Field(default=None, ge=Decimal("0"), le=Decimal("100"))
    treasury_to_accredited_fee_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    treasury_to_agent_fee_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    treasury_collection_from_accredited_fee_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    treasury_collection_from_agent_fee_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    agent_topup_profit_internal_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    agent_topup_profit_external_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )
    agent_topup_profit_percent: Decimal | None = Field(
        default=None,
        ge=Decimal("0"),
        le=Decimal("100"),
    )

    @model_validator(mode="after")
    def validate_any_value_provided(self):
        if (
            self.fee_percent is None
            and self.internal_fee_percent is None
            and self.external_fee_percent is None
            and self.treasury_to_accredited_fee_percent is None
            and self.treasury_to_agent_fee_percent is None
            and self.treasury_collection_from_accredited_fee_percent is None
            and self.treasury_collection_from_agent_fee_percent is None
            and self.agent_topup_profit_internal_percent is None
            and self.agent_topup_profit_external_percent is None
            and self.agent_topup_profit_percent is None
        ):
            raise ValueError("At least one commission value must be provided")
        return self


class CommissionRuleResponse(BaseModel):
    id: UUID
    role: UserRole
    internal_fee_percent: Decimal
    external_fee_percent: Decimal
    treasury_to_accredited_fee_percent: Decimal
    treasury_to_agent_fee_percent: Decimal
    treasury_collection_from_accredited_fee_percent: Decimal
    treasury_collection_from_agent_fee_percent: Decimal
    agent_topup_profit_internal_percent: Decimal
    agent_topup_profit_external_percent: Decimal
    agent_topup_profit_percent: Decimal
    is_active: bool
    updated_at: datetime | None

    class Config:
        from_attributes = True
