import uuid

from pgvector.sqlalchemy import Vector
from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base_class import Base

EMBEDDING_DIM = 384  # all-MiniLM-L6-v2


class Ingredient(Base):
    __tablename__ = "ingredients"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                          default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    e_number: Mapped[str | None] = mapped_column(String(10), index=True)
    frequency: Mapped[int] = mapped_column(Integer, default=0)   # occurrences in OFF dataset
    embedding: Mapped[list[float] | None] = mapped_column(Vector(EMBEDDING_DIM))

    explanation = relationship("IngredientExplanation", back_populates="ingredient",
                               uselist=False, cascade="all, delete-orphan")


class IngredientExplanation(Base):
    __tablename__ = "ingredient_explanations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                          default=uuid.uuid4)
    ingredient_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("ingredients.id", ondelete="CASCADE"),
        unique=True, nullable=False)
    what: Mapped[str] = mapped_column(Text, nullable=False)
    safety: Mapped[str | None] = mapped_column(Text)
    source: Mapped[str] = mapped_column(String(50), default="curated")  # curated|llm

    ingredient = relationship("Ingredient", back_populates="explanation")
