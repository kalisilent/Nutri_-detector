#!/usr/bin/env bash
# One-command local dev: brings the stack up after copying ML assets.
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ ! -f backend/ml_assets/health_classifier.pkl ]; then
  echo "ERROR: backend/ml_assets/ is empty."
  echo "Copy these files from your training notebook output:"
  echo "  - health_classifier.pkl"
  echo "  - ingredient_vocab.json"
  echo "  - additives_kb.csv"
  exit 1
fi

docker compose -f infra/docker/docker-compose.yml up --build
