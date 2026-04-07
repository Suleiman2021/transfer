import enum
import uuid

from sqlalchemy import Boolean, Column, DateTime, Enum, ForeignKey, JSON, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base
from app.features.cashboxes.models import CashboxType
from app.features.users.models import UserRole


class TransferState(str, enum.Enum):
    initiated = "initiated"
    pending_review = "pending_review"
    approved = "approved"
    completed = "completed"
    rejected = "rejected"
    failed = "failed"


class TransferType(str, enum.Enum):
    network_transfer = "network_transfer"
    topup = "topup"
    collection = "collection"
    agent_funding = "agent_funding"
    agent_collection = "agent_collection"
    customer_cashout = "customer_cashout"


class Transfer(Base):
    __tablename__ = "transfers"
    __table_args__ = (
        UniqueConstraint("performed_by_id", "idempotency_key", name="uq_transfer_performer_idempotency"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    from_cashbox_id = Column(UUID(as_uuid=True), ForeignKey("cashboxes.id"), nullable=False, index=True)
    to_cashbox_id = Column(UUID(as_uuid=True), ForeignKey("cashboxes.id"), nullable=False, index=True)
    treasury_cashbox_id = Column(UUID(as_uuid=True), ForeignKey("cashboxes.id"), nullable=False)

    operation_type = Column(
        Enum(TransferType, name="transfertype"),
        nullable=False,
        default=TransferType.network_transfer,
        index=True,
    )

    idempotency_key = Column(String(120), nullable=True, index=True)
    state = Column(Enum(TransferState, name="transferstate"), nullable=False, default=TransferState.initiated, index=True)

    amount = Column(Numeric(18, 2), nullable=False)
    commission_role = Column(Enum(UserRole, name="userrole"), nullable=False)
    commission_percent = Column(Numeric(5, 2), nullable=False, default=0)
    commission_amount = Column(Numeric(18, 2), nullable=False, default=0)
    is_cross_country = Column(Boolean, nullable=False, default=False)
    agent_profit_percent = Column(Numeric(5, 2), nullable=False, default=0)
    agent_profit_amount = Column(Numeric(18, 2), nullable=False, default=0)
    cashout_profit_percent = Column(Numeric(5, 2), nullable=False, default=0)
    cashout_profit_amount = Column(Numeric(18, 2), nullable=False, default=0)
    net_amount = Column(Numeric(18, 2), nullable=False)
    customer_name = Column(String(120), nullable=True)
    customer_phone = Column(String(40), nullable=True)

    source_currency = Column(String(3), nullable=False, default="SYP")
    destination_currency = Column(String(3), nullable=False, default="SYP")
    exchange_rate = Column(Numeric(18, 6), nullable=False, default=1)
    snapshot_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    risk_score = Column(Numeric(5, 2), nullable=False, default=0)
    review_required = Column(Boolean, nullable=False, default=False)
    reviewed_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    review_note = Column(Text, nullable=True)

    performed_by_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    note = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    from_cashbox = relationship("Cashbox", foreign_keys=[from_cashbox_id])
    to_cashbox = relationship("Cashbox", foreign_keys=[to_cashbox_id])
    treasury_cashbox = relationship("Cashbox", foreign_keys=[treasury_cashbox_id])

    performed_by = relationship("User", back_populates="executed_transfers", foreign_keys=[performed_by_id])
    reviewed_by = relationship("User", back_populates="reviewed_transfers", foreign_keys=[reviewed_by_id])

    state_logs = relationship("TransferStateLog", back_populates="transfer", cascade="all, delete-orphan")
    risk_alerts = relationship("RiskAlert", back_populates="transfer", cascade="all, delete-orphan")

    @property
    def from_cashbox_name(self) -> str | None:
        return self.from_cashbox.name if self.from_cashbox else None

    @property
    def to_cashbox_name(self) -> str | None:
        return self.to_cashbox.name if self.to_cashbox else None

    @property
    def from_cashbox_type(self) -> CashboxType | None:
        return self.from_cashbox.type if self.from_cashbox else None

    @property
    def to_cashbox_type(self) -> CashboxType | None:
        return self.to_cashbox.type if self.to_cashbox else None


class TransferStateLog(Base):
    __tablename__ = "transfer_state_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transfer_id = Column(UUID(as_uuid=True), ForeignKey("transfers.id", ondelete="CASCADE"), nullable=False, index=True)
    state = Column(Enum(TransferState, name="transferstate"), nullable=False, index=True)

    actor_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True)
    reason = Column(Text, nullable=True)
    context = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    transfer = relationship("Transfer", back_populates="state_logs")
    actor = relationship("User")
