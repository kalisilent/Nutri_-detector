from pydantic import BaseModel


class GradeCount(BaseModel):
    grade: str
    count: int


class DashboardResponse(BaseModel):
    total_scans: int
    grade_distribution: list[GradeCount]
    average_grade: str | None
    healthiest_scan_id: str | None
    most_common_additives: list[dict]
