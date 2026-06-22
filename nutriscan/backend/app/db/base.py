"""Aggregates all ORM models so Alembic's autogenerate sees them.
Import this module (not base_class) from alembic/env.py."""
from app.db.base_class import Base                          # noqa: F401
from app.models.user import User                            # noqa: F401
from app.models.scan import Scan                            # noqa: F401
from app.models.ingredient import (                         # noqa: F401
    Ingredient, IngredientExplanation,
)
from app.models.saved_product import SavedProduct           # noqa: F401
