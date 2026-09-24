import secrets
import string

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.models import Link

CODE_ALPHABET = string.ascii_letters + string.digits
MAX_CREATE_ATTEMPTS = 10


def generate_code(length: int) -> str:
    return "".join(secrets.choice(CODE_ALPHABET) for _ in range(length))


def create_link(session: Session, destination_url: str, code_length: int) -> Link:
    for _ in range(MAX_CREATE_ATTEMPTS):
        link = Link(code=generate_code(code_length), destination_url=destination_url)
        session.add(link)
        try:
            session.commit()
        except IntegrityError:
            session.rollback()
            continue
        session.refresh(link)
        return link
    raise RuntimeError("Could not allocate a unique short code")


def get_link(session: Session, code: str, *, active_only: bool = False) -> Link | None:
    statement = select(Link).where(Link.code == code)
    if active_only:
        statement = statement.where(Link.is_active.is_(True))
    return session.scalar(statement)


def record_redirect(session: Session, link: Link) -> None:
    session.execute(
        update(Link)
        .where(Link.id == link.id, Link.is_active.is_(True))
        .values(redirect_count=Link.redirect_count + 1)
    )
    session.commit()


def disable_link(session: Session, link: Link) -> None:
    link.is_active = False
    session.commit()
