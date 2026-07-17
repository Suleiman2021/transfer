import enum
import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, JSON, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class CashboxType(str, enum.Enum):
    treasury = "treasury"
    accredited = "accredited"
    agent = "agent"


class Cashbox(Base):
    __tablename__ = "cashboxes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False, unique=True)
    city = Column(String(100), nullable=False, index=True)
    country = Column(String(100), nullable=False, index=True)
    type = Column(Enum(CashboxType, name="cashboxtype"), nullable=False)

    manager_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)

    # Per-currency balances are the single source of truth. Each currency keeps
    # its own independent balance; there is no cross-currency conversion.
    currency_balances = Column(JSON, nullable=False, server_default='{}')
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    manager = relationship("User", back_populates="managed_cashboxes")
    shifts = relationship("CashboxShift", back_populates="cashbox")

    @property
    def manager_name(self) -> str | None:
        return self.manager.full_name if self.manager else None
