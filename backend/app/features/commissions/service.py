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
    treasury_to_agent_internal_fee_percent: Decimal | None = None,
    treasury_to_agent_external_fee_percent: Decimal | None = None,
    treasury_to_accredited_internal_fee_percent: Decimal | None = None,
    treasury_to_accredited_external_fee_percent: Decimal | None = None,
    remittance_treasury_percent: Decimal | None = None,
    remittance_sender_percent: Decimal | None = None,
    remittance_receiver_percent: Decimal | None = None,
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
        if treasury_to_agent_internal_fee_percent is not None:
            rule.treasury_to_agent_internal_fee_percent = Decimal(treasury_to_agent_internal_fee_percent)
        if treasury_to_agent_external_fee_percent is not None:
            rule.treasury_to_agent_external_fee_percent = Decimal(treasury_to_agent_external_fee_percent)
        if treasury_to_accredited_internal_fee_percent is not None:
            rule.treasury_to_accredited_internal_fee_percent = Decimal(treasury_to_accredited_internal_fee_percent)
        if treasury_to_accredited_external_fee_percent is not None:
            rule.treasury_to_accredited_external_fee_percent = Decimal(treasury_to_accredited_external_fee_percent)
        if remittance_treasury_percent is not None:
            rule.remittance_treasury_percent = Decimal(remittance_treasury_percent)
        if remittance_sender_percent is not None:
            rule.remittance_sender_percent = Decimal(remittance_sender_percent)
        if remittance_receiver_percent is not None:
            rule.remittance_receiver_percent = Decimal(remittance_receiver_percent)

        rule.is_active = True
    else:
        initial_internal = Decimal(internal_fee_percent) if internal_fee_percent is not None else (fallback_fee or Decimal("0"))
        initial_external = Decimal(external_fee_percent) if external_fee_percent is not None else (fallback_fee or Decimal("0"))
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
            treasury_to_agent_internal_fee_percent=Decimal(treasury_to_agent_internal_fee_percent or Decimal("0")),
            treasury_to_agent_external_fee_percent=Decimal(treasury_to_agent_external_fee_percent or Decimal("0")),
            treasury_to_accredited_internal_fee_percent=Decimal(treasury_to_accredited_internal_fee_percent or Decimal("0")),
            treasury_to_accredited_external_fee_percent=Decimal(treasury_to_accredited_external_fee_percent or Decimal("0")),
            remittance_treasury_percent=Decimal(remittance_treasury_percent or Decimal("0")),
            remittance_sender_percent=Decimal(remittance_sender_percent or Decimal("0")),
            remittance_receiver_percent=Decimal(remittance_receiver_percent or Decimal("0")),
            is_active=True,
        )
        db.add(rule)

    db.commit()
    db.refresh(rule)
    return rule


def list_commission_rules(db: Session) -> list[CommissionRule]:
    return db.query(CommissionRule).order_by(CommissionRule.role.asc()).all()


def get_treasury_funding_commission_percent(
    db: Session,
    destination_type: CashboxType,
    *,
    is_cross_country: bool = False,
) -> Decimal:
    admin_rule = (
        db.query(CommissionRule)
        .filter(CommissionRule.role == UserRole.admin, CommissionRule.is_active == True)
        .first()
    )
    if not admin_rule:
        return Decimal("0")

    if destination_type == CashboxType.agent:
        if is_cross_country:
            return Decimal(admin_rule.treasury_to_agent_external_fee_percent or 0)
        return Decimal(admin_rule.treasury_to_agent_internal_fee_percent or 0)
    if destination_type == CashboxType.accredited:
        if is_cross_country:
            return Decimal(admin_rule.treasury_to_accredited_external_fee_percent or 0)
        return Decimal(admin_rule.treasury_to_accredited_internal_fee_percent or 0)
    return Decimal("0")


def get_remittance_commission_percents(db: Session) -> tuple[Decimal, Decimal, Decimal]:
    """Returns (treasury_percent, sender_percent, receiver_percent) for remittances."""
    admin_rule = (
        db.query(CommissionRule)
        .filter(CommissionRule.role == UserRole.admin, CommissionRule.is_active == True)
        .first()
    )
    if not admin_rule:
        return (Decimal("0"), Decimal("0"), Decimal("0"))
    return (
        Decimal(admin_rule.remittance_treasury_percent or 0),
        Decimal(admin_rule.remittance_sender_percent or 0),
        Decimal(admin_rule.remittance_receiver_percent or 0),
    )


