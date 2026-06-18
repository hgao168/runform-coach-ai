import os
from contextlib import contextmanager
from typing import Any

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker

_engine: Engine | None = None
_session_factory: sessionmaker[Session] | None = None


def _normalize_db_url(url: str) -> str:
    if url.startswith("postgres://"):
        return "postgresql://" + url[len("postgres://"):]
    return url


def get_database_url() -> str | None:
    raw = os.getenv("DATABASE_URL")
    return _normalize_db_url(raw) if raw else None


def get_engine() -> Engine | None:
    global _engine
    if _engine is not None:
        return _engine
    db_url = get_database_url()
    if not db_url:
        return None
    _engine = create_engine(db_url, pool_pre_ping=True)
    return _engine


def get_session_factory() -> sessionmaker[Session] | None:
    global _session_factory
    if _session_factory is not None:
        return _session_factory
    engine = get_engine()
    if engine is None:
        return None
    _session_factory = sessionmaker(bind=engine)
    return _session_factory


@contextmanager
def get_db_session():
    factory = get_session_factory()
    if factory is None:
        raise RuntimeError("DATABASE_URL is not configured.")
    session = factory()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def check_database() -> dict[str, Any]:
    engine = get_engine()
    if engine is None:
        return {"configured": False, "status": "not_configured"}
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return {"configured": True, "status": "ok"}
    except SQLAlchemyError as exc:
        return {"configured": True, "status": "error", "detail": str(exc)}


def ensure_auth_columns() -> None:
    """Idempotent: add auth columns to users table if they don't exist.

    Production DB was stamped with Alembic migration 20260612_0008 without
    the columns actually being created. This runs on every startup to
    guarantee the columns exist regardless of migration state.
    """
    engine = get_engine()
    if engine is None:
        return
    try:
        with engine.connect() as conn:
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS google_sub VARCHAR(255)"))
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (email)"))
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_google_sub ON users (google_sub)"))
            conn.commit()
    except SQLAlchemyError:
        # Non-fatal: tables may not exist yet (first deploy). Alembic migrations
        # will create them, and this will succeed on the next restart.
        pass
