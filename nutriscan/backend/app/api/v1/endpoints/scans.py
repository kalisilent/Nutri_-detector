import uuid

from fastapi import (APIRouter, Depends, File, HTTPException, Request,
                     UploadFile, status)
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.rate_limit import limiter
from app.db.session import get_db
from app.models.scan import Scan
from app.models.user import User
from app.schemas.scan import (ScanHistoryItem, ScanHistoryResponse, ScanResult)
from app.services.scan_pipeline import run_scan_pipeline
from app.utils.storage import save_image

router = APIRouter(prefix="/scans", tags=["scans"])

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.post("", response_model=ScanResult, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.RATE_LIMIT_SCAN)
async def create_scan(request: Request,
                      image: UploadFile = File(...),
                      user: User = Depends(get_current_user),
                      db: Session = Depends(get_db)):
    # ---- validation ----
    if image.content_type not in ALLOWED_TYPES:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                            f"Unsupported type {image.content_type}. Use JPEG/PNG/WebP.")
    image_bytes = await image.read()
    if len(image_bytes) > settings.MAX_UPLOAD_MB * 1024 * 1024:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            f"Image exceeds {settings.MAX_UPLOAD_MB} MB limit")

    # ---- pipeline ----
    result = await run_scan_pipeline(image_bytes, db)
    if "error" in result:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"Scan failed: {result['error']}")

    image_url = save_image(image_bytes, str(user.id))

    # ---- persist ----
    scan = Scan(user_id=user.id,
                image_url=image_url,
                panel_type=result["panel_type"],
                grade=result["grade"],
                grade_confidence=result["grade_confidence"],
                nutrients=result["nutrients"],
                ingredients=result["ingredients"],
                additives=result["additives"],
                raw_ocr=result["raw_ocr"][:8000])
    db.add(scan)
    db.commit()
    db.refresh(scan)

    return ScanResult(scan_id=str(scan.id),
                      panel_type=result["panel_type"],
                      grade=result["grade"],
                      grade_label=result["grade_label"],
                      grade_confidence=result["grade_confidence"],
                      grade_probabilities=result["grade_probabilities"],
                      nutrients=result["nutrients"],
                      ingredients=result["ingredients"],
                      additives=result["additives"],
                      unmatched=result["unmatched"],
                      image_url=image_url,
                      created_at=scan.created_at)


@router.get("/history", response_model=ScanHistoryResponse)
def history(page: int = 1, page_size: int = 20,
            user: User = Depends(get_current_user),
            db: Session = Depends(get_db)):
    page = max(page, 1)
    page_size = min(max(page_size, 1), 100)

    total = db.execute(select(func.count(Scan.id))
                       .where(Scan.user_id == user.id)).scalar_one()
    rows = db.execute(select(Scan)
                      .where(Scan.user_id == user.id)
                      .order_by(Scan.created_at.desc())
                      .offset((page - 1) * page_size)
                      .limit(page_size)).scalars().all()

    items = [ScanHistoryItem(scan_id=str(s.id), grade=s.grade,
                             panel_type=s.panel_type, image_url=s.image_url,
                             ingredient_count=len(s.ingredients or []),
                             created_at=s.created_at) for s in rows]
    return ScanHistoryResponse(items=items, total=total,
                               page=page, page_size=page_size)


@router.get("/{scan_id}", response_model=ScanResult)
def get_scan(scan_id: uuid.UUID,
             user: User = Depends(get_current_user),
             db: Session = Depends(get_db)):
    scan = db.get(Scan, scan_id)
    if scan is None or scan.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Scan not found")

    return ScanResult(scan_id=str(scan.id), panel_type=scan.panel_type,
                      grade=scan.grade, grade_label=None,
                      grade_confidence=scan.grade_confidence,
                      grade_probabilities=None,
                      nutrients=scan.nutrients or {},
                      ingredients=scan.ingredients or [],
                      additives=scan.additives or [],
                      unmatched=[], image_url=scan.image_url,
                      created_at=scan.created_at)


@router.delete("/{scan_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_scan(scan_id: uuid.UUID,
                user: User = Depends(get_current_user),
                db: Session = Depends(get_db)):
    scan = db.get(Scan, scan_id)
    if scan is None or scan.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Scan not found")
    db.delete(scan)
    db.commit()
