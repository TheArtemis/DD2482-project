import os
from functools import lru_cache

from pydantic import BaseModel, Field


class Settings(BaseModel):
    database_url: str = Field(
        default_factory=lambda: os.getenv(
            "DATABASE_URL", "sqlite:///./url_shortener.db"
        )
    )
    git_sha: str = Field(default_factory=lambda: os.getenv("GIT_SHA", "development"))
    code_length: int = Field(
        default_factory=lambda: int(os.getenv("CODE_LENGTH", "7")), ge=4, le=32
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
