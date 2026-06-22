"""Compute embeddings for all ingredients missing them (enables semantic RAG lookup)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sentence_transformers import SentenceTransformer  # noqa: E402

from app.core.config import settings                   # noqa: E402
from app.db.session import SessionLocal                # noqa: E402
from app.models.ingredient import Ingredient           # noqa: E402

BATCH = 256


def main() -> None:
    model = SentenceTransformer(settings.EMBEDDING_MODEL)
    db = SessionLocal()
    try:
        rows = db.query(Ingredient).filter(Ingredient.embedding.is_(None)).all()
        print(f"Embedding {len(rows)} ingredients...")
        for i in range(0, len(rows), BATCH):
            chunk = rows[i:i + BATCH]
            vectors = model.encode([r.name for r in chunk],
                                   normalize_embeddings=True)
            for row, vec in zip(chunk, vectors):
                row.embedding = vec.tolist()
            db.commit()
            print(f"  {min(i + BATCH, len(rows))}/{len(rows)}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
