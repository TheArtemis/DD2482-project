from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.responses import RedirectResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.schemas import (
    HealthResponse,
    LinkCreate,
    LinkResponse,
    LinkStats,
    VersionResponse,
)
from app.config import Settings, get_settings
from app.db.models import Link
from app.db.session import get_db
from app.services.links import create_link, disable_link, get_link, record_redirect

api_router = APIRouter()
redirect_router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


async def provide_settings() -> Settings:
    return get_settings()


AppSettings = Annotated[Settings, Depends(provide_settings)]


@api_router.post(
    "/links", response_model=LinkResponse, status_code=status.HTTP_201_CREATED
)
async def shorten_link(
    payload: LinkCreate,
    request: Request,
    session: DbSession,
    settings: AppSettings,
) -> LinkResponse:
    try:
        link = create_link(session, str(payload.destination_url), settings.code_length)
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="A short code could not be created",
        ) from exc

    return LinkResponse(
        code=link.code,
        destination_url=link.destination_url,
        short_url=str(request.base_url).rstrip("/") + f"/{link.code}",
        created_at=link.created_at,
    )


@api_router.get("/links/{code}/stats", response_model=LinkStats)
async def link_stats(code: str, session: DbSession) -> Link:
    link = get_link(session, code)
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Link not found"
        )
    return link


@api_router.delete("/links/{code}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_link(code: str, session: DbSession) -> Response:
    link = get_link(session, code, active_only=True)
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Link not found"
        )
    disable_link(session, link)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@api_router.get("/health/live", response_model=HealthResponse)
async def live() -> HealthResponse:
    return HealthResponse(status="ok")


@api_router.get("/health/ready", response_model=HealthResponse)
async def ready(session: DbSession) -> HealthResponse:
    try:
        session.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is unavailable",
        ) from exc
    return HealthResponse(status="ok")


@api_router.get("/version", response_model=VersionResponse)
async def version(settings: AppSettings) -> VersionResponse:
    return VersionResponse(version=settings.git_sha)


@redirect_router.get("/{code}", include_in_schema=False)
async def follow_link(code: str, session: DbSession) -> RedirectResponse:
    link = get_link(session, code, active_only=True)
    if link is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Link not found"
        )
    destination_url = link.destination_url
    record_redirect(session, link)
    return RedirectResponse(
        destination_url, status_code=status.HTTP_307_TEMPORARY_REDIRECT
    )
