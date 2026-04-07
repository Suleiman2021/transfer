from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.features.users.models import UserRole


class UserCreateRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    full_name: str = Field(min_length=3, max_length=120)
    role: UserRole
    city: str = Field(min_length=2, max_length=100)
    country: str = Field(min_length=2, max_length=100)
    password: str = Field(min_length=8, max_length=128)


class UserResponse(BaseModel):
    id: UUID
    username: str
    full_name: str
    role: UserRole
    city: str
    country: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
