# Changelog

All notable changes to NutriScan are documented here.

## [1.0.0] — Unreleased

### Added
- Initial release: scan, OCR, Nutri-Score grading, ingredient explanations
- User accounts (JWT auth, refresh tokens, bcrypt passwords)
- Scan history + per-user dashboard with grade distribution
- E-number additive explainer (30+ curated entries)
- RAG fallback for unknown ingredients (pgvector + LLM grounded)
- Cloud Run deployment, Cloud SQL, Cloud Storage, Secret Manager
- Flutter app: Material 3, dark mode, offline cache (Hive)
- CI/CD via GitHub Actions, Cloud Build pipeline
