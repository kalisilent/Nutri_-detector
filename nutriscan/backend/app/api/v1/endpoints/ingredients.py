from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.services.rag.explainer import CURATED_ADDITIVES, ExplanationService

router = APIRouter(prefix="/ingredients", tags=["ingredients"])


@router.get("/explain/{name}")
async def explain_ingredient(name: str,
                             user: User = Depends(get_current_user),
                             db: Session = Depends(get_db)):
    """Explain a single ingredient or E-number in plain language."""
    service = ExplanationService(db)

    # E-number?
    if name.upper().startswith("E") and name[1:4].isdigit():
        info = service.curated_additive(name)
        if info:
            return info
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Additive not in database")

    result = await service.explain(name)
    if result is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND,
                            "No explanation available for this ingredient")
    return result


@router.get("/additives")
def list_additives(user: User = Depends(get_current_user)):
    """Full curated additive dictionary for offline caching in the app."""
    return [{"code": code, **info} for code, info in CURATED_ADDITIVES.items()]
