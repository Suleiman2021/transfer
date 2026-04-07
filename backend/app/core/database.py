from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings

_engine_kwargs = {
    "echo": settings.SQL_ECHO,
    "future": True,
}

if settings.DATABASE_URL.startswith("postgresql"):
    _engine_kwargs.update(
        {
            # Refresh broken idle connections before running queries.
            "pool_pre_ping": True,
            # Avoid keeping SSL connections longer than common network idle limits.
            "pool_recycle": 280,
            "pool_timeout": 30,
            "connect_args": {
                "connect_timeout": 10,
                "keepalives": 1,
                "keepalives_idle": 30,
                "keepalives_interval": 10,
                "keepalives_count": 5,
            },
        }
    )

engine = create_engine(settings.DATABASE_URL, **_engine_kwargs)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
