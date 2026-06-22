"""Image storage: GCS in production, local filesystem in development."""
import uuid
from pathlib import Path

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger("storage")


def save_image(image_bytes: bytes, user_id: str) -> str | None:
    """Persist an uploaded scan image; return its URL/path or None on failure."""
    filename = f"{user_id}/{uuid.uuid4().hex}.jpg"

    if settings.USE_LOCAL_STORAGE:
        try:
            dest = Path(settings.LOCAL_STORAGE_DIR) / filename
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(image_bytes)
            return str(dest)
        except OSError as exc:
            logger.error("local_storage_failed", error=str(exc))
            return None

    try:
        from google.cloud import storage as gcs
        client = gcs.Client()
        bucket = client.bucket(settings.GCS_BUCKET)
        blob = bucket.blob(f"scans/{filename}")
        blob.upload_from_string(image_bytes, content_type="image/jpeg")
        # Signed URL valid for 7 days — bucket itself stays private
        return blob.generate_signed_url(version="v4", expiration=7 * 24 * 3600)
    except Exception as exc:  # noqa: BLE001
        logger.error("gcs_upload_failed", error=str(exc))
        return None
