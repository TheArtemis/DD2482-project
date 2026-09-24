# Snip — URL shortener

A small but complete URL-shortening application built with FastAPI, SQLAlchemy,
Alembic, uv, and a dependency-free browser frontend.

## Run locally

[Install uv](https://docs.astral.sh/uv/getting-started/installation/). The project
requires Python 3.12 or newer; uv creates and maintains the local `.venv`.

```bash
./run.sh
```

Open <http://localhost:8000>. Interactive API documentation is available at
<http://localhost:8000/docs>.

The script synchronizes locked dependencies, applies database migrations, and
starts the backend and frontend together. It uses a local SQLite database by
default. Press `Ctrl+C` to stop the application.

Copy `.env.example` to `.env` to configure the host, port, reload behavior,
database URL, or displayed version. The `.env` file is ignored by Git.

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/links` | Create a short link |
| `GET` | `/{code}` | Redirect and increment the counter |
| `GET` | `/links/{code}/stats` | Read link statistics |
| `DELETE` | `/links/{code}` | Disable a short link |
| `GET` | `/health/live` | Process liveness |
| `GET` | `/health/ready` | Database readiness |
| `GET` | `/version` | Deployed Git SHA/version |

Example:

```bash
curl -sS http://localhost:8000/links \
  -H 'content-type: application/json' \
  -d '{"destination_url":"https://example.com/a/long/path"}'
```

Deleting a link disables its redirect while retaining its statistics. The API
emits structured request logs and returns an `x-request-id` response header.

## Local development

Set `DATABASE_URL` to use an existing PostgreSQL server instead of SQLite, or
override the listener with `APP_HOST` and `APP_PORT`. Enable automatic reload
during development with `APP_RELOAD=1 ./run.sh`.

The equivalent individual commands are:

```bash
uv sync --locked
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

Run quality checks with:

```bash
uv run pytest
uv run ruff check .
uv run ruff format --check .
uv run ty check
```

Run only the migration and database integration tests with:

```bash
uv run pytest -m integration
```

Runtime and development dependencies are declared in `pyproject.toml` and
resolved reproducibly by the committed `uv.lock`. Use `uv add <package>` for a
runtime dependency or `uv add --dev <package>` for a development dependency.

## Layout

- `app/api`: HTTP routes and request/response models
- `app/db`: SQLAlchemy model and session setup
- `app/services`: short-code and link business logic
- `app/web`: responsive HTML/CSS/JavaScript frontend
- `migrations`: Alembic database migrations
- `tests`: unit and API tests
- `run.sh`: local dependency, migration, and application launcher
