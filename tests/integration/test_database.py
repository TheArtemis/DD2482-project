from collections.abc import Iterator
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, select, text
from sqlalchemy.orm import sessionmaker

from app.config import get_settings
from app.db.models import Link
from app.services import links

pytestmark = pytest.mark.integration
PROJECT_ROOT = Path(__file__).parents[2]


@pytest.fixture
def migrated_database(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator:
    database_url = f"sqlite:///{tmp_path / 'integration.db'}"
    monkeypatch.setenv("DATABASE_URL", database_url)
    get_settings.cache_clear()

    alembic_config = Config(str(PROJECT_ROOT / "alembic.ini"))
    alembic_config.set_main_option("script_location", str(PROJECT_ROOT / "migrations"))
    command.upgrade(alembic_config, "head")

    engine = create_engine(database_url)
    session_factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    try:
        yield engine, session_factory
    finally:
        engine.dispose()
        get_settings.cache_clear()


def test_migration_creates_current_schema(migrated_database):
    engine, _ = migrated_database

    database_inspector = inspect(engine)
    assert set(database_inspector.get_table_names()) == {"alembic_version", "links"}
    assert {column["name"] for column in database_inspector.get_columns("links")} == {
        "id",
        "code",
        "destination_url",
        "created_at",
        "redirect_count",
        "is_active",
    }

    with engine.connect() as connection:
        revision = connection.execute(
            text("SELECT version_num FROM alembic_version")
        ).scalar_one()
    assert revision == "20260924_0001"


def test_link_lifecycle_persists_across_sessions(migrated_database):
    _, session_factory = migrated_database

    with session_factory() as session:
        created = links.create_link(session, "https://example.com/persisted", 7)
        code = created.code

    with session_factory() as session:
        stored = links.get_link(session, code, active_only=True)
        assert stored is not None
        assert stored.destination_url == "https://example.com/persisted"
        assert stored.redirect_count == 0
        links.record_redirect(session, stored)

    with session_factory() as session:
        stored = links.get_link(session, code, active_only=True)
        assert stored is not None
        assert stored.redirect_count == 1
        links.disable_link(session, stored)

    with session_factory() as session:
        assert links.get_link(session, code, active_only=True) is None
        disabled = links.get_link(session, code)
        assert disabled is not None
        assert disabled.is_active is False
        assert disabled.redirect_count == 1


def test_code_collision_rolls_back_and_retries(migrated_database, monkeypatch):
    _, session_factory = migrated_database

    with session_factory() as session:
        session.add(Link(code="duplicate", destination_url="https://example.com/one"))
        session.commit()

        generated_codes = iter(("duplicate", "available"))
        monkeypatch.setattr(
            links, "generate_code", lambda _length: next(generated_codes)
        )

        created = links.create_link(session, "https://example.com/two", 7)
        assert created.code == "available"
        assert session.scalars(select(Link).order_by(Link.id)).all() == [
            links.get_link(session, "duplicate"),
            created,
        ]


def test_redirect_updates_do_not_lose_stale_session_increments(migrated_database):
    _, session_factory = migrated_database

    with session_factory() as session:
        code = links.create_link(session, "https://example.com/counter", 7).code

    with session_factory() as first_session, session_factory() as second_session:
        first_copy = links.get_link(first_session, code)
        second_copy = links.get_link(second_session, code)
        assert first_copy is not None
        assert second_copy is not None
        assert first_copy.redirect_count == second_copy.redirect_count == 0

        links.record_redirect(first_session, first_copy)
        links.record_redirect(second_session, second_copy)

    with session_factory() as session:
        stored = links.get_link(session, code)
        assert stored is not None
        assert stored.redirect_count == 2
