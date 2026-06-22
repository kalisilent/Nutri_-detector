# ---------- builder ----------
FROM python:3.12-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- runtime ----------
FROM python:3.12-slim
WORKDIR /app

# OpenCV headless runtime needs libgl-less libs only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install /usr/local
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini .
COPY scripts ./scripts
COPY ml_assets ./ml_assets

# non-root user
RUN useradd -m appuser && chown -R appuser /app
USER appuser

ENV PORT=8080 PYTHONUNBUFFERED=1
EXPOSE 8080

# Cloud Run sets $PORT. 2 workers fits the default 1-CPU instance.
CMD exec gunicorn app.main:app \
    --worker-class uvicorn.workers.UvicornWorker \
    --workers 2 --bind 0.0.0.0:${PORT} \
    --timeout 120 --access-logfile -
