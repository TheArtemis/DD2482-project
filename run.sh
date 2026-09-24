#!/usr/bin/env bash

set -Eeuo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

if [[ -f "$project_dir/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$project_dir/.env"
    set +a
fi

if command -v uv >/dev/null 2>&1; then
    uv_command="$(command -v uv)"
elif [[ -x "$project_dir/.venv/bin/uv" ]]; then
    uv_command="$project_dir/.venv/bin/uv"
else
    echo "Error: uv is required. Install it from https://docs.astral.sh/uv/." >&2
    exit 1
fi

export UV_CACHE_DIR="${UV_CACHE_DIR:-$project_dir/.cache/uv}"
export DATABASE_URL="${DATABASE_URL:-sqlite:///$project_dir/url_shortener.db}"

app_host="${APP_HOST:-127.0.0.1}"
app_port="${APP_PORT:-8000}"
server_args=(
    app.main:app
    --host "$app_host"
    --port "$app_port"
)

if [[ "${APP_RELOAD:-0}" == "1" ]]; then
    server_args+=(--reload)
fi

echo "Synchronizing Python dependencies..."
"$uv_command" sync --locked

echo "Applying database migrations..."
"$uv_command" run --locked --no-sync alembic upgrade head

echo "Starting Snip at http://$app_host:$app_port"
echo "The frontend and API are served by the same process. Press Ctrl+C to stop."
exec "$uv_command" run --locked --no-sync uvicorn "${server_args[@]}"
