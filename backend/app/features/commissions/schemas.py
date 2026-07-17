from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

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
    treasury_to_agent_internal_fee_percent: Decimal | None = Field(
        default=None, ge=Decimal("0"), le=Decimal("100")
    )
    treasury_to_agent_external_fee_percent: Decimal | None = Field(
        default=None, ge=Decimal("0"), le=Decimal("100")
    )
    treasury_to_accredited_internal_fee_percent: Decimal | None = Field(
        default=None, ge=Decimal("0"), le=Decimal("100")
    )
    treasury_to_accredited_external_fee_percent: Decimal | None = Field(
        default=None, ge=Decimal("0"), le=Decimal("100")
    )
    remittance_treasury_percent: Decimal | None = Field(
        default=None, ge=Decimal("0"), le=Decimal("100")
    )
    remittance_sender_percent: Decimal | None = Field(
        default=None, ge=Decimal("0"), le=Decimal("100")
    )
    remittance_receiver_percent: Decimal | None = Field(
        default=None, ge=Decimal("0"), le=Decimal("100")
    )

    @model_validator(mode="after")
    def validate_any_value_provided(self):
        values = [
            self.fee_percent,
            self.internal_fee_percent,
            self.external_fee_percent,
            self.treasury_to_accredited_fee_percent,
            self.treasury_to_agent_fee_percent,
            self.treasury_to_agent_internal_fee_percent,
            self.treasury_to_agent_external_fee_percent,
            self.treasury_to_accredited_internal_fee_percent,
            self.treasury_to_accredited_external_fee_percent,
            self.remittance_treasury_percent,
            self.remittance_sender_percent,
            self.remittance_receiver_percent,
        ]
        if all(v is None for v in values):
            raise ValueError("At least one commission value must be provided")
        return self


class CommissionRuleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    role: UserRole
    internal_fee_percent: Decimal
    external_fee_percent: Decimal
    treasury_to_accredited_fee_percent: Decimal
    treasury_to_agent_fee_percent: Decimal
    treasury_to_agent_internal_fee_percent: Decimal
    treasury_to_agent_external_fee_percent: Decimal
    treasury_to_accredited_internal_fee_percent: Decimal
    treasury_to_accredited_external_fee_percent: Decimal
    remittance_treasury_percent: Decimal
    remittance_sender_percent: Decimal
    remittance_receiver_percent: Decimal
    is_active: bool
    updated_at: datetime | None
