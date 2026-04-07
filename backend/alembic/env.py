from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool

import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.config import settings
from app.core.database import Base

# Import model modules so metadata is fully registered
from app.features.cashboxes import models as cashboxes_models  # noqa: F401
from app.features.commissions import models as commissions_models  # noqa: F401
from app.features.transfers import models as transfers_models  # noqa: F401
from app.features.users import models as users_models  # noqa: F401
from app.features.risk import models as risk_models  # noqa: F401
from app.features.shifts import models as shifts_models  # noqa: F401
from app.features.ledger import models as ledger_models  # noqa: F401


config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=settings.DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = create_engine(settings.DATABASE_URL, poolclass=pool.NullPool)

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()


