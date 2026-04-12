from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session

from app.features.cashboxes.models import Cashbox, CashboxType
from app.features.commissions.service import (
    get_commission_values,
    get_treasury_collection_commission_percent,
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
    TransferCancelRequest,
    TransferCreateRequest,
    TransferReviewAction,
    TransferReviewRequest,
)
from app.features.users.models import User, UserRole


MONEY_QUANT = Decimal("0.01")
RATE_QUANT = Decimal("0.000001")



def _q_money(value: Decimal) -> Decimal:
    return Decimal(value).quantize(MONEY_QUANT, rounding=ROUND_HALF_UP)



def _q_rate(value: Decimal) -> Decimal:
    return Decimal(value).quantize(RATE_QUANT, rounding=ROUND_HALF_UP)



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


def _get_locked_cashbox(db: Session, cashbox_id: UUID) -> Cashbox | None:
    stmt = select(Cashbox).where(Cashbox.id == cashbox_id).with_for_update()
    return db.execute(stmt).scalar_one_or_none()



def _get_locked_treasury(db: Session) -> Cashbox | None:
    stmt = (
        select(Cashbox)
        .where(Cashbox.type == CashboxType.treasury, Cashbox.is_active == True)
        .with_for_update()
    )
    return db.execute(stmt).scalar_one_or_none()



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
    if user.role == UserRole.admin:
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
    if operation_type == TransferType.network_transfer:
        if source.type != CashboxType.accredited or destination.type != CashboxType.accredited:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Network transfers must move between accredited cashboxes",
            )
        return

    if operation_type == TransferType.topup:
        if destination.type != CashboxType.accredited or source.type not in {CashboxType.agent, CashboxType.treasury}:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Top-up must move from agent or treasury to an accredited cashbox",
            )
        return

    if operation_type == TransferType.collection:
        if source.type != CashboxType.accredited or destination.type not in {CashboxType.agent, CashboxType.treasury}:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Collection must move from accredited cashbox to agent or treasury",
            )
        return

    if operation_type == TransferType.agent_funding:
        if source.type != CashboxType.treasury or destination.type != CashboxType.agent:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Agent funding must move from treasury to an agent cashbox",
            )
        return

    if operation_type == TransferType.agent_collection:
        if source.type != CashboxType.agent or destination.type != CashboxType.treasury:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Agent collection must move from an agent cashbox to treasury",
            )
        return

    if operation_type == TransferType.customer_cashout:
        if source.type != CashboxType.accredited:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Customer cashout must start from an accredited cashbox",
            )
        if destination.id != source.id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Customer cashout destination must be the same accredited cashbox",
            )
        return

    raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Unsupported transfer type")



def _validate_transfer_scope(source: Cashbox, destination: Cashbox, performer: User, operation_type: TransferType) -> None:
    _validate_operation_shape(source, destination, operation_type)

    if performer.role == UserRole.admin:
        return

    if performer.role == UserRole.agent:
        my_agent_cashboxes = _managed_cashbox_ids(performer, CashboxType.agent)
        if not my_agent_cashboxes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Agent user does not manage an active agent cashbox",
            )

        if operation_type in {
            TransferType.network_transfer,
            TransferType.collection,
            TransferType.agent_collection,
            TransferType.customer_cashout,
        }:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Agent cannot execute this direct transfer route",
            )

        if operation_type == TransferType.agent_funding:
            if source.type != CashboxType.treasury:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Agent balance request must be funded by treasury cashbox",
                )
            if destination.id not in my_agent_cashboxes:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Agent balance request must target your own agent cashbox",
                )
            return

        if source.type == CashboxType.agent and source.id in my_agent_cashboxes:
            return
        if destination.type == CashboxType.agent and destination.id in my_agent_cashboxes:
            return

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Agent can only operate through their own agent cashbox",
        )

    my_accredited_cashboxes = _managed_cashbox_ids(performer, CashboxType.accredited)
    if not my_accredited_cashboxes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accredited user does not manage an active accredited cashbox",
        )

    if operation_type in {TransferType.agent_funding, TransferType.agent_collection}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admin can move balances directly between treasury and agent cashboxes",
        )

    if operation_type == TransferType.network_transfer:
        if source.id not in my_accredited_cashboxes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Accredited users can transfer only from their own accredited cashboxes",
            )
        return

    if operation_type == TransferType.topup:
        if destination.id not in my_accredited_cashboxes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Top-up request must target one of your accredited cashboxes",
            )
        return

    if operation_type == TransferType.customer_cashout:
        if source.id not in my_accredited_cashboxes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Customer cashout must start from one of your accredited cashboxes",
            )
        if destination.id != source.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Customer cashout must use the same accredited cashbox as destination",
            )
        return

    if source.id not in my_accredited_cashboxes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Collection request must start from one of your accredited cashboxes",
        )



def _determine_commission_role(source: Cashbox, destination: Cashbox, operation_type: TransferType) -> UserRole:
    if operation_type == TransferType.network_transfer:
        return UserRole.accredited

    if operation_type == TransferType.customer_cashout:
        return UserRole.accredited

    if source.type == CashboxType.treasury and destination.type == CashboxType.accredited:
        return UserRole.accredited
    if source.type == CashboxType.treasury and destination.type == CashboxType.agent:
        return UserRole.agent

    if operation_type == TransferType.agent_funding:
        return UserRole.agent
    if operation_type == TransferType.agent_collection:
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
    if operation_type == TransferType.customer_cashout:
        return False
    # Product rule: all transfer operations require recipient approval.
    # (User and cashbox creation flows are outside this service.)
    return True



def _is_review_from_source_side(
    *,
    operation_type: TransferType,
    performed_by_id: UUID,
    source_manager_user_id: UUID | None,
    destination_manager_user_id: UUID | None,
) -> bool:
    if (
        operation_type == TransferType.agent_funding
        and destination_manager_user_id is not None
        and performed_by_id == destination_manager_user_id
    ):
        return True

    if (
        operation_type == TransferType.topup
        and destination_manager_user_id is not None
        and performed_by_id == destination_manager_user_id
    ):
        return True

    if (
        operation_type in {TransferType.collection, TransferType.agent_collection}
        and source_manager_user_id is not None
        and performed_by_id != source_manager_user_id
    ):
        return True

    return False



def _can_user_review_pending_transfer(user: User, transfer: Transfer, source: Cashbox, destination: Cashbox) -> bool:
    review_from_source_side = _is_review_from_source_side(
        operation_type=transfer.operation_type,
        performed_by_id=transfer.performed_by_id,
        source_manager_user_id=source.manager_user_id,
        destination_manager_user_id=destination.manager_user_id,
    )

    review_cashbox = source if review_from_source_side else destination

    if review_cashbox.type == CashboxType.treasury:
        return user.role == UserRole.admin

    if user.role == UserRole.agent:
        my_agent_cashboxes = _managed_cashbox_ids(user, CashboxType.agent)
        return review_cashbox.id in my_agent_cashboxes

    if user.role == UserRole.accredited:
        my_accredited_cashboxes = _managed_cashbox_ids(user, CashboxType.accredited)
        return review_cashbox.id in my_accredited_cashboxes

    return False



def _apply_transfer_posting(db: Session, transfer: Transfer) -> None:
    source = _get_locked_cashbox(db, transfer.from_cashbox_id)
    destination = _get_locked_cashbox(db, transfer.to_cashbox_id)
    treasury = _get_locked_treasury(db)

    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not treasury:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Treasury cashbox not configured")

    if not source.is_active or not destination.is_active or not treasury.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cashboxes involved in transfer must be active")

    amount = _q_money(Decimal(transfer.amount))
    commission_amount = _q_money(Decimal(transfer.commission_amount))
    if getattr(transfer, "operation_type", None) == TransferType.customer_cashout:
        source_out = amount
        source_balance = _q_money(Decimal(source.balance))
        if source_balance < source_out:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient source cashbox balance")
        source.balance = _q_money(source_balance - source_out)
        transfer.treasury_cashbox_id = treasury.id
        transfer.state = TransferState.completed
        transfer.review_required = False
        return

    # Commission is deducted locally from the sender and moved to treasury.
    source_out = _q_money(amount + commission_amount)
    source_balance = _q_money(Decimal(source.balance))

    if source.type != CashboxType.treasury and source_balance < source_out:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient source cashbox balance")

    source.balance = _q_money(source_balance - source_out)
    destination.balance = _q_money(Decimal(destination.balance) + amount)
    treasury.balance = _q_money(Decimal(treasury.balance) + commission_amount)

    transfer.treasury_cashbox_id = treasury.id
    transfer.state = TransferState.completed
    transfer.review_required = False



def create_transfer(db: Session, payload: TransferCreateRequest, performer: User) -> Transfer:
    if (
        payload.from_cashbox_id == payload.to_cashbox_id
        and payload.operation_type != TransferType.customer_cashout
    ):
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

    source = _get_locked_cashbox(db, payload.from_cashbox_id)
    destination = _get_locked_cashbox(db, payload.to_cashbox_id)

    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not source.is_active or not destination.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Both cashboxes must be active")

    _validate_transfer_scope(source, destination, performer, payload.operation_type)

    customer_name = _normalize_optional_text(payload.customer_name)
    customer_phone = _normalize_optional_text(payload.customer_phone)
    if payload.operation_type == TransferType.customer_cashout:
        if not customer_name or not customer_phone:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Customer name and phone are required for customer cashout",
            )

    requested_amount = _q_money(payload.amount)
    commission_role = _determine_commission_role(source, destination, payload.operation_type)
    is_cross_country = source.country != destination.country
    is_agent_topup = (
        payload.operation_type == TransferType.topup
        and source.type == CashboxType.agent
        and destination.type == CashboxType.accredited
    )
    is_accredited_network_transfer = (
        payload.operation_type == TransferType.network_transfer
        and source.type == CashboxType.accredited
        and destination.type == CashboxType.accredited
    )
    is_treasury_to_user_funding = (
        source.type == CashboxType.treasury
        and destination.type in {CashboxType.accredited, CashboxType.agent}
        and payload.operation_type in {TransferType.topup, TransferType.agent_funding}
    )
    is_user_to_treasury_collection = (
        destination.type == CashboxType.treasury
        and source.type in {CashboxType.accredited, CashboxType.agent}
        and payload.operation_type in {TransferType.collection, TransferType.agent_collection}
    )
    sender_profit_enabled = is_agent_topup or is_accredited_network_transfer
    if is_treasury_to_user_funding:
        commission_percent = get_treasury_funding_commission_percent(db, destination.type)
        agent_profit_percent = Decimal("0")
    elif is_user_to_treasury_collection:
        commission_percent = get_treasury_collection_commission_percent(db, source.type)
        agent_profit_percent = Decimal("0")
    else:
        commission_percent, agent_profit_percent = get_commission_values(
            db,
            commission_role,
            is_cross_country=is_cross_country,
            sender_profit_enabled=sender_profit_enabled,
        )
    if payload.commission_percent is not None:
        commission_percent = Decimal(payload.commission_percent)
    commission_percent = _q_money(commission_percent)
    agent_profit_percent = _q_money(agent_profit_percent)
    cashout_profit_percent = Decimal(payload.cashout_profit_percent or Decimal("0"))
    cashout_profit_percent = _q_money(cashout_profit_percent)

    if is_agent_topup or is_accredited_network_transfer or is_treasury_to_user_funding:
        amount, commission_amount, agent_profit_amount = _split_requested_amount_with_fees(
            requested_amount,
            commission_percent,
            agent_profit_percent,
        )
        cashout_profit_percent = Decimal("0")
        cashout_profit_amount = Decimal("0")
    elif payload.operation_type == TransferType.customer_cashout:
        amount = requested_amount
        # Customer cashout has no treasury commission by product rule.
        commission_percent = Decimal("0")
        commission_amount = Decimal("0")
        agent_profit_percent = Decimal("0")
        agent_profit_amount = Decimal("0")
        cashout_profit_amount = _q_money((amount * cashout_profit_percent) / Decimal("100"))
    else:
        amount = requested_amount
        commission_amount = _q_money((amount * commission_percent) / Decimal("100"))
        agent_profit_amount = _q_money((amount * agent_profit_percent) / Decimal("100"))
        cashout_profit_percent = Decimal("0")
        cashout_profit_amount = Decimal("0")
    net_amount = amount

    transfer_note = _normalize_optional_text(payload.note)
    if payload.operation_type == TransferType.customer_cashout:
        customer_note = f"Customer: {customer_name} ({customer_phone})"
        transfer_note = (
            f"{customer_note} | {transfer_note}"
            if transfer_note
            else customer_note
        )

    risk = evaluate_transfer_risk(db, performer, source, destination, amount)
    review_required = _should_require_manual_review(
        performer,
        payload.operation_type,
        risk_requires_review=risk.requires_review,
    )

    transfer = Transfer(
        from_cashbox_id=source.id,
        to_cashbox_id=destination.id,
        treasury_cashbox_id=source.id,
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
        cashout_profit_percent=cashout_profit_percent,
        cashout_profit_amount=cashout_profit_amount,
        net_amount=net_amount,
        customer_name=customer_name,
        customer_phone=customer_phone,
        source_currency=payload.source_currency,
        destination_currency=payload.destination_currency,
        exchange_rate=_q_rate(payload.exchange_rate),
        snapshot_at=datetime.now(timezone.utc),
        risk_score=_q_money(risk.score),
        review_required=review_required,
        performed_by_id=performer.id,
        note=transfer_note,
    )

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
            "exchange_rate": str(transfer.exchange_rate),
            "requested_amount": str(requested_amount),
            "credited_amount": str(amount),
            "commission_amount": str(commission_amount),
            "sender_profit_amount": str(agent_profit_amount),
            "cashout_profit_amount": str(cashout_profit_amount),
            "customer_name": customer_name,
            "customer_phone": customer_phone,
        },
    )

    create_risk_alerts(db, transfer.id, performer.id, risk.alerts)

    if review_required:
        transfer.state = TransferState.pending_review
        waiting_reason = "Request is waiting for counterparty approval"
        if _is_review_from_source_side(
            operation_type=payload.operation_type,
            performed_by_id=performer.id,
            source_manager_user_id=source.manager_user_id,
            destination_manager_user_id=destination.manager_user_id,
        ):
            waiting_reason = "Request is waiting for source-side approval"
        elif destination.type == CashboxType.treasury:
            waiting_reason = "Request is waiting for admin approval"
        _append_state_log(
            db,
            transfer,
            TransferState.pending_review,
            actor_user_id=performer.id,
            reason=waiting_reason,
        )
        db.commit()
        db.refresh(transfer)
        return transfer

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

    db.commit()
    db.refresh(transfer)
    return transfer



def review_transfer(db: Session, transfer_id: UUID, payload: TransferReviewRequest, reviewer: User) -> Transfer:
    transfer = db.query(Transfer).filter(Transfer.id == transfer_id).with_for_update().first()
    if not transfer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer not found")

    if transfer.state != TransferState.pending_review:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Transfer is not pending review")

    source = _get_locked_cashbox(db, transfer.from_cashbox_id)
    destination = _get_locked_cashbox(db, transfer.to_cashbox_id)
    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not _can_user_review_pending_transfer(reviewer, transfer, source, destination):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not allowed to review this request")

    transfer.reviewed_by_id = reviewer.id
    transfer.reviewed_at = datetime.now(timezone.utc)
    transfer.review_note = payload.note.strip() if payload.note else None

    if payload.action == TransferReviewAction.reject:
        transfer.state = TransferState.rejected
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

    transfer.state = TransferState.approved
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
    except HTTPException as exc:
        transfer.state = TransferState.failed
        _append_state_log(
            db,
            transfer,
            TransferState.failed,
            actor_user_id=reviewer.id,
            reason=str(exc.detail),
        )

    db.commit()
    db.refresh(transfer)
    return transfer


def _apply_transfer_cancellation(db: Session, transfer: Transfer) -> tuple[Cashbox, Cashbox, Cashbox]:
    source = _get_locked_cashbox(db, transfer.from_cashbox_id)
    destination = _get_locked_cashbox(db, transfer.to_cashbox_id)
    treasury = _get_locked_treasury(db)

    if not source or not destination:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cashbox not found")

    if not treasury:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Treasury cashbox not configured")

    amount = _q_money(Decimal(transfer.amount))
    commission_amount = _q_money(Decimal(transfer.commission_amount))

    if transfer.operation_type == TransferType.customer_cashout:
        source.balance = _q_money(Decimal(source.balance) + amount)
        return source, destination, treasury

    destination_balance = _q_money(Decimal(destination.balance))
    if destination_balance < amount:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot cancel transfer because destination balance is not enough",
        )
    destination.balance = _q_money(destination_balance - amount)

    treasury_balance = _q_money(Decimal(treasury.balance))
    if treasury_balance < commission_amount:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot cancel transfer because treasury balance is not enough",
        )
    treasury.balance = _q_money(treasury_balance - commission_amount)

    source.balance = _q_money(Decimal(source.balance) + amount + commission_amount)
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
            currency=transfer.destination_currency,
        ),
    ]

    if commission > 0:
        lines.append(
            LedgerLineInput(
                account_id=treasury_account.id,
                debit=Decimal("0"),
                credit=commission,
                currency=transfer.destination_currency,
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
    if reviewer.role != UserRole.admin:
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
    if user.role == UserRole.admin:
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
                "total_cashout_profit": _q_money(Decimal(row.total_cashout_profit or 0)),
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

