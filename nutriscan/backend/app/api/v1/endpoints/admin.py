from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_admin_user
from app.db.session import get_db
from app.models.scan import Scan
from app.models.user import User
from app.services.ml.predictor import ModelService

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats")
def stats(admin: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    total_users = db.execute(select(func.count(User.id))).scalar_one()
    total_scans = db.execute(select(func.count(Scan.id))).scalar_one()
    grade_rows = db.execute(select(Scan.grade, func.count(Scan.id))
                            .where(Scan.grade.isnot(None))
                            .group_by(Scan.grade)).all()
    return {"total_users": total_users,
            "total_scans": total_scans,
            "grades": {g: c for g, c in grade_rows},
            "model_version": ModelService.get().model_version}


class BatchPredictRequest(BaseModel):
    rows: list[dict]


@router.post("/predict/batch")
def batch_predict(body: BatchPredictRequest,
                  admin: User = Depends(get_admin_user)):
    """Batch grade prediction for offline analysis (max 1000 rows)."""
    rows = body.rows[:1000]
    return {"predictions": ModelService.get().predict_batch(rows)}
