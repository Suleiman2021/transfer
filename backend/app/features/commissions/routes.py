from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_roles
from app.features.commissions.schemas import CommissionRuleResponse, CommissionRuleUpsertRequest
from app.features.commissions.service import list_commission_rules, upsert_commission_rule
from app.features.users.models import User, UserRole


router = APIRouter(prefix="/commissions", tags=["Commissions"])


@router.get("/", response_model=list[CommissionRuleResponse])
def read_commissions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_commission_rules(db)


@router.post("/", response_model=CommissionRuleResponse)
def save_commission(
    payload: CommissionRuleUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.admin)),
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
