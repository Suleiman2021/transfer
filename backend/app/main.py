from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware

from app.core.bootstrap import bootstrap_system
from app.core.config import settings
from app.features.admin.routes import router as admin_router
from app.features.auth.routes import router as auth_router
from app.features.cashboxes.routes import router as cashboxes_router
from app.features.commissions.routes import router as commissions_router
from app.features.ledger.routes import router as ledger_router
from app.features.risk.routes import router as risk_router
from app.features.shifts.routes import router as shifts_router
from app.features.transfers.routes import router as transfers_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    bootstrap_system()
    yield


app = FastAPI(
    title=f"{settings.COMPANY_NAME} API",
    description="Feature-based remittance system for a single-company cashbox network",
    version="2.3.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins,
    allow_credentials=settings.effective_cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(cashboxes_router)
app.include_router(commissions_router)
app.include_router(transfers_router)
app.include_router(risk_router)
app.include_router(shifts_router)
app.include_router(ledger_router)


@app.get("/")
def root():
    return {
        "service": settings.COMPANY_NAME,
        "status": "running",
        "architecture": "feature-based",
        "notes": [
            "Self-registration is disabled",
            "Only admins can create users and cashboxes",
            "Treasury is managed by the admin and can fund or collect from the network",
            "Accredited users can manage multiple cashboxes and transfer between accredited cashboxes",
            "Agents operate as intermediaries with their own cashboxes and commissions",
            "Top-up requests can wait for agent or admin approval",
            "Double-entry ledger posting is enabled for completed transfers",
        ],
    }


@app.head("/", include_in_schema=False)
def root_head():
    return Response(status_code=200)


@app.api_route("/healthz", methods=["GET", "HEAD"])
def healthz():
    return {"status": "ok"}
