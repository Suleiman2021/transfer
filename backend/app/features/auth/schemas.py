from uuid import UUID

from pydantic import BaseModel, Field

from app.features.users.models import UserRole


class LoginRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=8, max_length=128)


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: UUID
    full_name: str
    role: UserRole
    city: str
    country: str


class MeResponse(BaseModel):
    user_id: UUID
    username: str
    full_name: str
    role: UserRole
    city: str
    country: str
