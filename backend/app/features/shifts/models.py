import enum
import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Numeric, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class ShiftStatus(str, enum.Enum):
    open = "open"
    closed = "closed"


class CashboxShift(Base):
    __tablename__ = "cashbox_shifts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cashbox_id = Column(UUID(as_uuid=True), ForeignKey("cashboxes.id", ondelete="CASCADE"), nullable=False, index=True)

    opened_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    closed_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)

    status = Column(Enum(ShiftStatus, name="shiftstatus"), nullable=False, default=ShiftStatus.open, index=True)

    opening_balance = Column(Numeric(18, 2), nullable=False)
    expected_closing_balance = Column(Numeric(18, 2), nullable=True)
    actual_closing_balance = Column(Numeric(18, 2), nullable=True)
    over_short_amount = Column(Numeric(18, 2), nullable=True)

    opening_note = Column(Text, nullable=True)
    closing_note = Column(Text, nullable=True)
    settlement_applied = Column(Boolean, nullable=False, default=True)

    opened_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    closed_at = Column(DateTime(timezone=True), nullable=True)

    cashbox = relationship("Cashbox", back_populates="shifts")
    opened_by = relationship("User", back_populates="opened_shifts", foreign_keys=[opened_by_id])
    closed_by = relationship("User", back_populates="closed_shifts", foreign_keys=[closed_by_id])
