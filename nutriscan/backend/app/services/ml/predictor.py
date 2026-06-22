"""
ML serving: loads the LightGBM classifier + ingredient vocabulary at startup,
serves grade predictions and fuzzy ingredient matching.

Assets produced by the training notebook live in ml_assets/:
  - health_classifier.pkl
  - ingredient_vocab.json
  - additives_kb.csv
"""
import json
from pathlib import Path

import joblib
import pandas as pd
from rapidfuzz import fuzz, process

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger("ml")

NUTRIENT_COLS = ["energy_100g", "fat_100g", "saturated-fat_100g",
                 "carbohydrates_100g", "sugars_100g", "fiber_100g",
                 "proteins_100g", "salt_100g", "sodium_100g", "additives_n"]

GRADE_LABELS = {"a": "HEALTHY", "b": "GOOD", "c": "MODERATE",
                "d": "POOR", "e": "UNHEALTHY"}


class ModelService:
    """Singleton holding all ML assets. Load once per container."""

    _instance: "ModelService | None" = None

    def __init__(self) -> None:
        assets = Path(settings.ML_ASSETS_DIR)
        self.model = joblib.load(assets / settings.MODEL_FILE)
        self.vocab: dict[str, int] = json.loads(
            (assets / settings.VOCAB_FILE).read_text())
        self.vocab_list = list(self.vocab.keys())
        self.additives_kb = pd.read_csv(assets / settings.ADDITIVES_FILE)
        self.model_version = (assets / "VERSION").read_text().strip() \
            if (assets / "VERSION").exists() else "1.0.0"
        logger.info("ml_assets_loaded",
                    vocab_size=len(self.vocab_list),
                    additives=len(self.additives_kb),
                    model_version=self.model_version)

    @classmethod
    def get(cls) -> "ModelService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    # ---------------- fuzzy matching ----------------

    def match_ingredients(self, tokens: list[str]) -> tuple[list[dict], list[str]]:
        matched, unmatched = [], []
        for token in tokens:
            result = process.extractOne(
                token, self.vocab_list,
                scorer=fuzz.WRatio,
                score_cutoff=settings.FUZZY_MATCH_CUTOFF)
            if result:
                name, score, _ = result
                matched.append({
                    "ocr_text": token,
                    "matched_to": name,
                    "confidence": round(float(score), 1),
                })
            else:
                unmatched.append(token)
        return matched, unmatched

    # ---------------- grade prediction ----------------

    def predict_grade(self, nutrients: dict[str, float],
                      additives_count: int = 0) -> dict:
        row = {col: nutrients.get(col, -1) for col in NUTRIENT_COLS}
        row["additives_n"] = additives_count

        X = pd.DataFrame([row], columns=NUTRIENT_COLS)
        grade = str(self.model.predict(X)[0])
        probabilities = self.model.predict_proba(X)[0]
        prob_map = {str(c): round(float(p), 4)
                    for c, p in zip(self.model.classes_, probabilities)}

        return {
            "grade": grade,
            "grade_label": GRADE_LABELS.get(grade, "UNKNOWN"),
            "grade_confidence": prob_map.get(grade, 0.0),
            "grade_probabilities": prob_map,
            "model_version": self.model_version,
        }

    def predict_batch(self, rows: list[dict]) -> list[dict]:
        """Batch prediction for the admin/batch endpoint."""
        X = pd.DataFrame(
            [{c: r.get(c, -1) for c in NUTRIENT_COLS} for r in rows],
            columns=NUTRIENT_COLS)
        grades = self.model.predict(X)
        probs = self.model.predict_proba(X)
        out = []
        for g, p in zip(grades, probs):
            pm = {str(c): round(float(x), 4) for c, x in zip(self.model.classes_, p)}
            out.append({"grade": str(g),
                        "grade_label": GRADE_LABELS.get(str(g), "UNKNOWN"),
                        "grade_probabilities": pm})
        return out
