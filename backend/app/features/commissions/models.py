import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, Numeric
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.core.database import Base
from app.features.users.models import UserRole


class CommissionRule(Base):
    __tablename__ = "commission_rules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    role = Column(Enum(UserRole, name="userrole"), unique=True, nullable=False)
    internal_fee_percent = Column(Numeric(5, 2), nullable=False, default=0)
    external_fee_percent = Column(Numeric(5, 2), nullable=False, default=0)
    treasury_to_accredited_fee_percent = Column(Numeric(5, 2), nullable=False, default=0)
    treasury_to_agent_fee_percent = Column(Numeric(5, 2), nullable=False, default=0)
    treasury_collection_from_accredited_fee_percent = Column(Numeric(5, 2), nullable=False, default=0)
    treasury_collection_from_agent_fee_percent = Column(Numeric(5, 2), nullable=False, default=0)
    agent_topup_profit_internal_percent = Column(Numeric(5, 2), nullable=False, default=0)
    agent_topup_profit_external_percent = Column(Numeric(5, 2), nullable=False, default=0)
    agent_topup_profit_percent = Column(Numeric(5, 2), nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
