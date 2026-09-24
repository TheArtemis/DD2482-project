import json
import logging
from pathlib import Path
from time import perf_counter
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, Response

from app.api.routes import api_router, redirect_router
from app.config import get_settings

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("url_shortener.requests")
settings = get_settings()
web_dir = Path(__file__).parent / "web"
index_html = (web_dir / "index.html").read_text(encoding="utf-8")
stylesheet = (web_dir / "static" / "styles.css").read_text(encoding="utf-8")
frontend_script = (web_dir / "static" / "app.js").read_text(encoding="utf-8")

app = FastAPI(
    title="URL Shortener",
    description="A small URL-shortening service with redirect statistics.",
    version=settings.git_sha,
)


@app.middleware("http")
async def request_logging(request: Request, call_next) -> Response:
    started = perf_counter()
    request_id = request.headers.get("x-request-id", str(uuid4()))
    response_status = 500
    try:
        response = await call_next(request)
        response_status = response.status_code
        response.headers["x-request-id"] = request_id
        return response
    finally:
        route = request.scope.get("route")
        route_path = getattr(route, "path", "unmatched")
        logger.info(
            json.dumps(
                {
                    "event": "http_request",
                    "method": request.method,
                    "route": route_path,
                    "status_code": response_status,
                    "duration_ms": round((perf_counter() - started) * 1000, 2),
                    "request_id": request_id,
                    "version": settings.git_sha,
                }
            )
        )


@app.get("/", include_in_schema=False)
async def home() -> HTMLResponse:
    return HTMLResponse(index_html)


@app.get("/static/styles.css", include_in_schema=False)
async def styles() -> Response:
    return Response(stylesheet, media_type="text/css")


@app.get("/static/app.js", include_in_schema=False)
async def browser_app() -> Response:
    return Response(frontend_script, media_type="text/javascript")


app.include_router(api_router)
# This catch-all redirect route must remain last so it cannot shadow API/UI routes.
app.include_router(redirect_router)
