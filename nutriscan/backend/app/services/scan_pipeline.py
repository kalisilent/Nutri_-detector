"""
Scan orchestrator — the production equivalent of the notebook's scan_food_packet().
OCR → detect panel → parse → match → explain → predict grade.
"""
from sqlalchemy.orm import Session

from app.core.logging import get_logger
from app.services.ml.predictor import ModelService
from app.services.ocr.engine import run_ocr
from app.services.ocr.parsers import (detect_panel_type, parse_ingredients,
                                      parse_nutrition)
from app.services.rag.explainer import ExplanationService

logger = get_logger("pipeline")


async def run_scan_pipeline(image_bytes: bytes, db: Session) -> dict:
    ml = ModelService.get()
    explainer = ExplanationService(db)

    # 1. OCR
    ocr = run_ocr(image_bytes)
    if ocr.error:
        return {"error": ocr.error}

    # 2. Panel type
    panel_type = detect_panel_type(ocr.raw_text)

    matched: list[dict] = []
    unmatched: list[str] = []
    e_numbers: list[str] = []
    additives: list[dict] = []
    nutrients: dict[str, float] = {}

    # 3. Ingredients branch
    if panel_type in ("ingredients", "both"):
        tokens, e_numbers = parse_ingredients(ocr.raw_text)
        matched, unmatched = ml.match_ingredients(tokens)

        # explain matched ingredients (DB → LLM cascade)
        for m in matched:
            exp = await explainer.explain(m["matched_to"])
            if exp:
                m["explanation"] = exp["what"]
                m["safety"] = exp.get("safety")

        # explain additives (curated dict → KB frequency fallback)
        for code in e_numbers:
            info = explainer.curated_additive(code)
            if info is None:
                kb = ml.additives_kb
                row = kb[kb["code"] == code.upper()]
                if not row.empty:
                    info = {"code": code.upper(), "name": "Additive",
                            "what": f"Found in {int(row.iloc[0]['count']):,} products in our database.",
                            "safety": f"Most commonly appears in grade '{row.iloc[0]['most_common_grade']}' products.",
                            "source": "kb_frequency"}
            if info:
                additives.append(info)

    # 4. Nutrition branch
    if panel_type in ("nutrition", "both", "unknown"):
        nutrients = parse_nutrition(ocr.raw_text)

    # 5. Grade
    prediction = ml.predict_grade(nutrients, additives_count=len(e_numbers))

    # Low information guard: if we extracted almost nothing, don't pretend confidence
    if len(nutrients) < 3 and panel_type in ("nutrition", "unknown"):
        prediction["grade_label"] = prediction["grade_label"] + " (LOW CONFIDENCE — few nutrients readable)"

    logger.info("scan_complete", panel_type=panel_type,
                ingredients=len(matched), additives=len(e_numbers),
                nutrients=len(nutrients), grade=prediction["grade"],
                ocr_confidence=ocr.mean_confidence)

    return {
        "panel_type": panel_type,
        "raw_ocr": ocr.raw_text,
        "ocr_confidence": ocr.mean_confidence,
        "nutrients": nutrients,
        "ingredients": matched,
        "unmatched": unmatched,
        "additives": additives,
        **prediction,
    }
