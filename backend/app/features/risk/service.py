from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import and_, func
from sqlalchemy.orm import Session

from app.features.cashboxes.models import Cashbox
from app.features.risk.models import RiskAlert, RiskAlertSeverity, RiskProfile
from app.features.risk.schemas import RiskProfileUpsertRequest
from app.features.transfers.models import Transfer, TransferState
from app.features.users.models import User, UserRole


@dataclass
class RiskAlertDraft:
    code: str
    severity: RiskAlertSeverity
    message: str
    requires_review: bool
    weight: int


@dataclass
class RiskEvaluationResult:
    score: Decimal
    requires_review: bool
    alerts: list[RiskAlertDraft]


DEFAULT_RISK_SETTINGS = {
    UserRole.admin: {
        "daily_amount_limit": Decimal("100000000"),
        "daily_transfer_limit": 5000,
        "single_transfer_soft_limit": Decimal("10000000"),
        "single_transfer_hard_limit": Decimal("50000000"),
        "requires_review_for_cross_city": False,
    },
    UserRole.accredited: {
        "daily_amount_limit": Decimal("500000"),
        "daily_transfer_limit": 120,
        "single_transfer_soft_limit": Decimal("100000"),
        "single_transfer_hard_limit": Decimal("250000"),
        "requires_review_for_cross_city": True,
    },
    UserRole.agent: {
        "daily_amount_limit": Decimal("200000"),
        "daily_transfer_limit": 60,
        "single_transfer_soft_limit": Decimal("50000"),
        "single_transfer_hard_limit": Decimal("120000"),
        "requires_review_for_cross_city": True,
    },
}


def ensure_user_risk_profile(db: Session, user: User) -> RiskProfile:
    profile = db.query(RiskProfile).filter(RiskProfile.user_id == user.id).first()
    if profile:
        return profile

    defaults = DEFAULT_RISK_SETTINGS.get(user.role, DEFAULT_RISK_SETTINGS[UserRole.agent])
    profile = RiskProfile(user_id=user.id, **defaults)
    db.add(profile)
    db.flush()
    return profile


def ensure_default_risk_profiles(db: Session) -> None:
    users = db.query(User).all()
    for user in users:
        ensure_user_risk_profile(db, user)


def evaluate_transfer_risk(
    db: Session,
    performer: User,
    source: Cashbox,
    destination: Cashbox,
    amount: Decimal,
) -> RiskEvaluationResult:
    profile = ensure_user_risk_profile(db, performer)
    if not profile.is_active:
        return RiskEvaluationResult(score=Decimal("0"), requires_review=False, alerts=[])

    alerts: list[RiskAlertDraft] = []

    start_of_day = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)

    today_amount, today_count = (
        db.query(
            func.coalesce(func.sum(Transfer.amount), 0),
            func.count(Transfer.id),
        )
        .filter(
            and_(
                Transfer.performed_by_id == performer.id,
                Transfer.created_at >= start_of_day,
                Transfer.state == TransferState.completed,
            )
        )
        .one()
    )

    today_amount = Decimal(today_amount)
    today_count = int(today_count)

    if amount > Decimal(profile.single_transfer_hard_limit):
        alerts.append(
            RiskAlertDraft(
                code="SINGLE_HARD_LIMIT",
                severity=RiskAlertSeverity.high,
                message="Transfer exceeds single hard limit",
                requires_review=True,
                weight=45,
            )
        )
    elif amount > Decimal(profile.single_transfer_soft_limit):
        alerts.append(
            RiskAlertDraft(
                code="SINGLE_SOFT_LIMIT",
                severity=RiskAlertSeverity.medium,
                message="Transfer exceeds single soft limit",
                requires_review=False,
                weight=20,
            )
        )

    if today_count + 1 > int(profile.daily_transfer_limit):
        alerts.append(
            RiskAlertDraft(
                code="DAILY_COUNT_LIMIT",
                severity=RiskAlertSeverity.high,
                message="Daily transfer count limit exceeded",
                requires_review=True,
                weight=35,
            )
        )

    if today_amount + amount > Decimal(profile.daily_amount_limit):
        alerts.append(
            RiskAlertDraft(
                code="DAILY_AMOUNT_LIMIT",
                severity=RiskAlertSeverity.high,
                message="Daily transfer amount limit exceeded",
                requires_review=True,
                weight=40,
            )
        )

    if profile.requires_review_for_cross_city and source.city != destination.city:
        alerts.append(
            RiskAlertDraft(
                code="CROSS_CITY_PATTERN",
                severity=RiskAlertSeverity.medium,
                message="Cross-city transfer pattern detected",
                requires_review=True,
                weight=20,
            )
        )

    risk_score = Decimal(min(100, sum(a.weight for a in alerts))).quantize(Decimal("0.01"))
    requires_review = any(a.requires_review for a in alerts) or risk_score >= Decimal("70")

    return RiskEvaluationResult(score=risk_score, requires_review=requires_review, alerts=alerts)


def create_risk_alerts(
    db: Session,
    transfer_id: UUID,
    user_id: UUID,
    alerts: list[RiskAlertDraft],
) -> None:
    for alert in alerts:
        db.add(
            RiskAlert(
                transfer_id=transfer_id,
                user_id=user_id,
                code=alert.code,
                severity=alert.severity,
                message=alert.message,
                requires_review=alert.requires_review,
                resolved=False,
            )
        )


def resolve_transfer_alerts(db: Session, transfer_id: UUID) -> None:
    (
        db.query(RiskAlert)
        .filter(RiskAlert.transfer_id == transfer_id, RiskAlert.resolved == False)
        .update({RiskAlert.resolved: True}, synchronize_session=False)
    )


def list_profiles(db: Session) -> list[RiskProfile]:
    return db.query(RiskProfile).order_by(RiskProfile.updated_at.desc()).all()


def get_profile_by_user(db: Session, user_id: UUID) -> RiskProfile:
    profile = db.query(RiskProfile).filter(RiskProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Risk profile not found")
    return profile


def upsert_profile(db: Session, user_id: UUID, payload: RiskProfileUpsertRequest) -> RiskProfile:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    profile = ensure_user_risk_profile(db, user)

    if payload.daily_amount_limit is not None:
        profile.daily_amount_limit = payload.daily_amount_limit
    if payload.daily_transfer_limit is not None:
        profile.daily_transfer_limit = payload.daily_transfer_limit
    if payload.single_transfer_soft_limit is not None:
        profile.single_transfer_soft_limit = payload.single_transfer_soft_limit
    if payload.single_transfer_hard_limit is not None:
        profile.single_transfer_hard_limit = payload.single_transfer_hard_limit
    if payload.requires_review_for_cross_city is not None:
        profile.requires_review_for_cross_city = payload.requires_review_for_cross_city
    if payload.is_active is not None:
        profile.is_active = payload.is_active

    if Decimal(profile.single_transfer_hard_limit) < Decimal(profile.single_transfer_soft_limit):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="single_transfer_hard_limit must be >= single_transfer_soft_limit",
        )

    db.commit()
    db.refresh(profile)
    return profile


def list_alerts(db: Session, resolved: bool | None, limit: int = 200) -> list[RiskAlert]:
    query = db.query(RiskAlert).order_by(RiskAlert.created_at.desc())
    if resolved is not None:
        query = query.filter(RiskAlert.resolved == resolved)
    return query.limit(min(limit, 500)).all()
