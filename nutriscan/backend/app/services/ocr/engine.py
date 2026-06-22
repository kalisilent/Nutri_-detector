"""
OCR pipeline: OpenCV preprocessing + RapidOCR (ONNX, CPU-friendly).

This is the production version of the notebook pipeline:
- no matplotlib display
- structured confidence scoring
- graceful error recovery (returns empty result instead of crashing)
"""
from dataclasses import dataclass, field

import cv2
import numpy as np

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger("ocr")

# Lazy singleton — loading the ONNX models takes ~2s, do it once per container
_engine = None


def _get_engine():
    global _engine
    if _engine is None:
        from rapidocr_onnxruntime import RapidOCR
        _engine = RapidOCR()
        logger.info("ocr_engine_loaded", backend="rapidocr")
    return _engine


@dataclass
class OCRResult:
    raw_text: str = ""
    lines: list[str] = field(default_factory=list)
    mean_confidence: float = 0.0
    n_regions: int = 0
    error: str | None = None


def preprocess(image_bytes: bytes) -> np.ndarray | None:
    """Decode + clean an uploaded image for OCR. Returns BGR ndarray or None."""
    try:
        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            return None

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        denoised = cv2.fastNlMeansDenoising(gray, h=15)
        thresh = cv2.adaptiveThreshold(
            denoised, 255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 31, 10)

        # Upscale small images so tiny label fonts are readable
        h, w = thresh.shape
        if max(h, w) < 1000:
            scale = 1000 / max(h, w)
            thresh = cv2.resize(thresh, None, fx=scale, fy=scale,
                                interpolation=cv2.INTER_CUBIC)

        return cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)
    except Exception as exc:  # noqa: BLE001 — never crash the request on a bad image
        logger.error("preprocess_failed", error=str(exc))
        return None


def run_ocr(image_bytes: bytes) -> OCRResult:
    """Full OCR: preprocess → recognize → filter by confidence."""
    processed = preprocess(image_bytes)
    if processed is None:
        return OCRResult(error="could_not_decode_image")

    try:
        results, _ = _get_engine()(processed)
    except Exception as exc:  # noqa: BLE001
        logger.error("ocr_failed", error=str(exc))
        return OCRResult(error="ocr_engine_failure")

    if not results:
        return OCRResult(error="no_text_detected")

    lines, confidences = [], []
    for detection in results:
        # RapidOCR detection: [bbox, text, confidence]
        text, conf = detection[1], float(detection[2])
        if conf >= settings.OCR_CONFIDENCE_THRESHOLD:
            lines.append(text)
            confidences.append(conf)

    if not lines:
        return OCRResult(error="all_below_confidence_threshold")

    return OCRResult(
        raw_text=" ".join(lines),
        lines=lines,
        mean_confidence=float(np.mean(confidences)),
        n_regions=len(lines),
    )
