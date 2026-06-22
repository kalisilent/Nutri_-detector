"""
Seed the ingredient knowledge base from notebook assets.
Run once after migrations:  python scripts/seed_kb.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings           # noqa: E402
from app.db.session import SessionLocal        # noqa: E402
from app.models.ingredient import Ingredient   # noqa: E402


def main() -> None:
    assets = Path(settings.ML_ASSETS_DIR)
    vocab = json.loads((assets / settings.VOCAB_FILE).read_text())

    db = SessionLocal()
    try:
        existing = {name for (name,) in db.query(Ingredient.name).all()}
        new_rows = [Ingredient(name=name, frequency=count)
                    for name, count in vocab.items() if name not in existing]
        db.add_all(new_rows)
        db.commit()
        print(f"Seeded {len(new_rows)} ingredients "
              f"({len(existing)} already present)")
    finally:
        db.close()

    print("Optional: run scripts/embed_kb.py to compute pgvector embeddings.")


if __name__ == "__main__":
    main()
