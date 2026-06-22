from datetime import datetime

from pydantic import BaseModel


class MatchedIngredient(BaseModel):
    ocr_text: str
    matched_to: str
    confidence: float
    explanation: str | None = None
    safety: str | None = None


class AdditiveInfo(BaseModel):
    code: str
    name: str
    what: str
    safety: str
    source: str = "curated"


class ScanResult(BaseModel):
    scan_id: str
    panel_type: str
    grade: str | None
    grade_label: str | None
    grade_confidence: float | None
    grade_probabilities: dict[str, float] | None
    nutrients: dict[str, float]
    ingredients: list[MatchedIngredient]
    additives: list[AdditiveInfo]
    unmatched: list[str]
    image_url: str | None
    created_at: datetime


class ScanHistoryItem(BaseModel):
    scan_id: str
    grade: str | None
    panel_type: str
    image_url: str | None
    ingredient_count: int
    created_at: datetime


class ScanHistoryResponse(BaseModel):
    items: list[ScanHistoryItem]
    total: int
    page: int
    page_size: int
