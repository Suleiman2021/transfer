from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.features.cashboxes.models import Cashbox
from app.features.ledger.models import LedgerAccount, LedgerAccountType, LedgerEntry, LedgerLine
from app.features.transfers.models import Transfer


MONEY_QUANT = Decimal("0.01")
COMMISSION_REVENUE_CODE = "REV_COMMISSION"


@dataclass
class LedgerLineInput:
    account_id: UUID
    debit: Decimal = Decimal("0")
    credit: Decimal = Decimal("0")
    currency: str = "SYP"


def _q(value: Decimal) -> Decimal:
    return Decimal(value).quantize(MONEY_QUANT, rounding=ROUND_HALF_UP)


def _cashbox_account_code(cashbox_id: UUID) -> str:
    return f"CASHBOX:{cashbox_id}"


def ensure_default_ledger_accounts(db: Session) -> None:
    account = db.query(LedgerAccount).filter(LedgerAccount.code == COMMISSION_REVENUE_CODE).first()
    if account:
        return

    db.add(
        LedgerAccount(
            code=COMMISSION_REVENUE_CODE,
            name="Commission Revenue",
            account_type=LedgerAccountType.revenue,
            currency="SYP",
            cashbox_id=None,
            is_system=True,
            is_active=True,
        )
    )


def ensure_cashbox_ledger_account(db: Session, cashbox: Cashbox) -> LedgerAccount:
    existing = db.query(LedgerAccount).filter(LedgerAccount.cashbox_id == cashbox.id).first()
    if existing:
        if existing.code != _cashbox_account_code(cashbox.id):
            existing.code = _cashbox_account_code(cashbox.id)
        if existing.name != f"Cashbox {cashbox.name}":
            existing.name = f"Cashbox {cashbox.name}"
        existing.is_active = bool(cashbox.is_active)
        return existing

    account = LedgerAccount(
        code=_cashbox_account_code(cashbox.id),
        name=f"Cashbox {cashbox.name}",
        account_type=LedgerAccountType.asset,
        currency="SYP",
        cashbox_id=cashbox.id,
        is_system=True,
        is_active=bool(cashbox.is_active),
    )
    db.add(account)
    db.flush()
    return account


def sync_cashbox_ledger_accounts(db: Session) -> None:
    for cashbox in db.query(Cashbox).all():
        ensure_cashbox_ledger_account(db, cashbox)


def _validate_balanced_lines(lines: list[LedgerLineInput]) -> tuple[Decimal, Decimal]:
    if len(lines) < 2:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Ledger entry requires at least 2 lines")

    total_debit = _q(sum((Decimal(line.debit) for line in lines), Decimal("0")))
    total_credit = _q(sum((Decimal(line.credit) for line in lines), Decimal("0")))

    if total_debit <= 0 or total_credit <= 0:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Debit and credit totals must be positive")

    if total_debit != total_credit:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Ledger entry must be balanced")

    return total_debit, total_credit


def create_ledger_entry(
    db: Session,
    *,
    created_by_id: UUID,
    lines: list[LedgerLineInput],
    transfer_id: UUID | None = None,
    reference_type: str = "manual",
    reference_id: UUID | None = None,
    description: str | None = None,
) -> LedgerEntry:
    _validate_balanced_lines(lines)

    for line in lines:
        account = db.query(LedgerAccount).filter(LedgerAccount.id == line.account_id, LedgerAccount.is_active == True).first()
        if not account:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ledger account not found or inactive")

    entry = LedgerEntry(
        transfer_id=transfer_id,
        reference_type=reference_type,
        reference_id=reference_id,
        description=description,
        created_by_id=created_by_id,
    )
    db.add(entry)
    db.flush()

    for line in lines:
        db.add(
            LedgerLine(
                entry_id=entry.id,
                account_id=line.account_id,
                debit=_q(line.debit),
                credit=_q(line.credit),
                currency=line.currency,
            )
        )

    db.flush()
    db.refresh(entry)
    return entry


def post_transfer_ledger_entry(db: Session, transfer: Transfer, created_by_id: UUID) -> LedgerEntry:
    existing = db.query(LedgerEntry).filter(LedgerEntry.transfer_id == transfer.id).first()
    if existing:
        return existing

    source_cashbox = db.query(Cashbox).filter(Cashbox.id == transfer.from_cashbox_id).first()
    destination_cashbox = db.query(Cashbox).filter(Cashbox.id == transfer.to_cashbox_id).first()
    treasury_cashbox = db.query(Cashbox).filter(Cashbox.id == transfer.treasury_cashbox_id).first()

    if not source_cashbox or not destination_cashbox or not treasury_cashbox:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found for ledger posting")

    ensure_default_ledger_accounts(db)
    source_account = ensure_cashbox_ledger_account(db, source_cashbox)
    destination_account = ensure_cashbox_ledger_account(db, destination_cashbox)
    treasury_account = ensure_cashbox_ledger_account(db, treasury_cashbox)
    amount = _q(transfer.amount)
    commission = _q(transfer.commission_amount)
    source_credit = _q(amount + commission)

    lines = [
        LedgerLineInput(account_id=destination_account.id, debit=amount, credit=Decimal("0"), currency=transfer.destination_currency),
        LedgerLineInput(account_id=source_account.id, debit=Decimal("0"), credit=source_credit, currency=transfer.source_currency),
    ]

    if commission > 0:
        lines.insert(
            1,
            LedgerLineInput(
                account_id=treasury_account.id,
                debit=commission,
                credit=Decimal("0"),
                currency=transfer.destination_currency,
            ),
        )

    return create_ledger_entry(
        db,
        created_by_id=created_by_id,
        transfer_id=transfer.id,
        reference_type="transfer",
        reference_id=transfer.id,
        description=f"Transfer {transfer.id}",
        lines=lines,
    )


def list_accounts(db: Session) -> list[LedgerAccount]:
    return db.query(LedgerAccount).order_by(LedgerAccount.code.asc()).all()


def list_entries(db: Session, limit: int = 100, transfer_id: UUID | None = None) -> list[LedgerEntry]:
    query = db.query(LedgerEntry).order_by(LedgerEntry.created_at.desc())
    if transfer_id is not None:
        query = query.filter(LedgerEntry.transfer_id == transfer_id)
    return query.limit(min(limit, 300)).all()


def get_entry(db: Session, entry_id: UUID) -> LedgerEntry:
    entry = db.query(LedgerEntry).filter(LedgerEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ledger entry not found")
    return entry


def get_trial_balance_rows(db: Session) -> list[dict]:
    rows = (
        db.query(
            LedgerAccount.id,
            LedgerAccount.code,
            LedgerAccount.name,
            LedgerAccount.account_type,
            func.coalesce(func.sum(LedgerLine.debit), 0).label("debit"),
            func.coalesce(func.sum(LedgerLine.credit), 0).label("credit"),
        )
        .outerjoin(LedgerLine, LedgerLine.account_id == LedgerAccount.id)
        .group_by(LedgerAccount.id)
        .order_by(LedgerAccount.code.asc())
        .all()
    )

    result = []
    for row in rows:
        debit = _q(row.debit)
        credit = _q(row.credit)
        result.append(
            {
                "account_id": row.id,
                "account_code": row.code,
                "account_name": row.name,
                "account_type": row.account_type,
                "debit": debit,
                "credit": credit,
                "balance": _q(debit - credit),
            }
        )
    return result
