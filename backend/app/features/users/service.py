from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.features.risk.service import ensure_user_risk_profile
from app.features.users.models import User, UserRole
from app.features.users.schemas import UserCreateRequest


def create_user_by_admin(db: Session, data: UserCreateRequest, creator: User) -> User:
    if db.query(User).filter(User.username == data.username.strip().lower()).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username already exists")

    user = User(
        username=data.username.strip().lower(),
        full_name=data.full_name.strip(),
        role=data.role,
        city=data.city.strip().lower(),
        country=data.country.strip().lower(),
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
        )
    return query.all()


def deactivate_user_by_admin(db: Session, user_id, actor: User) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if user.role == UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Admin user cannot be deactivated",
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

    if user.role == UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Admin user cannot be activated from this endpoint",
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
