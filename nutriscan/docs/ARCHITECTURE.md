# NutriScan — Production Architecture

## 1. System Overview

NutriScan analyzes packaged food from photos. The user scans a packet; the system runs OCR,
extracts ingredients + nutrition values, predicts a Nutri-Score grade (A–E) with a trained
LightGBM model, and explains every ingredient in plain language using a knowledge base with
an LLM/RAG fallback.

## 2. High-Level Architecture

```mermaid
flowchart LR
    subgraph Client
        A[Flutter App<br/>Android / iOS]
    end

    subgraph GCP["Google Cloud"]
        B[Cloud Load Balancer / HTTPS]
        C[Cloud Run<br/>FastAPI Backend]
        D[(Cloud SQL<br/>PostgreSQL)]
        E[Cloud Storage<br/>scan images]
        F[Cloud Run<br/>ML+OCR Service]
        G[(Vector Store<br/>pgvector)]
        H[Secret Manager]
        I[Cloud Logging +<br/>Error Reporting]
    end

    subgraph Third["3rd Party"]
        J[LLM API<br/>RAG fallback]
        K[Firebase<br/>Crashlytics + Analytics]
    end

    A -->|JWT over HTTPS| B --> C
    C --> D
    C --> E
    C --> F
    F --> G
    F -->|unknown ingredient| J
    C --> H
    C --> I
    A --> K
```

**Why each component exists**

| Component | Why |
|---|---|
| Flutter app | One codebase → Android + iOS. Camera, offline cache, Material 3. |
| Cloud Run (API) | Serverless containers: scale-to-zero (cost), autoscale on traffic, no server ops. |
| Cloud Run (ML/OCR) | OCR + model inference is CPU-heavy and has different scaling needs than the API — isolating it keeps API latency low and lets it scale independently. |
| Cloud SQL Postgres | Relational data (users, scans, products) + pgvector extension doubles as the RAG vector store, avoiding a second database bill. |
| Cloud Storage | Raw scan images don't belong in Postgres. Signed URLs keep them private. |
| Secret Manager | JWT keys, DB passwords, LLM API keys never live in code or env files. |
| Cloud Logging / Error Reporting | Centralized structured logs + automatic error grouping/alerts. |
| Firebase Crashlytics + Analytics | Client-side crash reports and usage funnels for the mobile app. |
| GitHub Actions | CI/CD: test → build → push image → deploy on every merge to main. |

## 3. Scan Request Flow

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant API as FastAPI (Cloud Run)
    participant ML as ML/OCR Service
    participant DB as PostgreSQL
    participant GCS as Cloud Storage
    participant LLM as LLM (RAG fallback)

    U->>App: Take photo of packet
    App->>API: POST /api/v1/scans (image, JWT)
    API->>GCS: store image, get URL
    API->>ML: /infer (image bytes)
    ML->>ML: OpenCV preprocess → PaddleOCR
    ML->>ML: detect panel type, parse ingredients + nutrients
    ML->>ML: LightGBM → grade A–E
    ML->>DB: lookup ingredient KB (pgvector similarity)
    alt ingredient unknown
        ML->>LLM: grounded explanation prompt
        LLM-->>ML: plain-language text
        ML->>DB: cache explanation
    end
    ML-->>API: grade + ingredients + explanations
    API->>DB: save scan record
    API-->>App: JSON result
    App->>U: Grade badge + ingredient cards
```

## 4. Database ERD

```mermaid
erDiagram
    USERS ||--o{ SCANS : has
    USERS ||--o{ SAVED_PRODUCTS : saves
    SCANS }o--|| PRODUCTS : resolves_to
    PRODUCTS ||--o{ PRODUCT_INGREDIENTS : contains
    INGREDIENTS ||--o{ PRODUCT_INGREDIENTS : in
    INGREDIENTS ||--o| INGREDIENT_EXPLANATIONS : explained_by

    USERS { uuid id PK
            text email UK
            text hashed_password
            text full_name
            timestamptz created_at }
    SCANS { uuid id PK
            uuid user_id FK
            text image_url
            text panel_type
            char grade
            jsonb nutrients
            jsonb raw_ocr
            timestamptz created_at }
    PRODUCTS { uuid id PK
               text barcode UK
               text name
               char grade }
    INGREDIENTS { uuid id PK
                  text name UK
                  text e_number
                  vector embedding }
    INGREDIENT_EXPLANATIONS { uuid id PK
                              uuid ingredient_id FK
                              text what
                              text safety
                              text source }
```

## 5. CI/CD

```mermaid
flowchart LR
    A[git push] --> B[GitHub Actions]
    B --> C[lint + pytest + flutter test]
    C --> D[docker build backend & ml]
    D --> E[push to Artifact Registry]
    E --> F[gcloud run deploy staging]
    F --> G{manual approval}
    G --> H[deploy production]
    B --> I[flutter build appbundle]
    I --> J[upload to Play Console<br/>internal track]
```

## 6. Folder Structure (top level)

```
nutriscan/
├── backend/           FastAPI + ML + OCR + RAG (single deployable, two entrypoints)
│   ├── app/
│   │   ├── api/v1/endpoints/   auth, scans, history, ingredients, admin, health
│   │   ├── core/               config, security, logging, rate limit
│   │   ├── db/                 session, base, init
│   │   ├── models/             SQLAlchemy ORM
│   │   ├── schemas/            Pydantic request/response
│   │   ├── services/
│   │   │   ├── ocr/            preprocess, engine, parsers
│   │   │   ├── ml/             model loader, predictor
│   │   │   └── rag/            embeddings, retriever, llm fallback, kb
│   │   └── utils/
│   ├── alembic/                migrations
│   ├── tests/                  unit + API tests
│   ├── scripts/                seed KB, import model assets
│   ├── ml_assets/              health_classifier.pkl, vocab, additives (from your notebook)
│   ├── Dockerfile
│   └── requirements.txt
├── mobile/            Flutter app (Riverpod, Material 3, go_router)
│   ├── lib/
│   │   ├── core/               theme, dio client, secure storage, errors, router
│   │   └── features/           auth, scan, history, dashboard, profile
│   ├── android/                signing config, manifest
│   └── test/
├── infra/
│   ├── docker/docker-compose.yml      local dev: api + ml + postgres
│   ├── gcp/cloudbuild.yaml            Cloud Build alt pipeline
│   └── scripts/deploy.sh
├── .github/workflows/             ci.yml, deploy.yml, mobile.yml
└── docs/                          this file, Play Store guide, privacy policy
```

## 7. Security

- JWT access (30 min) + refresh (30 days) tokens, bcrypt password hashing
- Rate limiting per-IP and per-user (slowapi)
- All secrets via Secret Manager / env injection — never committed
- Signed URLs for image access; bucket is private
- CORS locked to app origins; HTTPS only; security headers middleware
- Input validation on every endpoint via Pydantic; file-type + size checks on upload

## 8. Cost Optimization

- Cloud Run scale-to-zero on both services (pay only for requests)
- Single Postgres instance hosts relational + vector data
- LLM called only on KB cache miss, response cached forever after
- Images compressed client-side before upload (target < 500 KB)
- min-instances=0 for staging, 1 for prod ML service (avoids cold-start OCR model load)
