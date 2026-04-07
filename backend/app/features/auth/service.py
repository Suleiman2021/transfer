from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import create_access_token, verify_password
from app.features.auth.schemas import LoginResponse
from app.features.users.models import User, UserRole


def _authenticate_user(db: Session, username: str, password: str) -> User:
    user = db.query(User).filter(User.username == username.strip().lower()).first()

    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is inactive")

    return user


def _build_login_response(user: User) -> LoginResponse:
    token = create_access_token(subject=str(user.id), role=user.role.value)
    return LoginResponse(
        access_token=token,
        user_id=user.id,
        full_name=user.full_name,
        role=user.role,
        city=user.city,
        country=user.country,
    )


def login_non_admin_user(db: Session, username: str, password: str) -> LoginResponse:
    user = _authenticate_user(db, username, password)

    if user.role == UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin must use /auth/admin/login endpoint",
        )

    return _build_login_response(user)


def login_admin_user(
    db: Session,
    username: str,
    password: str,
) -> LoginResponse:
    user = _authenticate_user(db, username, password)

    if user.role != UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admin can use /auth/admin/login endpoint",
        )

    return _build_login_response(user)
