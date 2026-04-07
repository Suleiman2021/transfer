from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings


BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 120
    SQL_ECHO: bool = False

    COMPANY_NAME: str = "Cashbox Transfer Network"

    BOOTSTRAP_ADMIN_USERNAME: str = "admin"
    BOOTSTRAP_ADMIN_PASSWORD: str = "Admin@12345"
    BOOTSTRAP_ADMIN_FULL_NAME: str = "System Administrator"
    BOOTSTRAP_ADMIN_CITY: str = "damascus"
    BOOTSTRAP_ADMIN_COUNTRY: str = "سوريا"
    BOOTSTRAP_TREASURY_NAME: str = "الخزنة المركزية"

    FORCE_REBUILD_SCHEMA: bool = False
    AUTO_RESET_SCHEMA_ON_MISMATCH: bool = False

    class Config:
        env_file = BASE_DIR / ".env"
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
