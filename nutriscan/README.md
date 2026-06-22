# NutriScan

> Scan a food packet. Understand every ingredient. Get a Nutri-Score grade.

NutriScan is a production-ready mobile app + backend that uses OCR, a LightGBM
classifier, and a RAG explanation pipeline to help shoppers understand processed
food labels.

---

## Architecture

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design with
Mermaid diagrams. Quick overview:

```
Flutter app ──HTTPS──▶ Cloud Run (FastAPI)
                          │
                          ├─ Cloud SQL (Postgres + pgvector)
                          ├─ Cloud Storage  (scan images)
                          ├─ Secret Manager (JWT, DB, LLM keys)
                          └─ LLM API        (RAG fallback)
```

## Repository Layout

```
nutriscan/
├── backend/              FastAPI + ML + OCR + RAG
├── mobile/               Flutter (Riverpod, Material 3, go_router)
├── infra/                Docker, Cloud Build, GCP setup
├── .github/workflows/    CI, deploy, mobile release
└── docs/                 architecture, Play Store, privacy, terms
```

## Quick Start (local development)

```bash
# 1. Put your trained ML assets in backend/ml_assets/
#    (generated from the training notebook):
#      - health_classifier.pkl
#      - ingredient_vocab.json
#      - additives_kb.csv
#      - VERSION (single line: 1.0.0)

# 2. Bring up Postgres + API
bash infra/scripts/dev_up.sh

# 3. API will be at http://localhost:8080/docs

# 4. Run the Flutter app (Android emulator can reach the host at 10.0.2.2)
cd mobile && flutter pub get && flutter run
```

## Deploy to Google Cloud

```bash
# One-time project setup (creates SQL, storage, secrets, registry)
PROJECT_ID=your-project bash infra/scripts/setup_gcp.sh

# Then push to main — GitHub Actions handles the rest
git push origin main
```

See [`docs/PLAY_STORE.md`](docs/PLAY_STORE.md) for the mobile release process.

## Tests

```bash
# Backend
cd backend && pytest

# Mobile
cd mobile && flutter test
```

## License

Proprietary. © 2026 Your Company.

## Safety Notice

NutriScan provides educational information based on the Nutri-Score and NOVA
classification systems. It is **not medical advice**. Users with specific dietary
restrictions or medical conditions should consult a qualified healthcare provider.
