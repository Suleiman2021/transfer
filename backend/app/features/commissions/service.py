from decimal import Decimal

from sqlalchemy.orm import Session

from app.features.cashboxes.models import CashboxType
from app.features.commissions.models import CommissionRule
from app.features.users.models import UserRole


def upsert_commission_rule(
    db: Session,
    role: UserRole,
    *,
    internal_fee_percent: Decimal | None = None,
    external_fee_percent: Decimal | None = None,
    treasury_to_accredited_fee_percent: Decimal | None = None,
    treasury_to_agent_fee_percent: Decimal | None = None,
    treasury_collection_from_accredited_fee_percent: Decimal | None = None,
    treasury_collection_from_agent_fee_percent: Decimal | None = None,
    agent_topup_profit_internal_percent: Decimal | None = None,
    agent_topup_profit_external_percent: Decimal | None = None,
    agent_topup_profit_percent: Decimal | None = None,
    legacy_fee_percent: Decimal | None = None,
) -> CommissionRule:
    rule = db.query(CommissionRule).filter(CommissionRule.role == role).first()
    fallback_fee = Decimal(legacy_fee_percent) if legacy_fee_percent is not None else None

    if rule:
        if internal_fee_percent is not None:
            rule.internal_fee_percent = Decimal(internal_fee_percent)
        elif fallback_fee is not None:
            rule.internal_fee_percent = fallback_fee

        if external_fee_percent is not None:
            rule.external_fee_percent = Decimal(external_fee_percent)
        elif fallback_fee is not None:
            rule.external_fee_percent = fallback_fee
        if treasury_to_accredited_fee_percent is not None:
            rule.treasury_to_accredited_fee_percent = Decimal(
                treasury_to_accredited_fee_percent
            )
        if treasury_to_agent_fee_percent is not None:
            rule.treasury_to_agent_fee_percent = Decimal(
                treasury_to_agent_fee_percent
            )
        if treasury_collection_from_accredited_fee_percent is not None:
            rule.treasury_collection_from_accredited_fee_percent = Decimal(
                treasury_collection_from_accredited_fee_percent
            )
        if treasury_collection_from_agent_fee_percent is not None:
            rule.treasury_collection_from_agent_fee_percent = Decimal(
                treasury_collection_from_agent_fee_percent
            )

        if agent_topup_profit_internal_percent is not None:
            rule.agent_topup_profit_internal_percent = Decimal(
                agent_topup_profit_internal_percent
            )
        if agent_topup_profit_external_percent is not None:
            rule.agent_topup_profit_external_percent = Decimal(
                agent_topup_profit_external_percent
            )
        if agent_topup_profit_percent is not None:
            # Legacy compatibility: apply same value to both.
            rule.agent_topup_profit_internal_percent = Decimal(
                agent_topup_profit_percent
            )
            rule.agent_topup_profit_external_percent = Decimal(
                agent_topup_profit_percent
            )

        # Keep the legacy field aligned with the internal value for compatibility.
        rule.agent_topup_profit_percent = Decimal(
            rule.agent_topup_profit_internal_percent
        )

        rule.is_active = True
    else:
        initial_internal = Decimal(internal_fee_percent) if internal_fee_percent is not None else (fallback_fee or Decimal("0"))
        initial_external = Decimal(external_fee_percent) if external_fee_percent is not None else (fallback_fee or Decimal("0"))
        if agent_topup_profit_percent is not None:
            initial_agent_profit_internal = Decimal(agent_topup_profit_percent)
            initial_agent_profit_external = Decimal(agent_topup_profit_percent)
        else:
            initial_agent_profit_internal = Decimal(
                agent_topup_profit_internal_percent or Decimal("0")
            )
            initial_agent_profit_external = Decimal(
                agent_topup_profit_external_percent or Decimal("0")
            )
        rule = CommissionRule(
            role=role,
            internal_fee_percent=initial_internal,
            external_fee_percent=initial_external,
            treasury_to_accredited_fee_percent=Decimal(
                treasury_to_accredited_fee_percent or Decimal("0")
            ),
            treasury_to_agent_fee_percent=Decimal(
                treasury_to_agent_fee_percent or Decimal("0")
            ),
            treasury_collection_from_accredited_fee_percent=Decimal(
                treasury_collection_from_accredited_fee_percent or Decimal("0")
            ),
            treasury_collection_from_agent_fee_percent=Decimal(
                treasury_collection_from_agent_fee_percent or Decimal("0")
            ),
            agent_topup_profit_internal_percent=initial_agent_profit_internal,
            agent_topup_profit_external_percent=initial_agent_profit_external,
            agent_topup_profit_percent=initial_agent_profit_internal,
            is_active=True,
        )
        db.add(rule)

    db.commit()
    db.refresh(rule)
    return rule


def get_commission_percent(db: Session, role: UserRole) -> Decimal:
    # Backward compatible fallback used by old call sites.
    if role == UserRole.admin:
        return Decimal("0")

    rule = db.query(CommissionRule).filter(CommissionRule.role == role, CommissionRule.is_active == True).first()
    return Decimal(rule.internal_fee_percent) if rule else Decimal("0")


def get_commission_values(
    db: Session,
    role: UserRole,
    *,
    is_cross_country: bool,
    sender_profit_enabled: bool = False,
) -> tuple[Decimal, Decimal]:
    if role == UserRole.admin:
        return (Decimal("0"), Decimal("0"))

    rule = (
        db.query(CommissionRule)
        .filter(CommissionRule.role == role, CommissionRule.is_active == True)
        .first()
    )
    if not rule:
        return (Decimal("0"), Decimal("0"))

    commission_percent = (
        Decimal(rule.external_fee_percent)
        if is_cross_country
        else Decimal(rule.internal_fee_percent)
    )
    agent_profit_percent = (
        (
            Decimal(rule.agent_topup_profit_external_percent)
            if is_cross_country
            else Decimal(rule.agent_topup_profit_internal_percent)
        )
        if sender_profit_enabled
        else Decimal("0")
    )
    return (commission_percent, agent_profit_percent)


def list_commission_rules(db: Session) -> list[CommissionRule]:
    return db.query(CommissionRule).order_by(CommissionRule.role.asc()).all()


def get_treasury_funding_commission_percent(
    db: Session,
    destination_type: CashboxType,
) -> Decimal:
    admin_rule = (
        db.query(CommissionRule)
        .filter(CommissionRule.role == UserRole.admin, CommissionRule.is_active == True)
        .first()
    )
    if not admin_rule:
        return Decimal("0")

    if destination_type == CashboxType.agent:
        return Decimal(admin_rule.treasury_to_agent_fee_percent or 0)
    if destination_type == CashboxType.accredited:
        return Decimal(admin_rule.treasury_to_accredited_fee_percent or 0)
    return Decimal("0")


def get_treasury_collection_commission_percent(
    db: Session,
    source_type: CashboxType,
) -> Decimal:
    admin_rule = (
        db.query(CommissionRule)
        .filter(CommissionRule.role == UserRole.admin, CommissionRule.is_active == True)
        .first()
    )
    if not admin_rule:
        return Decimal("0")

    if source_type == CashboxType.agent:
        return Decimal(admin_rule.treasury_collection_from_agent_fee_percent or 0)
    if source_type == CashboxType.accredited:
        return Decimal(
            admin_rule.treasury_collection_from_accredited_fee_percent or 0
        )
    return Decimal("0")
