from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.features.auth.schemas import LoginRequest, LoginResponse, MeResponse
from app.features.auth.service import login_admin_user, login_non_admin_user
from app.features.users.schemas import OwnPasswordChangeRequest, UserQrResolveResponse, UserResponse
from app.features.users.service import change_own_password, get_user_by_code
from app.features.users.models import User, UserRole


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    return login_non_admin_user(db, payload.username, payload.password)


@router.post("/admin/login", response_model=LoginResponse)
def admin_login(payload: LoginRequest, db: Session = Depends(get_db)):
    return login_admin_user(
        db,
        payload.username,
        payload.password,
    )


@router.get("/me", response_model=MeResponse)
def me(current_user: User = Depends(get_current_user)):
    return MeResponse(
        user_id=current_user.id,
        username=current_user.username,
        full_name=current_user.full_name,
        role=current_user.role,
        city=current_user.city,
        country=current_user.country,
        phone=current_user.phone,
    )


@router.patch("/me/password", response_model=MeResponse)
def change_password(
    payload: OwnPasswordChangeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = change_own_password(db, current_user, payload)
    return MeResponse(
        user_id=user.id,
        username=user.username,
        full_name=user.full_name,
        role=user.role,
        city=user.city,
        country=user.country,
        phone=user.phone,
    )


@router.get("/users/resolve-code", response_model=UserQrResolveResponse)
def resolve_user_code(
    code: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin accounts do not participate in QR-based transfers",
        )
    resolved = get_user_by_code(db, code)
    if resolved.role in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot resolve admin accounts via QR code",
        )
    return resolved
