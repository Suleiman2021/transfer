import enum
import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Integer, Numeric, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class RiskAlertSeverity(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class RiskProfile(Base):
    __tablename__ = "risk_profiles"
    __table_args__ = (UniqueConstraint("user_id", name="uq_risk_profile_user"),)

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    daily_amount_limit = Column(Numeric(18, 2), nullable=False)
    daily_transfer_limit = Column(Integer, nullable=False)
    single_transfer_soft_limit = Column(Numeric(18, 2), nullable=False)
    single_transfer_hard_limit = Column(Numeric(18, 2), nullable=False)
    requires_review_for_cross_city = Column(Boolean, nullable=False, default=False)

    is_active = Column(Boolean, nullable=False, default=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    user = relationship("User", back_populates="risk_profile")


class RiskAlert(Base):
    __tablename__ = "risk_alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transfer_id = Column(UUID(as_uuid=True), ForeignKey("transfers.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    code = Column(String(80), nullable=False)
    severity = Column(Enum(RiskAlertSeverity, name="riskalertseverity"), nullable=False)
    message = Column(String(300), nullable=False)
    requires_review = Column(Boolean, nullable=False, default=False)

    resolved = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    transfer = relationship("Transfer", back_populates="risk_alerts")
    user = relationship("User", back_populates="risk_alerts")
