from datetime import date
from decimal import Decimal

from pydantic import BaseModel

from app.features.cashboxes.schemas import CashboxResponse
from app.features.transfers.schemas import DailyTransferReportRow, TransferResponse
from app.features.users.schemas import UserResponse


class UserReportSummaryResponse(BaseModel):
    cashboxes_count: int
    total_balance: Decimal
    transfers_count: int
    completed_count: int
    pending_count: int
    rejected_count: int
    total_amount: Decimal
    total_commission: Decimal
    total_agent_profit: Decimal
    total_cashout_profit: Decimal
    from_date: date | None
    to_date: date | None


class UserReportResponse(BaseModel):
    user: UserResponse
    cashboxes: list[CashboxResponse]
    transfers: list[TransferResponse]
    daily_rows: list[DailyTransferReportRow]
    summary: UserReportSummaryResponse
