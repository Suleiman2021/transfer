from fastapi import HTTPException, status
from sqlalchemy import String, cast
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.features.risk.service import ensure_user_risk_profile
from app.features.users.models import User, UserRole
from app.features.users.schemas import (
    OwnPasswordChangeRequest,
    UserCreateRequest,
    UserPasswordResetRequest,
    UserUpdateRequest,
)


def _normalize_phone(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    return normalized or None


def create_user_by_admin(db: Session, data: UserCreateRequest, creator: User) -> User:
    if data.role == UserRole.super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Super admin role cannot be assigned via this endpoint",
        )

    if db.query(User).filter(User.username == data.username.strip().lower()).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already exists")

    user = User(
        username=data.username.strip().lower(),
        full_name=data.full_name.strip(),
        role=data.role,
        city=data.city.strip().lower(),
        country=data.country.strip().lower(),
        phone=_normalize_phone(data.phone),
        password_hash=hash_password(data.password),
        created_by_id=creator.id,
        is_active=True,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    ensure_user_risk_profile(db, user)
    db.commit()
    db.refresh(user)

    return user


def list_users(
    db: Session,
    role: UserRole | None = None,
    search: str | None = None,
) -> list[User]:
    query = db.query(User).order_by(User.created_at.desc())
    if role:
        query = query.filter(User.role == role)
    if search:
        term = f"%{search.strip().lower()}%"
        query = query.filter(
            (User.username.ilike(term))
            | (User.full_name.ilike(term))
            | (User.city.ilike(term))
            | (User.country.ilike(term))
            | (User.phone.ilike(term))
        )
    return query.all()


def get_user_by_code(db: Session, code: str) -> User:
    normalized = code.strip()
    for prefix in ("radical-transfer:user:", "user:"):
        if normalized.startswith(prefix):
            normalized = normalized[len(prefix):]
            break

    user = (
        db.query(User)
        .filter((cast(User.id, String) == normalized) | (User.username == normalized.lower()))
        .first()
    )

    if not user:
        user = (
            db.query(User)
            .filter(User.full_name.ilike(normalized))
            .first()
        )

    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def update_user_by_admin(db: Session, user_id, data: UserUpdateRequest, actor: User) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if data.username is not None:
        username = data.username.strip().lower()
        exists = db.query(User).filter(User.username == username, User.id != user.id).first()
        if exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already exists")
        user.username = username
    if data.full_name is not None:
        user.full_name = data.full_name.strip()
    if data.city is not None:
        user.city = data.city.strip().lower()
    if data.country is not None:
        user.country = data.country.strip().lower()
    if data.phone is not None:
        user.phone = _normalize_phone(data.phone)

    db.commit()
    db.refresh(user)
    return user


def reset_user_password_by_admin(
    db: Session,
    user_id,
    data: UserPasswordResetRequest,
    actor: User,
) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.password_hash = hash_password(data.password)
    db.commit()
    db.refresh(user)
    return user


def change_own_password(db: Session, user: User, data: OwnPasswordChangeRequest) -> User:
    if not verify_password(data.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    user.password_hash = hash_password(data.new_password)
    db.commit()
    db.refresh(user)
    return user


def deactivate_user_by_admin(db: Session, user_id, actor: User) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if user.role == UserRole.super_admin:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Super admin cannot be deactivated",
        )

    # Regular admins can only be deactivated by super_admin
    if user.role == UserRole.admin and actor.role != UserRole.super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only super admin can deactivate admin users",
        )

    if user.id == actor.id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="You cannot deactivate your own account",
        )

    if not user.is_active:
        return user

    user.is_active = False
    db.commit()
    db.refresh(user)
    return user


def activate_user_by_admin(db: Session, user_id, actor: User) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if user.role == UserRole.super_admin:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Super admin status cannot be changed from this endpoint",
        )

    # Regular admins can only be activated by super_admin
    if user.role == UserRole.admin and actor.role != UserRole.super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only super admin can activate admin users",
        )

    if user.id == actor.id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="You cannot activate your own account from this endpoint",
        )

    if user.is_active:
        return user

    user.is_active = True
    db.commit()
    db.refresh(user)
    return user
