#!/usr/bin/env bash
# One-time GCP project bootstrap. Run with PROJECT_ID and REGION set:
#   PROJECT_ID=my-proj REGION=us-central1 bash infra/scripts/setup_gcp.sh
set -euo pipefail

: "${PROJECT_ID:?Set PROJECT_ID}"
: "${REGION:=us-central1}"

echo "==> Setting project"
gcloud config set project "$PROJECT_ID"

echo "==> Enabling required APIs"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com

echo "==> Creating Artifact Registry repo"
gcloud artifacts repositories create nutriscan \
  --repository-format=docker --location="$REGION" || true

echo "==> Creating Cloud Storage bucket for scan images"
gsutil mb -l "$REGION" "gs://nutriscan-scans" || true
gsutil iam ch allUsers:objectViewer gs://nutriscan-scans 2>/dev/null || true

echo "==> Creating Cloud SQL Postgres instance (this takes ~10 min)"
gcloud sql instances create nutriscan-db \
  --database-version=POSTGRES_16 \
  --region="$REGION" \
  --tier=db-f1-micro \
  --storage-size=10GB \
  --backup-start-time=03:00 || true

gcloud sql databases create nutriscan --instance=nutriscan-db || true

echo "==> Generating secrets (saved to Secret Manager)"
JWT_SECRET=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 24)
gcloud sql users create nutriscan --instance=nutriscan-db --password="$DB_PASSWORD" || true

DB_URL="postgresql://nutriscan:${DB_PASSWORD}@/nutriscan?host=/cloudsql/${PROJECT_ID}:${REGION}:nutriscan-db"

echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret --data-file=- || \
  echo -n "$JWT_SECRET" | gcloud secrets versions add jwt-secret --data-file=-

echo -n "$DB_URL" | gcloud secrets create db-url --data-file=- || \
  echo -n "$DB_URL" | gcloud secrets versions add db-url --data-file=-

echo -n "" | gcloud secrets create llm-key --data-file=- || true

echo "==> Done. Push code or trigger Cloud Build to deploy."
