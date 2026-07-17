import logging
import secrets
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import case, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password

logger = logging.getLogger(__name__)
from app.features.cashboxes.models import Cashbox, CashboxType
from app.features.commissions.service import (
    get_remittance_commission_percents,
    get_treasury_funding_commission_percent,
)
from app.features.ledger.service import (
    LedgerLineInput,
    create_ledger_entry,
    ensure_cashbox_ledger_account,
    ensure_default_ledger_accounts,
    post_transfer_ledger_entry,
)
from app.features.risk.service import create_risk_alerts, evaluate_transfer_risk, resolve_transfer_alerts
from app.features.transfers.models import Transfer, TransferState, TransferStateLog, TransferType
from app.features.transfers.schemas import (
    RemittanceCreateRequest,
    TransferCancelRequest,
    TransferCreateRequest,
    TransferReviewAction,
    TransferReviewRequest,
)
from app.features.users.models import User, UserRole, is_admin_role


MONEY_QUANT = Decimal("0.01")
APPROVAL_CODE_LENGTH = 6



def _q_money(value: Decimal) -> Decimal:
    return Decimal(value).quantize(MONEY_QUANT, rounding=ROUND_HALF_UP)



def _split_requested_amount_with_fees(
    requested_amount: Decimal,
    commission_percent: Decimal,
    sender_profit_percent: Decimal,
) -> tuple[Decimal, Decimal, Decimal]:
    # Gross input mode:
    # gross = credited + treasury_commission + sender_profit.
    divisor = Decimal("1") + (
        (Decimal(commission_percent) + Decimal(sender_profit_percent))
        / Decimal("100")
    )
    if divisor <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid commission configuration for this transfer",
        )

    credited_amount = _q_money(Decimal(requested_amount) / divisor)
    commission_amount = _q_money(
        (credited_amount * Decimal(commission_percent)) / Decimal("100")
    )
    sender_profit_amount = _q_money(
        (credited_amount * Decimal(sender_profit_percent)) / Decimal("100")
    )
    return (credited_amount, commission_amount, sender_profit_amount)


def _normalize_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    return normalized or None


def _generate_approval_code() -> str:
    upper_bound = 10**APPROVAL_CODE_LENGTH
    return str(secrets.randbelow(upper_bound)).zfill(APPROVAL_CODE_LENGTH)


def _normalize_approval_code(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = "".join(ch for ch in value.strip() if ch.isdigit())
    return normalized or None


def _attach_approval_code(transfer: Transfer) -> str:
    code = _generate_approval_code()
    transfer.approval_code_required = True
    transfer.approval_code_hash = hash_password(code)
    transfer._approval_code = code
    return code


def _verify_transfer_approval_code(transfer: Transfer, code: str | None) -> bool:
    normalized = _normalize_approval_code(code)
    if not normalized or not transfer.approval_code_hash:
        return False
    return verify_password(normalized, transfer.approval_code_hash)


def _clear_transfer_approval_code(transfer: Transfer) -> None:
    transfer.approval_code_required = False
    transfer.approval_code_hash = None
    transfer._approval_code = None


def _update_cashbox_currency_balance(
    cashbox: Cashbox, currency: str, delta: Decimal
) -> None:
    balances: dict = dict(cashbox.currency_balances or {})
    current = Decimal(str(balances.get(currency, "0")))
    updated = _q_money(current + delta)
    if updated == Decimal("0"):
        balances.pop(currency, None)
    else:
        balances[currency] = str(updated)
    cashbox.currency_balances = balances


def _get_locked_cashbox(db: Session, cashbox_id: UUID) -> Cashbox | None:
    stmt = select(Cashbox).where(Cashbox.id == cashbox_id).with_for_update()
    return db.execute(stmt).scalar_one_or_none()


def _lock_cashboxes_sorted(
    db: Session, cashbox_ids: "list[UUID] | set[UUID]"
) -> dict[UUID, "Cashbox | None"]:
    """Acquire row locks on the given cashboxes in a deterministic UUID order.

    Locking in a single global order (across every entry point that touches
    cashboxes) prevents deadlocks between concurrent transfers that involve the
    same cashboxes in different directions.
    """
    locked: dict[UUID, "Cashbox | None"] = {}
    for cid in sorted({cid for cid in cashbox_ids if cid is not None}, key=str):
        locked[cid] = _get_locked_cashbox(db, cid)
    return locked



def _get_locked_treasury(db: Session) -> Cashbox | None:
    stmt = (
        select(Cashbox)
        .where(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
        .with_for_update()
    )
    return db.execute(stmt).scalar_one_or_none()



def _commit_or_return_existing_transfer(
    db: Session,
    transfer: Transfer,
    *,
    performed_by_id: UUID,
    idempotency_key: str | None,
) -> Transfer:
    """Commit the new transfer, resolving an idempotency-key race gracefully.

    Two concurrent requests with the same idempotency key both pass the pre-insert
    lookup; the loser hits the unique constraint. Instead of surfacing a 500, return
    the transfer that actually won the race.
    """
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        if idempotency_key:
            existing = (
                db.query(Transfer)
                .filter(
                    Transfer.performed_by_id == performed_by_id,
                    Transfer.idempotency_key == idempotency_key,
                )
                .first()
            )
            if existing:
                return existing
        raise
    db.refresh(transfer)
    return transfer


def _append_state_log(
    db: Session,
    transfer: Transfer,
    state: TransferState,
    *,
    actor_user_id: UUID | None,
    reason: str | None = None,
    context: dict | None = None,
) -> None:
    db.add(
        TransferStateLog(
            transfer_id=transfer.id,
            state=state,
            actor_user_id=actor_user_id,
            reason=reason,
            context=context,
        )
    )



def _managed_cashbox_ids(user: User, *cashbox_types: CashboxType) -> set[UUID]:
    allowed = set(cashbox_types)
    return {
        cashbox.id
        for cashbox in user.managed_cashboxes
        if cashbox.is_active and (not allowed or cashbox.type in allowed)
    }



def _is_transfer_visible_to_user(transfer: Transfer, user: User) -> bool:
    if is_admin_role(user.role):
        return True

    visible_ids = _managed_cashbox_ids(user)
    if user.role == UserRole.accredited:
        visible_ids = _managed_cashbox_ids(user, CashboxType.accredited)
    elif user.role == UserRole.agent:
        visible_ids = _managed_cashbox_ids(user, CashboxType.agent)

    if transfer.from_cashbox_id in visible_ids or transfer.to_cashbox_id in visible_ids:
        return True

    return transfer.performed_by_id == user.id



def _validate_operation_shape(source: Cashbox, destination: Cashbox, operation_type: TransferType) -> None:
    if operation_type == TransferType.topup:
        if destination.type != CashboxType.accredited or source.type not in {CashboxType.agent, CashboxType.treasury}:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Top-up must move from agent or treasury to an accredited cashbox",
            )
        return

    if operation_type == TransferType.agent_funding:
        if source.type != CashboxType.treasury or destination.type != CashboxType.agent:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Agent funding must move from treasury to an agent cashbox",
            )
        return

    if operation_type == TransferType.remittance:
        if source.type != CashboxType.accredited or destination.type != CashboxType.accredited:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Remittances must move between accredited cashboxes",
            )
        if source.id == destination.id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot create a remittance to your own cashbox",
            )
        return

    raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Unsupported transfer type")



def _validate_transfer_scope(source: Cashbox, destination: Cashbox, performer: User, operation_type: TransferType) -> None:
    _validate_operation_shape(source, destination, operation_type)

    if is_admin_role(performer.role):
        return

    if performer.role == UserRole.agent:
        my_agent_cashboxes = _managed_cashbox_ids(performer, CashboxType.agent)
        if not my_agent_cashboxes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Agent user does not manage an active agent cashbox",
            )

        # Agents only push top-ups from their own agent cashbox to an accredited cashbox.
        # Treasury-to-agent funding (agent_funding) is admin-initiated only.
        if operation_type != TransferType.topup:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Agent can only top up accredited cashboxes",
            )
        if source.type != CashboxType.agent or source.id not in my_agent_cashboxes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Top-up must originate from your own agent cashbox",
            )
        if destination.type != CashboxType.accredited:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Agent top-up must target an accredited cashbox",
            )
        return

    # Accredited (and any other non-admin role) cannot initiate funding operations;
    # accredited users move money only through customer remittances.
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Only admin can fund cashboxes directly; accredited users use customer remittances",
    )



def _determine_commission_role(source: Cashbox, destination: Cashbox, operation_type: TransferType) -> UserRole:
    if source.type == CashboxType.treasury and destination.type == CashboxType.accredited:
        return UserRole.accredited
    if source.type == CashboxType.treasury and destination.type == CashboxType.agent:
        return UserRole.agent

    if operation_type == TransferType.agent_funding:
        return UserRole.agent
    if source.type == CashboxType.agent or destination.type == CashboxType.agent:
        return UserRole.agent

    return UserRole.admin



def _should_require_manual_review(
    performer: User,
    operation_type: TransferType,
    *,
    risk_requires_review: bool,
) -> bool:
    # Product rule: all transfer operations require recipient approval.
    # (User and cashbox creation flows are outside this service.)
    return True


def _apply_admin_commission_override(
    commission_percent: Decimal,
    requested_override: Decimal | None,
    performer: User,
) -> Decimal:
    if requested_override is not None and is_admin_role(performer.role):
        return Decimal(requested_override)
    return commission_percent



def _can_user_review_pending_transfer(user: User, transfer: Transfer, source: Cashbox, destination: Cashbox) -> bool:
    # Admins/super-admins are the only role that can approve OR reject anything.
    if is_admin_role(user.role):
        return True

    # The recipient confirms receipt of what was sent to them. The initiator can
    # never approve their own request, and the source side never approves.
    if transfer.performed_by_id == user.id:
        return False

    review_cashbox = destination
    if review_cashbox.type == CashboxType.treasury:
        return False  # only admin manages the treasury

    if user.role == UserRole.agent:
        return review_cashbox.id in _managed_cashbox_ids(user, CashboxType.agent)

    if user.role == UserRole.accredited:
        return review_cashbox.id in _managed_cashbox_ids(user, CashboxType.accredited)

    return False



def _apply_transfer_posting(db: Session, transfer: Transfer) -> None:
    # All involved cashboxes (source, destination, treasury) are expected to be
    # locked by the caller in a single global UUID order. Re-acquiring the locks
    # here is a no-op within the same transaction and keeps this function safe to
    # call directly in tests.
    source = _get_locked_cashbox(db, transfer.from_cashbox_id)
    destination = _get_locked_cashbox(db, transfer.to_cashbox_id)

    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not source.is_active or not destination.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cashboxes involved in transfer must be active")

    # Single-currency model: amounts are denominated in the transfer currency and
    # each currency keeps its own independent balance per cashbox.
    amount = _q_money(Decimal(transfer.amount))
    commission_amount = _q_money(Decimal(transfer.commission_amount))
    currency = (getattr(transfer, "source_currency", None) or "SYP").upper()

    def _src_balance(cashbox: "Cashbox") -> Decimal:
        balances: dict = cashbox.currency_balances or {}
        return _q_money(Decimal(str(balances.get(currency, "0"))))

    # Remittance: debit sender at approval, distribute commissions, net exits the system.
    #
    # Physical reality: receiver accredited pays the final customer CASH from their own funds.
    # Digital accounting:
    #   Sender debited:   transit = net + treasury_commission + receiver_commission
    #   Treasury credited: treasury_commission
    #   Receiver credited: receiver_commission ONLY (their earnings for paying cash out)
    #   Net amount:        exits digital system (became physical cash the receiver paid out)
    if getattr(transfer, "operation_type", None) == TransferType.remittance:
        treasury = _get_locked_treasury(db)
        if not treasury:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Treasury cashbox not configured")
        if not treasury.is_active:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Treasury cashbox is not active")

        net_amount = amount
        receiver_commission = _q_money(Decimal(transfer.receiver_commission_amount))
        treasury_commission = commission_amount

        transit = _q_money(net_amount + receiver_commission + treasury_commission)

        # Check sender has sufficient balance before debiting.
        if _src_balance(source) < transit:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Insufficient source cashbox balance to complete this remittance",
            )

        # Debit sender the full transit.
        _update_cashbox_currency_balance(source, currency, -transit)

        # Credit receiver ONLY their commission (net amount was paid as cash, exits digital system).
        if receiver_commission > 0:
            _update_cashbox_currency_balance(destination, currency, receiver_commission)

        # Credit treasury their commission.
        if treasury_commission > 0:
            _update_cashbox_currency_balance(treasury, currency, treasury_commission)

        transfer.treasury_cashbox_id = treasury.id
        transfer.state = TransferState.completed
        transfer.review_required = False
        return

    # For all other transfer types, lock treasury and credit it with commission.
    treasury = _get_locked_treasury(db)
    if not treasury:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Treasury cashbox not configured")
    if not treasury.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cashboxes involved in transfer must be active")

    source_out = _q_money(amount + commission_amount)
    if source.type != CashboxType.treasury and _src_balance(source) < source_out:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient source cashbox balance")

    _update_cashbox_currency_balance(source, currency, -source_out)
    _update_cashbox_currency_balance(destination, currency, amount)
    if commission_amount > 0:
        _update_cashbox_currency_balance(treasury, currency, commission_amount)

    transfer.treasury_cashbox_id = treasury.id
    transfer.state = TransferState.completed
    transfer.review_required = False



def create_transfer(db: Session, payload: TransferCreateRequest, performer: User) -> Transfer:
    if payload.from_cashbox_id == payload.to_cashbox_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Source and destination cashbox must be different",
        )

    if payload.idempotency_key:
        existing = (
            db.query(Transfer)
            .filter(
                Transfer.performed_by_id == performer.id,
                Transfer.idempotency_key == payload.idempotency_key,
            )
            .first()
        )
        if existing:
            return existing

    # Fetch the treasury ID upfront (non-locking) so it is recorded correctly
    # even for transfers that enter pending_review without calling _apply_transfer_posting.
    treasury_for_record = (
        db.query(Cashbox)
        .filter(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
        .first()
    )
    if not treasury_for_record:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Treasury cashbox not configured",
        )

    # Lock source, destination and treasury together in one global UUID order to
    # avoid deadlocks with concurrent transfers touching the same cashboxes.
    locked = _lock_cashboxes_sorted(
        db,
        [payload.from_cashbox_id, payload.to_cashbox_id, treasury_for_record.id],
    )
    source = locked.get(payload.from_cashbox_id)
    destination = locked.get(payload.to_cashbox_id)

    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not source.is_active or not destination.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Both cashboxes must be active")

    _validate_transfer_scope(source, destination, performer, payload.operation_type)

    requested_amount = _q_money(payload.amount)
    commission_role = _determine_commission_role(source, destination, payload.operation_type)
    is_cross_country = source.country != destination.country
    is_agent_topup = (
        payload.operation_type == TransferType.topup
        and source.type == CashboxType.agent
        and destination.type == CashboxType.accredited
    )
    if is_agent_topup:
        # Op3 (agent → accredited): the agent keeps their own commission; the
        # treasury takes nothing. The agent fee uses the agent role's internal/
        # external fee depending on whether it crosses a country border.
        from app.features.commissions.models import CommissionRule
        agent_rule = (
            db.query(CommissionRule)
            .filter(CommissionRule.role == UserRole.agent, CommissionRule.is_active == True)
            .first()
        )
        commission_percent = Decimal("0")
        agent_profit_percent = (
            Decimal(agent_rule.external_fee_percent if is_cross_country else agent_rule.internal_fee_percent)
            if agent_rule
            else Decimal("0")
        )
    else:
        # Op1/Op2 (admin → agent / admin → accredited): treasury commission only.
        commission_percent = get_treasury_funding_commission_percent(
            db, destination.type, is_cross_country=is_cross_country
        )
        agent_profit_percent = Decimal("0")
    commission_percent = _apply_admin_commission_override(
        commission_percent,
        payload.commission_percent,
        performer,
    )
    commission_percent = _q_money(commission_percent)
    agent_profit_percent = _q_money(agent_profit_percent)

    # Gross input mode for every funding operation: the entered amount is the gross
    # debited from the source, split into the credited amount + fees.
    amount, commission_amount, agent_profit_amount = _split_requested_amount_with_fees(
        requested_amount,
        commission_percent,  # 0 for agent topup (agent keeps their fee, not treasury)
        agent_profit_percent,
    )
    net_amount = amount

    src_currency = (payload.source_currency or "SYP").upper()

    # Reject immediately if source cashbox has insufficient balance.
    # Treasury is admin-managed and exempt from this early check.
    if source.type != CashboxType.treasury:
        src_balance = _q_money(
            Decimal(str((source.currency_balances or {}).get(src_currency, "0")))
        )
        source_out = _q_money(amount + commission_amount)
        if src_balance < source_out:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Insufficient source cashbox balance",
            )

    transfer_note = _normalize_optional_text(payload.note)

    risk = evaluate_transfer_risk(
        db, performer, source, destination, amount, currency=src_currency
    )
    review_required = _should_require_manual_review(
        performer,
        payload.operation_type,
        risk_requires_review=risk.requires_review,
    )

    transfer = Transfer(
        from_cashbox_id=source.id,
        to_cashbox_id=destination.id,
        treasury_cashbox_id=treasury_for_record.id,
        operation_type=payload.operation_type,
        idempotency_key=payload.idempotency_key,
        state=TransferState.initiated,
        amount=amount,
        commission_role=commission_role,
        commission_percent=commission_percent,
        commission_amount=commission_amount,
        is_cross_country=is_cross_country,
        agent_profit_percent=agent_profit_percent,
        agent_profit_amount=agent_profit_amount,
        net_amount=net_amount,
        source_currency=src_currency,
        snapshot_at=datetime.now(timezone.utc),
        risk_score=_q_money(risk.score),
        review_required=review_required,
        performed_by_id=performer.id,
        note=transfer_note,
    )
    if review_required:
        _attach_approval_code(transfer)

    db.add(transfer)
    db.flush()

    _append_state_log(
        db,
        transfer,
        TransferState.initiated,
        actor_user_id=performer.id,
        context={
            "operation_type": transfer.operation_type.value,
            "from_city": source.city,
            "to_city": destination.city,
            "from_country": source.country,
            "to_country": destination.country,
            "is_cross_country": is_cross_country,
            "source_type": source.type.value,
            "destination_type": destination.type.value,
            "source_name": source.name,
            "destination_name": destination.name,
            "currency": transfer.source_currency,
            "requested_amount": str(requested_amount),
            "credited_amount": str(amount),
            "commission_amount": str(commission_amount),
            "sender_profit_amount": str(agent_profit_amount),
            "approval_code_required": transfer.approval_code_required,
        },
    )

    create_risk_alerts(db, transfer.id, performer.id, risk.alerts)

    if review_required:
        transfer.state = TransferState.pending_review
        # The recipient confirms receipt; treasury-bound requests wait for admin.
        if destination.type == CashboxType.treasury:
            waiting_reason = "Request is waiting for admin approval"
        else:
            waiting_reason = "Request is waiting for recipient approval"
        _append_state_log(
            db,
            transfer,
            TransferState.pending_review,
            actor_user_id=performer.id,
            reason=waiting_reason,
        )
        return _commit_or_return_existing_transfer(
            db,
            transfer,
            performed_by_id=performer.id,
            idempotency_key=payload.idempotency_key,
        )

    _apply_transfer_posting(db, transfer)
    post_transfer_ledger_entry(db, transfer, performer.id)

    _append_state_log(
        db,
        transfer,
        TransferState.completed,
        actor_user_id=performer.id,
        reason="Transfer executed successfully",
    )
    resolve_transfer_alerts(db, transfer.id)

    return _commit_or_return_existing_transfer(
        db,
        transfer,
        performed_by_id=performer.id,
        idempotency_key=payload.idempotency_key,
    )



def review_transfer(db: Session, transfer_id: UUID, payload: TransferReviewRequest, reviewer: User) -> Transfer:
    transfer = db.query(Transfer).filter(Transfer.id == transfer_id).with_for_update().first()
    if not transfer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer not found")

    if transfer.state != TransferState.pending_review:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Transfer is not pending review")

    # Lock source, destination and treasury together in one global UUID order to
    # avoid deadlocks with concurrent transfers touching the same cashboxes.
    locked = _lock_cashboxes_sorted(
        db,
        [transfer.from_cashbox_id, transfer.to_cashbox_id, transfer.treasury_cashbox_id],
    )
    source = locked.get(transfer.from_cashbox_id)
    destination = locked.get(transfer.to_cashbox_id)
    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not _can_user_review_pending_transfer(reviewer, transfer, source, destination):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not allowed to review this request")

    transfer.reviewed_by_id = reviewer.id
    transfer.reviewed_at = datetime.now(timezone.utc)
    transfer.review_note = payload.note.strip() if payload.note else None

    if payload.action == TransferReviewAction.reject:
        if not is_admin_role(reviewer.role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only admin can reject transfer requests",
            )
        transfer.state = TransferState.rejected
        _clear_transfer_approval_code(transfer)
        _append_state_log(
            db,
            transfer,
            TransferState.rejected,
            actor_user_id=reviewer.id,
            reason=payload.note or "Rejected during review",
        )
        db.commit()
        db.refresh(transfer)
        return transfer

    if transfer.approval_code_required and not _verify_transfer_approval_code(
        transfer,
        payload.approval_code,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid transfer approval code",
        )

    transfer.state = TransferState.approved
    _clear_transfer_approval_code(transfer)
    _append_state_log(
        db,
        transfer,
        TransferState.approved,
        actor_user_id=reviewer.id,
        reason=payload.note or "Approved during review",
    )

    try:
        _apply_transfer_posting(db, transfer)
        post_transfer_ledger_entry(db, transfer, reviewer.id)
        _append_state_log(
            db,
            transfer,
            TransferState.completed,
            actor_user_id=reviewer.id,
            reason="Transfer executed after approval",
        )
        resolve_transfer_alerts(db, transfer.id)
        db.commit()
        db.refresh(transfer)
        return transfer
    except HTTPException as exc:
        # Rollback ALL in-session changes (balance updates, approved state log, etc.)
        # so that no partial data is committed to the database.
        logger.error(
            "Transfer %s posting failed after approval by %s: %s",
            transfer_id,
            reviewer.id,
            exc.detail,
            exc_info=True,
        )
        db.rollback()
        # Re-fetch a clean instance after rollback, then record failure only.
        failed_transfer = (
            db.query(Transfer).filter(Transfer.id == transfer_id).first()
        )
        if failed_transfer:
            failed_transfer.state = TransferState.failed
            failed_transfer.reviewed_by_id = reviewer.id
            failed_transfer.reviewed_at = datetime.now(timezone.utc)
            failed_transfer.review_note = str(exc.detail)
            # The rollback restored the approval code; clear it so a failed
            # transfer never keeps a live approval secret.
            _clear_transfer_approval_code(failed_transfer)
            _append_state_log(
                db,
                failed_transfer,
                TransferState.failed,
                actor_user_id=reviewer.id,
                reason=str(exc.detail),
            )
            db.commit()
            db.refresh(failed_transfer)
            return failed_transfer
        raise


def create_remittance(db: Session, payload: RemittanceCreateRequest, performer: User) -> Transfer:
    if performer.role != UserRole.accredited:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only accredited users can create remittances",
        )

    my_accredited_cashboxes = _managed_cashbox_ids(performer, CashboxType.accredited)
    if not my_accredited_cashboxes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not manage an active accredited cashbox",
        )

    if payload.from_cashbox_id not in my_accredited_cashboxes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Source cashbox must be one of your accredited cashboxes",
        )

    if payload.from_cashbox_id == payload.to_cashbox_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Cannot create a remittance to your own cashbox",
        )

    if payload.idempotency_key:
        existing = (
            db.query(Transfer)
            .filter(
                Transfer.performed_by_id == performer.id,
                Transfer.idempotency_key == payload.idempotency_key,
            )
            .first()
        )
        if existing:
            return existing

    treasury_for_record = (
        db.query(Cashbox)
        .filter(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
        .first()
    )
    if not treasury_for_record:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Treasury cashbox not configured",
        )

    # Lock source, destination and treasury together in one global UUID order.
    locked = _lock_cashboxes_sorted(
        db,
        [payload.from_cashbox_id, payload.to_cashbox_id, treasury_for_record.id],
    )
    source = locked.get(payload.from_cashbox_id)
    destination = locked.get(payload.to_cashbox_id)

    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not source.is_active or not destination.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Both cashboxes must be active")

    if source.type != CashboxType.accredited or destination.type != CashboxType.accredited:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Remittances must be between accredited cashboxes",
        )

    gross = _q_money(Decimal(str(payload.amount)))
    treasury_pct, sender_pct, receiver_pct = get_remittance_commission_percents(db)
    treasury_pct = _q_money(treasury_pct)
    sender_pct = _q_money(sender_pct)
    receiver_pct = _q_money(receiver_pct)

    currency = (payload.source_currency or "SYP").upper()

    sender_commission = _q_money(gross * sender_pct / Decimal("100"))
    transit = _q_money(gross - sender_commission)
    treasury_commission = _q_money(transit * treasury_pct / Decimal("100"))
    receiver_commission = _q_money(transit * receiver_pct / Decimal("100"))
    net_to_customer = _q_money(transit - treasury_commission - receiver_commission)

    # No balance check at creation — debit happens at approval time.

    is_cross_country = source.country != destination.country

    transfer = Transfer(
        from_cashbox_id=source.id,
        to_cashbox_id=destination.id,
        treasury_cashbox_id=treasury_for_record.id,
        operation_type=TransferType.remittance,
        idempotency_key=payload.idempotency_key,
        state=TransferState.initiated,
        amount=net_to_customer,
        commission_role=UserRole.accredited,
        commission_percent=treasury_pct,
        commission_amount=treasury_commission,
        is_cross_country=is_cross_country,
        agent_profit_percent=sender_pct,
        agent_profit_amount=sender_commission,
        sender_commission_percent=sender_pct,
        sender_commission_amount=sender_commission,
        receiver_commission_percent=receiver_pct,
        receiver_commission_amount=receiver_commission,
        net_amount=net_to_customer,
        sender_name=payload.sender_name.strip(),
        sender_phone=payload.sender_phone.strip(),
        sender_country=payload.sender_country.strip(),
        sender_city=payload.sender_city.strip(),
        receiver_name=payload.receiver_name.strip(),
        receiver_phone=payload.receiver_phone.strip(),
        receiver_country=payload.receiver_country.strip(),
        receiver_city=payload.receiver_city.strip(),
        source_currency=currency,
        snapshot_at=datetime.now(timezone.utc),
        risk_score=Decimal("0"),
        review_required=True,
        approval_code_required=False,
        performed_by_id=performer.id,
        note=_normalize_optional_text(payload.note),
    )

    db.add(transfer)
    db.flush()

    _append_state_log(
        db,
        transfer,
        TransferState.initiated,
        actor_user_id=performer.id,
        context={
            "operation_type": "remittance",
            "gross": str(gross),
            "transit": str(transit),
            "treasury_commission": str(treasury_commission),
            "sender_commission": str(sender_commission),
            "receiver_commission": str(receiver_commission),
            "net_to_customer": str(net_to_customer),
            "sender_name": transfer.sender_name,
            "receiver_name": transfer.receiver_name,
            "is_cross_country": is_cross_country,
        },
    )

    transfer.state = TransferState.pending_review
    _append_state_log(
        db,
        transfer,
        TransferState.pending_review,
        actor_user_id=performer.id,
        reason="Waiting for receiver accredited to confirm delivery",
    )

    return _commit_or_return_existing_transfer(
        db,
        transfer,
        performed_by_id=performer.id,
        idempotency_key=payload.idempotency_key,
    )


def _apply_transfer_cancellation(db: Session, transfer: Transfer) -> tuple[Cashbox, Cashbox, Cashbox]:
    # Locks are acquired by the caller in a single global UUID order; re-acquiring
    # here is a no-op within the same transaction.
    source = _get_locked_cashbox(db, transfer.from_cashbox_id)
    destination = _get_locked_cashbox(db, transfer.to_cashbox_id)
    treasury = _get_locked_treasury(db)

    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not treasury:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Treasury cashbox not configured")

    # Single-currency model: reverse the completed posting in the transfer currency.
    amount = _q_money(Decimal(transfer.amount))
    commission_amount = _q_money(Decimal(transfer.commission_amount))
    currency = (getattr(transfer, "source_currency", None) or "SYP").upper()

    def _cur_balance(cashbox: "Cashbox") -> Decimal:
        balances: dict = cashbox.currency_balances or {}
        return _q_money(Decimal(str(balances.get(currency, "0"))))

    if transfer.operation_type == TransferType.remittance:
        # Reverse the completed posting (symmetric with _apply_transfer_posting remittance path).
        # At approval: sender debited transit, receiver credited receiver_commission only,
        #              treasury credited treasury_commission, net exited the digital system.
        # To cancel:   debit receiver_commission from receiver, debit treasury_commission from treasury,
        #              restore full transit to sender.
        receiver_commission = _q_money(Decimal(transfer.receiver_commission_amount or 0))
        transit = _q_money(amount + receiver_commission + commission_amount)
        if receiver_commission > 0:
            if _cur_balance(destination) < receiver_commission:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Cannot cancel remittance because receiver commission balance is insufficient",
                )
            _update_cashbox_currency_balance(destination, currency, -receiver_commission)
        if commission_amount > 0:
            if _cur_balance(treasury) < commission_amount:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Cannot cancel remittance because treasury balance is insufficient",
                )
            _update_cashbox_currency_balance(treasury, currency, -commission_amount)
        _update_cashbox_currency_balance(source, currency, transit)
        return source, destination, treasury

    if _cur_balance(destination) < amount:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot cancel transfer because destination balance is not enough",
        )
    _update_cashbox_currency_balance(destination, currency, -amount)

    source_is_treasury = source.id == treasury.id
    if not source_is_treasury and commission_amount > 0:
        if _cur_balance(treasury) < commission_amount:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cannot cancel transfer because treasury balance is not enough",
            )
        _update_cashbox_currency_balance(treasury, currency, -commission_amount)

    source_restore = amount if source_is_treasury else _q_money(amount + commission_amount)
    _update_cashbox_currency_balance(source, currency, source_restore)

    return source, destination, treasury


def _post_transfer_cancellation_ledger_entry(
    db: Session,
    transfer: Transfer,
    *,
    source: Cashbox,
    destination: Cashbox,
    treasury: Cashbox,
    created_by_id: UUID,
) -> None:
    ensure_default_ledger_accounts(db)
    source_account = ensure_cashbox_ledger_account(db, source)
    destination_account = ensure_cashbox_ledger_account(db, destination)
    treasury_account = ensure_cashbox_ledger_account(db, treasury)

    amount = _q_money(Decimal(transfer.amount))
    commission = _q_money(Decimal(transfer.commission_amount))

    source_debit = _q_money(amount + commission)

    lines = [
        LedgerLineInput(
            account_id=source_account.id,
            debit=source_debit,
            credit=Decimal("0"),
            currency=transfer.source_currency,
        ),
        LedgerLineInput(
            account_id=destination_account.id,
            debit=Decimal("0"),
            credit=amount,
            currency=transfer.source_currency,
        ),
    ]

    if commission > 0:
        lines.append(
            LedgerLineInput(
                account_id=treasury_account.id,
                debit=Decimal("0"),
                credit=commission,
                currency=transfer.source_currency,
            )
        )

    create_ledger_entry(
        db,
        created_by_id=created_by_id,
        transfer_id=None,
        reference_type="transfer_cancellation",
        reference_id=transfer.id,
        description=f"Cancellation of transfer {transfer.id}",
        lines=lines,
    )


def cancel_transfer(
    db: Session,
    transfer_id: UUID,
    payload: TransferCancelRequest,
    reviewer: User,
) -> Transfer:
    if not is_admin_role(reviewer.role):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admin can cancel completed transfers",
        )

    transfer = db.query(Transfer).filter(Transfer.id == transfer_id).with_for_update().first()
    if not transfer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer not found")

    if transfer.state != TransferState.completed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only completed transfers can be cancelled",
        )

    # Pre-lock all involved cashboxes in one global UUID order before reversing.
    _lock_cashboxes_sorted(
        db,
        [transfer.from_cashbox_id, transfer.to_cashbox_id, transfer.treasury_cashbox_id],
    )
    source, destination, treasury = _apply_transfer_cancellation(db, transfer)
    _post_transfer_cancellation_ledger_entry(
        db,
        transfer,
        source=source,
        destination=destination,
        treasury=treasury,
        created_by_id=reviewer.id,
    )

    reason = payload.note.strip() if payload.note else "Cancelled by admin"
    transfer.state = TransferState.failed
    transfer.review_required = False
    transfer.reviewed_by_id = reviewer.id
    transfer.reviewed_at = datetime.now(timezone.utc)
    transfer.review_note = reason

    _append_state_log(
        db,
        transfer,
        TransferState.failed,
        actor_user_id=reviewer.id,
        reason=reason,
        context={"action": "admin_cancel", "restored": True},
    )
    resolve_transfer_alerts(db, transfer.id)

    db.commit()
    db.refresh(transfer)
    return transfer


def _start_of_day(day: date) -> datetime:
    return datetime.combine(day, time.min).replace(tzinfo=timezone.utc)


def _end_of_day_exclusive(day: date) -> datetime:
    return _start_of_day(day) + timedelta(days=1)


def _scoped_transfers_query(db: Session, user: User):
    query = db.query(Transfer)
    if is_admin_role(user.role):
        return query

    visible_ids = _managed_cashbox_ids(user)
    if user.role == UserRole.accredited:
        visible_ids = _managed_cashbox_ids(user, CashboxType.accredited)
    elif user.role == UserRole.agent:
        visible_ids = _managed_cashbox_ids(user, CashboxType.agent)

    if not visible_ids:
        return query.filter(Transfer.performed_by_id == user.id)

    return query.filter(
        or_(
            Transfer.from_cashbox_id.in_(visible_ids),
            Transfer.to_cashbox_id.in_(visible_ids),
            Transfer.performed_by_id == user.id,
        )
    )


def list_transfers(
    db: Session,
    user: User,
    limit: int = 100,
    from_date: date | None = None,
    to_date: date | None = None,
) -> list[Transfer]:
    query = _scoped_transfers_query(db, user)

    if from_date:
        query = query.filter(Transfer.created_at >= _start_of_day(from_date))
    if to_date:
        query = query.filter(Transfer.created_at < _end_of_day_exclusive(to_date))

    return query.order_by(Transfer.created_at.desc()).limit(min(limit, 200)).all()



def list_pending_transfers(
    db: Session,
    user: User,
    limit: int = 100,
    from_date: date | None = None,
    to_date: date | None = None,
) -> list[Transfer]:
    query = _scoped_transfers_query(db, user).filter(Transfer.state == TransferState.pending_review)
    if from_date:
        query = query.filter(Transfer.created_at >= _start_of_day(from_date))
    if to_date:
        query = query.filter(Transfer.created_at < _end_of_day_exclusive(to_date))

    rows = query.order_by(Transfer.created_at.asc()).limit(min(limit, 200)).all()
    return [
        row
        for row in rows
        if row.from_cashbox
        and row.to_cashbox
        and _can_user_review_pending_transfer(
            user,
            row,
            row.from_cashbox,
            row.to_cashbox,
        )
    ]


def daily_transfer_report(
    db: Session,
    user: User,
    *,
    from_date: date | None = None,
    to_date: date | None = None,
    limit_days: int = 30,
) -> list[dict]:
    scoped = _scoped_transfers_query(db, user)
    if from_date:
        scoped = scoped.filter(Transfer.created_at >= _start_of_day(from_date))
    if to_date:
        scoped = scoped.filter(Transfer.created_at < _end_of_day_exclusive(to_date))

    # Non-admin users should only see profits earned by their own role.
    # Admins see the global unfiltered total across all roles.
    _profit_condition = (
        Transfer.state == TransferState.completed
        if is_admin_role(user.role)
        else (
            (Transfer.state == TransferState.completed)
            & (Transfer.commission_role == user.role)
        )
    )

    day_key = func.date(Transfer.created_at)
    query = (
        scoped.with_entities(
            day_key.label("day"),
            func.count(Transfer.id).label("transfers_count"),
            func.sum(
                case((Transfer.state == TransferState.completed, 1), else_=0)
            ).label("completed_count"),
            func.sum(
                case((Transfer.state == TransferState.pending_review, 1), else_=0)
            ).label("pending_count"),
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
                        (_profit_condition, Transfer.agent_profit_amount),
                        else_=0,
                    )
                ),
                0,
            ).label("total_agent_profit"),
        )
        .group_by(day_key)
        .order_by(day_key.desc())
        .limit(max(1, min(limit_days, 180)))
    )

    rows = query.all()
    results: list[dict] = []
    for row in rows:
        day_value = row.day.isoformat() if hasattr(row.day, "isoformat") else str(row.day)
        results.append(
            {
                "date": day_value,
                "transfers_count": int(row.transfers_count or 0),
                "completed_count": int(row.completed_count or 0),
                "pending_count": int(row.pending_count or 0),
                "total_amount": _q_money(Decimal(row.total_amount or 0)),
                "total_commission": _q_money(Decimal(row.total_commission or 0)),
                "total_agent_profit": _q_money(Decimal(row.total_agent_profit or 0)),
            }
        )
    return results



def list_transfer_state_logs(db: Session, transfer_id: UUID, user: User) -> list[TransferStateLog]:
    transfer = db.query(Transfer).filter(Transfer.id == transfer_id).first()
    if not transfer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer not found")

    if not _is_transfer_visible_to_user(transfer, user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not allowed to view this transfer")

    return (
        db.query(TransferStateLog)
        .filter(TransferStateLog.transfer_id == transfer_id)
        .order_by(TransferStateLog.created_at.asc())
        .all()
    )

