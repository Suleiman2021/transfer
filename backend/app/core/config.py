from functools import lru_cache
from pathlib import Path

from pydantic import ConfigDict
from pydantic_settings import BaseSettings


BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = ConfigDict(env_file=BASE_DIR / ".env", extra="ignore")

    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 120
    SQL_ECHO: bool = False
    CORS_ALLOW_ORIGINS: str = "*"
    CORS_ALLOW_CREDENTIALS: bool = True

    COMPANY_NAME: str = "Cashbox Transfer Network"

    BOOTSTRAP_ADMIN_USERNAME: str = "admin"
    # No insecure default: the bootstrap admin password must be provided via the
    # environment (.env). An empty value disables seeding a default admin.
    BOOTSTRAP_ADMIN_PASSWORD: str = ""
    BOOTSTRAP_ADMIN_FULL_NAME: str = "System Administrator"
    BOOTSTRAP_ADMIN_CITY: str = "damascus"
    BOOTSTRAP_ADMIN_COUNTRY: str = "سوريا"
    BOOTSTRAP_TREASURY_NAME: str = "الخزنة المركزية"

    FORCE_REBUILD_SCHEMA: bool = False
    AUTO_RESET_SCHEMA_ON_MISMATCH: bool = False

    @property
    def cors_allow_origins(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.CORS_ALLOW_ORIGINS.split(",")
            if origin.strip()
        ] or ["*"]

    @property
    def effective_cors_allow_credentials(self) -> bool:
        # The CORS spec forbids credentials with a wildcard origin.
        # Browsers reject such responses, so disable credentials silently.
        if "*" in self.cors_allow_origins:
            return False
        return self.CORS_ALLOW_CREDENTIALS


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
