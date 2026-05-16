"""
Shared pytest fixtures for the RunForm backend tests.
"""

import os

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.db as db_mod
from app.db_models import Base, User

_test_engine = None
_test_session_factory: sessionmaker[Session] | None = None


def _setup_test_db():
    """Create SQLite in-memory database with all tables for testing."""
    global _test_engine, _test_session_factory
    if _test_engine is not None:
        return
    _test_engine = create_engine(
        "sqlite://", echo=False, connect_args={"check_same_thread": False}
    )
    _test_session_factory = sessionmaker(bind=_test_engine, class_=Session, autocommit=False, autoflush=False)
    Base.metadata.create_all(_test_engine)
    # Override the db module's engine/factory so all code uses test DB
    db_mod._engine = _test_engine
    db_mod._session_factory = _test_session_factory
    # Set DATABASE_URL env so checks pass
    os.environ.setdefault("DATABASE_URL", "sqlite://")


@pytest.fixture
def _db_setup():
    """Ensure test database is set up once per session."""
    _setup_test_db()


@pytest.fixture
def test_user(_db_setup):
    """Create a test user and return its ios_user_id."""
    with _test_session_factory() as sess:
        user = User(ios_user_id="test-user-001")
        sess.add(user)
        sess.commit()
        uid = user.ios_user_id
    return uid


@pytest.fixture
def test_user_id(_db_setup) -> int:
    """Return the database ID of the test user."""
    with _test_session_factory() as sess:
        user = sess.query(User).filter(User.ios_user_id == "test-user-001").first()
        if user is None:
            user = User(ios_user_id="test-user-001")
            sess.add(user)
            sess.commit()
        return user.id


from app.main import app


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


@pytest.fixture
async def client(_db_setup):
    """Return an httpx AsyncClient bound to the FastAPI app."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
