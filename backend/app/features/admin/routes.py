from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_roles
from app.features.admin.schemas import UserReportResponse
from app.features.admin.service import get_user_report
from app.features.cashboxes.schemas import CashboxCreateRequest, CashboxResponse, CashboxUpdateRequest
from app.features.cashboxes.service import create_cashbox, list_cashboxes, update_cashbox_by_admin
from app.features.commissions.schemas import CommissionRuleResponse, CommissionRuleUpsertRequest
from app.features.commissions.service import list_commission_rules, upsert_commission_rule
from app.features.users.models import User, UserRole
from app.features.users.schemas import UserCreateRequest, UserPasswordResetRequest, UserResponse, UserUpdateRequest
from app.features.users.service import (
    activate_user_by_admin,
    create_user_by_admin,
    deactivate_user_by_admin,
    list_users,
    reset_user_password_by_admin,
    update_user_by_admin,
)


router = APIRouter(prefix="/admin", tags=["Admin"])


@router.post("/users", response_model=UserResponse)
def admin_create_user(
    payload: UserCreateRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return create_user_by_admin(db, payload, current_admin)


@router.get("/users", response_model=list[UserResponse])
def admin_list_users(
    role: UserRole | None = Query(default=None),
    search: str | None = Query(default=None, min_length=1, max_length=120),
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return list_users(db, role, search)


@router.patch("/users/{user_id}", response_model=UserResponse)
def admin_update_user(
    user_id: UUID,
    payload: UserUpdateRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return update_user_by_admin(db, user_id, payload, current_admin)


@router.patch("/users/{user_id}/password", response_model=UserResponse)
def admin_reset_user_password(
    user_id: UUID,
    payload: UserPasswordResetRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return reset_user_password_by_admin(db, user_id, payload, current_admin)


@router.delete("/users/{user_id}", response_model=UserResponse)
def admin_deactivate_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return deactivate_user_by_admin(db, user_id, current_admin)


@router.post("/users/{user_id}/activate", response_model=UserResponse)
def admin_activate_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return activate_user_by_admin(db, user_id, current_admin)


@router.get("/users/{user_id}/report", response_model=UserReportResponse)
def admin_user_report(
    user_id: UUID,
    limit: int = Query(default=200, ge=1, le=300),
    from_date: date | None = Query(default=None),
    to_date: date | None = Query(default=None),
    limit_days: int = Query(default=45, ge=1, le=180),
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return get_user_report(
        db,
        user_id,
        from_date=from_date,
        to_date=to_date,
        limit=limit,
        limit_days=limit_days,
    )


@router.post("/cashboxes", response_model=CashboxResponse)
def admin_create_cashbox(
    payload: CashboxCreateRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return create_cashbox(db, payload, current_admin)


@router.get("/cashboxes", response_model=list[CashboxResponse])
def admin_list_cashboxes(
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return list_cashboxes(db, only_active=False)


@router.patch("/cashboxes/{cashbox_id}", response_model=CashboxResponse)
def admin_update_cashbox(
    cashbox_id: UUID,
    payload: CashboxUpdateRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return update_cashbox_by_admin(db, cashbox_id, payload, current_admin)


@router.post("/commissions", response_model=CommissionRuleResponse)
def admin_upsert_commission(
    payload: CommissionRuleUpsertRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return upsert_commission_rule(
        db,
        payload.role,
        internal_fee_percent=payload.internal_fee_percent,
        external_fee_percent=payload.external_fee_percent,
        treasury_to_accredited_fee_percent=payload.treasury_to_accredited_fee_percent,
        treasury_to_agent_fee_percent=payload.treasury_to_agent_fee_percent,
        treasury_collection_from_accredited_fee_percent=payload.treasury_collection_from_accredited_fee_percent,
        treasury_collection_from_agent_fee_percent=payload.treasury_collection_from_agent_fee_percent,
        agent_topup_profit_internal_percent=payload.agent_topup_profit_internal_percent,
        agent_topup_profit_external_percent=payload.agent_topup_profit_external_percent,
        agent_topup_profit_percent=payload.agent_topup_profit_percent,
        legacy_fee_percent=payload.fee_percent,
    )


@router.get("/commissions", response_model=list[CommissionRuleResponse])
def admin_list_commissions(
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return list_commission_rules(db)
