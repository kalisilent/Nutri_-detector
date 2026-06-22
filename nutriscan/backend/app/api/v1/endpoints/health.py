from fastapi import APIRouter
from sqlalchemy import text

from app.db.session import engine

router = APIRouter(tags=["health"])


@router.get("/health")
def health():
    """Liveness probe."""
    return {"status": "ok"}


@router.get("/health/ready")
def ready():
    """Readiness: verifies DB connection and ML assets are loaded."""
    db_ok, ml_ok = False, False
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:  # noqa: BLE001
        pass
    try:
        from app.services.ml.predictor import ModelService
        ModelService.get()
        ml_ok = True
    except Exception:  # noqa: BLE001
        pass
    status = "ok" if (db_ok and ml_ok) else "degraded"
    return {"status": status, "db": db_ok, "ml": ml_ok}
