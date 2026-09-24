from datetime import datetime

from pydantic import BaseModel, ConfigDict, HttpUrl


class LinkCreate(BaseModel):
    destination_url: HttpUrl


class LinkResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    destination_url: str
    short_url: str
    created_at: datetime


class LinkStats(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    destination_url: str
    created_at: datetime
    redirect_count: int
    is_active: bool


class VersionResponse(BaseModel):
    version: str


class HealthResponse(BaseModel):
    status: str
