from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.features.users.models import UserRole


class UserCreateRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    full_name: str = Field(min_length=3, max_length=120)
    role: UserRole
    city: str = Field(min_length=2, max_length=100)
    country: str = Field(min_length=2, max_length=100)
    phone: str | None = Field(default=None, max_length=40)
    password: str = Field(min_length=8, max_length=128)


class UserUpdateRequest(BaseModel):
    username: str | None = Field(default=None, min_length=3, max_length=50)
    full_name: str | None = Field(default=None, min_length=3, max_length=120)
    city: str | None = Field(default=None, min_length=2, max_length=100)
    country: str | None = Field(default=None, min_length=2, max_length=100)
    phone: str | None = Field(default=None, max_length=40)


class UserPasswordResetRequest(BaseModel):
    password: str = Field(min_length=8, max_length=128)


class OwnPasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    full_name: str
    role: UserRole
    city: str
    country: str
    phone: str | None = None
    is_active: bool
    created_at: datetime


class UserQrResolveResponse(BaseModel):
    """Limited user info returned when resolving a QR code — excludes admin fields."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    username: str
    full_name: str
    role: UserRole
    city: str
    country: str
    phone: str | None = None
    is_active: bool
    created_at: datetime
