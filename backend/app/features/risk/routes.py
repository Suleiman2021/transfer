from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_roles
from app.features.risk.schemas import RiskAlertResponse, RiskProfileResponse, RiskProfileUpsertRequest
from app.features.risk.service import get_profile_by_user, list_alerts, list_profiles, upsert_profile
from app.features.users.models import User, UserRole


router = APIRouter(prefix="/risk", tags=["Risk"])


@router.get("/profiles", response_model=list[RiskProfileResponse])
def read_profiles(
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return list_profiles(db)


@router.get("/profiles/{user_id}", response_model=RiskProfileResponse)
def read_profile(
    user_id: UUID,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return get_profile_by_user(db, user_id)


@router.put("/profiles/{user_id}", response_model=RiskProfileResponse)
def update_profile(
    user_id: UUID,
    payload: RiskProfileUpsertRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return upsert_profile(db, user_id, payload)


@router.get("/alerts", response_model=list[RiskAlertResponse])
def read_alerts(
    resolved: bool | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=500),
    db: Session = Depends(get_db),
    current_admin: User = Depends(require_roles(UserRole.admin)),
):
    return list_alerts(db, resolved, limit)


@router.get("/me", response_model=RiskProfileResponse)
def read_my_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_profile_by_user(db, current_user.id)
