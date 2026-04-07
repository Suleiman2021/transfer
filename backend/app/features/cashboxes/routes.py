from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.features.cashboxes.models import Cashbox
from app.features.cashboxes.schemas import CashboxResponse
from app.features.cashboxes.service import list_visible_cashboxes_for_user
from app.features.users.models import User, UserRole


router = APIRouter(prefix="/cashboxes", tags=["Cashboxes"])


@router.get("/", response_model=list[CashboxResponse])
def read_cashboxes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_visible_cashboxes_for_user(db, current_user)


@router.get("/my", response_model=list[CashboxResponse])
def read_my_cashboxes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role == UserRole.admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin manages the treasury and network, not a dedicated personal cashbox list",
        )

    cashboxes = (
        db.query(Cashbox)
        .filter(Cashbox.manager_user_id == current_user.id, Cashbox.is_active == True)
        .order_by(Cashbox.created_at.desc())
        .all()
    )
    return cashboxes
