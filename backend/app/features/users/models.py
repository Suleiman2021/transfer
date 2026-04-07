import enum
import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class UserRole(str, enum.Enum):
    admin = "admin"
    accredited = "accredited"
    agent = "agent"


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), unique=True, nullable=False, index=True)
    full_name = Column(String(120), nullable=False)
    role = Column(Enum(UserRole, name="userrole"), nullable=False)
    city = Column(String(100), nullable=False)
    country = Column(String(100), nullable=False, index=True)

    password_hash = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    created_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    created_by = relationship("User", remote_side=[id], backref="created_users")
    managed_cashboxes = relationship("Cashbox", back_populates="manager")

    executed_transfers = relationship(
        "Transfer",
        back_populates="performed_by",
        foreign_keys="Transfer.performed_by_id",
    )
    reviewed_transfers = relationship(
        "Transfer",
        back_populates="reviewed_by",
        foreign_keys="Transfer.reviewed_by_id",
    )

    risk_profile = relationship("RiskProfile", back_populates="user", uselist=False)
    risk_alerts = relationship("RiskAlert", back_populates="user")

    opened_shifts = relationship(
        "CashboxShift",
        back_populates="opened_by",
        foreign_keys="CashboxShift.opened_by_id",
    )
    closed_shifts = relationship(
        "CashboxShift",
        back_populates="closed_by",
        foreign_keys="CashboxShift.closed_by_id",
    )
