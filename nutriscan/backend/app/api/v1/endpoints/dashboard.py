from collections import Counter

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.scan import Scan
from app.models.user import User
from app.schemas.dashboard import DashboardResponse, GradeCount

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

GRADE_ORDER = "abcde"


@router.get("", response_model=DashboardResponse)
def dashboard(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.execute(select(Scan.grade, func.count(Scan.id))
                      .where(Scan.user_id == user.id, Scan.grade.isnot(None))
                      .group_by(Scan.grade)).all()
    counts = {g: c for g, c in rows}
    total = sum(counts.values())

    avg_grade = None
    if total:
        weighted = sum(GRADE_ORDER.index(g) * c for g, c in counts.items())
        avg_grade = GRADE_ORDER[round(weighted / total)]

    healthiest = db.execute(select(Scan.id)
                            .where(Scan.user_id == user.id, Scan.grade.isnot(None))
                            .order_by(Scan.grade.asc(), Scan.created_at.desc())
                            .limit(1)).scalar_one_or_none()

    # Most common additives across this user's scans
    additive_counter: Counter = Counter()
    scans = db.execute(select(Scan.additives)
                       .where(Scan.user_id == user.id)).scalars().all()
    for additives in scans:
        for a in additives or []:
            additive_counter[a.get("code", "?")] += 1

    return DashboardResponse(
        total_scans=total,
        grade_distribution=[GradeCount(grade=g, count=counts.get(g, 0))
                            for g in GRADE_ORDER],
        average_grade=avg_grade,
        healthiest_scan_id=str(healthiest) if healthiest else None,
        most_common_additives=[{"code": c, "count": n}
                               for c, n in additive_counter.most_common(5)])
