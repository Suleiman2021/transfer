import enum
import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, Numeric, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class LedgerAccountType(str, enum.Enum):
    asset = "asset"
    liability = "liability"
    equity = "equity"
    revenue = "revenue"
    expense = "expense"


class LedgerAccount(Base):
    __tablename__ = "ledger_accounts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String(80), nullable=False, unique=True, index=True)
    name = Column(String(120), nullable=False)
    account_type = Column(Enum(LedgerAccountType, name="ledgeraccounttype"), nullable=False)
    currency = Column(String(3), nullable=False, default="SYP")

    cashbox_id = Column(UUID(as_uuid=True), ForeignKey("cashboxes.id", ondelete="CASCADE"), nullable=True, unique=True, index=True)

    is_system = Column(Boolean, nullable=False, default=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    cashbox = relationship("Cashbox")


class LedgerEntry(Base):
    __tablename__ = "ledger_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transfer_id = Column(UUID(as_uuid=True), ForeignKey("transfers.id", ondelete="SET NULL"), nullable=True, unique=True, index=True)

    reference_type = Column(String(50), nullable=False, default="transfer")
    reference_id = Column(UUID(as_uuid=True), nullable=True, index=True)
    description = Column(Text, nullable=True)

    created_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    created_by = relationship("User")
    lines = relationship("LedgerLine", back_populates="entry", cascade="all, delete-orphan")


class LedgerLine(Base):
    __tablename__ = "ledger_lines"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entry_id = Column(UUID(as_uuid=True), ForeignKey("ledger_entries.id", ondelete="CASCADE"), nullable=False, index=True)
    account_id = Column(UUID(as_uuid=True), ForeignKey("ledger_accounts.id"), nullable=False, index=True)

    debit = Column(Numeric(18, 2), nullable=False, default=0)
    credit = Column(Numeric(18, 2), nullable=False, default=0)
    currency = Column(String(3), nullable=False, default="SYP")

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    entry = relationship("LedgerEntry", back_populates="lines")
    account = relationship("LedgerAccount")
