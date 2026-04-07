from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import case, func, or_
from sqlalchemy.orm import Session

from app.features.cashboxes.models import Cashbox
from app.features.transfers.models import Transfer, TransferState, TransferType
from app.features.users.models import User


MONEY_QUANT = Decimal("0.01")


def _q_money(value: Decimal) -> Decimal:
    return Decimal(value).quantize(MONEY_QUANT, rounding=ROUND_HALF_UP)


def _start_of_day(day: date) -> datetime:
    return datetime.combine(day, time.min).replace(tzinfo=timezone.utc)


def _end_of_day_exclusive(day: date) -> datetime:
    return _start_of_day(day) + timedelta(days=1)


def _build_user_transfers_query(
    db: Session,
    *,
    user_id: UUID,
    cashbox_ids: list[UUID],
):
    conditions = [Transfer.performed_by_id == user_id]
    if cashbox_ids:
        conditions.extend(
            [
                Transfer.from_cashbox_id.in_(cashbox_ids),
                Transfer.to_cashbox_id.in_(cashbox_ids),
            ]
        )
    return db.query(Transfer).filter(or_(*conditions))


def _apply_date_filters(
    query,
    *,
    from_date: date | None,
    to_date: date | None,
):
    if from_date:
        query = query.filter(Transfer.created_at >= _start_of_day(from_date))
    if to_date:
        query = query.filter(Transfer.created_at < _end_of_day_exclusive(to_date))
    return query


def get_user_report(
    db: Session,
    user_id: UUID,
    *,
    from_date: date | None = None,
    to_date: date | None = None,
    limit: int = 200,
    limit_days: int = 45,
) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    cashboxes = (
        db.query(Cashbox)
        .filter(Cashbox.manager_user_id == user.id)
        .order_by(Cashbox.created_at.desc())
        .all()
    )
    cashbox_ids = [cashbox.id for cashbox in cashboxes]
    total_balance = _q_money(sum((Decimal(cashbox.balance) for cashbox in cashboxes), Decimal("0")))

    scoped = _build_user_transfers_query(db, user_id=user.id, cashbox_ids=cashbox_ids)
    scoped = _apply_date_filters(scoped, from_date=from_date, to_date=to_date)

    safe_limit = max(1, min(limit, 300))
    transfers = scoped.order_by(Transfer.created_at.desc()).limit(safe_limit).all()

    totals = scoped.with_entities(
        func.count(Transfer.id).label("transfers_count"),
        func.sum(case((Transfer.state == TransferState.completed, 1), else_=0)).label("completed_count"),
        func.sum(case((Transfer.state == TransferState.pending_review, 1), else_=0)).label("pending_count"),
        func.sum(case((Transfer.state == TransferState.rejected, 1), else_=0)).label("rejected_count"),
        func.coalesce(
            func.sum(
                case(
                    (Transfer.state == TransferState.completed, Transfer.amount),
                    else_=0,
                )
            ),
            0,
        ).label("total_amount"),
        func.coalesce(
            func.sum(
                case(
                    (
                        Transfer.state == TransferState.completed,
                        Transfer.commission_amount,
                    ),
                    else_=0,
                )
            ),
            0,
        ).label("total_commission"),
        func.coalesce(
            func.sum(
                case(
                    (
                        Transfer.state == TransferState.completed,
                        Transfer.agent_profit_amount,
                    ),
                    else_=0,
                )
            ),
            0,
        ).label("total_agent_profit"),
        func.coalesce(
            func.sum(
                case(
                    (
                        (Transfer.state == TransferState.completed)
                        & (Transfer.operation_type == TransferType.customer_cashout),
                        Transfer.cashout_profit_amount,
                    ),
                    else_=0,
                )
            ),
            0,
        ).label("total_cashout_profit"),
    ).first()

    day_key = func.date(Transfer.created_at)
    safe_limit_days = max(1, min(limit_days, 180))
    grouped = (
        scoped.with_entities(
            day_key.label("day"),
            func.count(Transfer.id).label("transfers_count"),
            func.sum(case((Transfer.state == TransferState.completed, 1), else_=0)).label("completed_count"),
            func.sum(case((Transfer.state == TransferState.pending_review, 1), else_=0)).label("pending_count"),
            func.coalesce(
                func.sum(
                    case(
                        (Transfer.state == TransferState.completed, Transfer.amount),
                        else_=0,
                    )
                ),
                0,
            ).label("total_amount"),
            func.coalesce(
                func.sum(
                    case(
                        (
                            Transfer.state == TransferState.completed,
                            Transfer.commission_amount,
                        ),
                        else_=0,
                    )
                ),
                0,
            ).label("total_commission"),
            func.coalesce(
                func.sum(
                    case(
                        (
                            Transfer.state == TransferState.completed,
                            Transfer.agent_profit_amount,
                        ),
                        else_=0,
                    )
                ),
                0,
            ).label("total_agent_profit"),
            func.coalesce(
                func.sum(
                    case(
                        (
                            (Transfer.state == TransferState.completed)
                            & (Transfer.operation_type == TransferType.customer_cashout),
                            Transfer.cashout_profit_amount,
                        ),
                        else_=0,
                    )
                ),
                0,
            ).label("total_cashout_profit"),
        )
        .group_by(day_key)
        .order_by(day_key.desc())
        .limit(safe_limit_days)
        .all()
    )

    daily_rows = []
    for row in grouped:
        day_value = row.day.isoformat() if hasattr(row.day, "isoformat") else str(row.day)
        daily_rows.append(
            {
                "date": day_value,
                "transfers_count": int(row.transfers_count or 0),
                "completed_count": int(row.completed_count or 0),
                "pending_count": int(row.pending_count or 0),
                "total_amount": _q_money(Decimal(row.total_amount or 0)),
                "total_commission": _q_money(Decimal(row.total_commission or 0)),
                "total_agent_profit": _q_money(Decimal(row.total_agent_profit or 0)),
                "total_cashout_profit": _q_money(Decimal(row.total_cashout_profit or 0)),
            }
        )

    return {
        "user": user,
        "cashboxes": cashboxes,
        "transfers": transfers,
        "daily_rows": daily_rows,
        "summary": {
            "cashboxes_count": len(cashboxes),
            "total_balance": total_balance,
            "transfers_count": int(totals.transfers_count or 0),
            "completed_count": int(totals.completed_count or 0),
            "pending_count": int(totals.pending_count or 0),
            "rejected_count": int(totals.rejected_count or 0),
            "total_amount": _q_money(Decimal(totals.total_amount or 0)),
            "total_commission": _q_money(Decimal(totals.total_commission or 0)),
            "total_agent_profit": _q_money(Decimal(totals.total_agent_profit or 0)),
            "total_cashout_profit": _q_money(Decimal(totals.total_cashout_profit or 0)),
            "from_date": from_date,
            "to_date": to_date,
        },
    }
