"""Application configuration. All values overridable via environment variables."""
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # --- App ---
    APP_NAME: str = "NutriScan API"
    ENV: str = "development"                  # development | staging | production
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = False

    # --- Security ---
    SECRET_KEY: str = "CHANGE-ME-IN-PRODUCTION"   # injected from Secret Manager in prod
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    BCRYPT_ROUNDS: int = 12

    # --- Database ---
    DATABASE_URL: str = "postgresql://nutriscan:nutriscan@localhost:5432/nutriscan"
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 5

    # --- Storage ---
    GCS_BUCKET: str = "nutriscan-scans"
    USE_LOCAL_STORAGE: bool = True            # True for local dev, False on Cloud Run
    LOCAL_STORAGE_DIR: str = "/tmp/nutriscan-uploads"
    MAX_UPLOAD_MB: int = 8

    # --- ML assets ---
    ML_ASSETS_DIR: str = "ml_assets"
    MODEL_FILE: str = "health_classifier.pkl"
    VOCAB_FILE: str = "ingredient_vocab.json"
    ADDITIVES_FILE: str = "additives_kb.csv"
    FUZZY_MATCH_CUTOFF: int = 70
    OCR_CONFIDENCE_THRESHOLD: float = 0.5

    # --- RAG ---
    EMBEDDING_MODEL: str = "sentence-transformers/all-MiniLM-L6-v2"
    RAG_TOP_K: int = 3
    RAG_SIMILARITY_THRESHOLD: float = 0.75
    LLM_API_URL: str = "https://api.anthropic.com/v1/messages"
    LLM_API_KEY: str = ""                     # empty = LLM fallback disabled
    LLM_MODEL: str = "claude-haiku-4-5-20251001"

    # --- Rate limiting ---
    RATE_LIMIT_AUTH: str = "10/minute"
    RATE_LIMIT_SCAN: str = "30/minute"
    RATE_LIMIT_DEFAULT: str = "120/minute"

    # --- CORS ---
    CORS_ORIGINS: list[str] = ["*"]           # tighten in production


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
