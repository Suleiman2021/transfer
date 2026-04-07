from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.features.auth.schemas import LoginRequest, LoginResponse, MeResponse
from app.features.auth.service import login_admin_user, login_non_admin_user
from app.features.users.models import User


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
    )
