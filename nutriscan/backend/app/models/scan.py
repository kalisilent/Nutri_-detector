import uuid
from datetime import datetime

from sqlalchemy import CHAR, DateTime, Float, ForeignKey, Index, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base


class Scan(Base):
    __tablename__ = "scans"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                          default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    image_url: Mapped[str | None] = mapped_column(String(1024))
    panel_type: Mapped[str] = mapped_column(String(20), default="unknown")
    grade: Mapped[str | None] = mapped_column(CHAR(1))            # a–e
    grade_confidence: Mapped[float | None] = mapped_column(Float)
    nutrients: Mapped[dict | None] = mapped_column(JSONB)         # extracted values
    ingredients: Mapped[list | None] = mapped_column(JSONB)       # matched list
    additives: Mapped[list | None] = mapped_column(JSONB)         # explained E-numbers
    raw_ocr: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True),
                                                 server_default=func.now())

    user = relationship("User", back_populates="scans")

    __table_args__ = (
        # History queries: "this user's scans, newest first" — composite index
        Index("ix_scans_user_created", "user_id", "created_at"),
    )
