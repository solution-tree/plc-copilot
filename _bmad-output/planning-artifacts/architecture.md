---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - apps/api/docs/prd-v4.md
  - apps/api/docs/prd-v4-validation-report.md
  - apps/api/docs/research/ferpa-FINAL.md
workflowType: 'architecture'
project_name: 'plc-copilot'
user_name: 'Claudia'
date: '2026-02-26'
lastStep: 8
status: 'complete'
completedAt: '2026-02-26'
lastRevisedAt: '2026-02-27'
revisionNote: 'Aligned with PRD v4.2 — Terraform/CI/CD in scope, RPO corrected to 24h, container scanning added, ambiguity metrics added, minimal test client added, eval pipeline extended for baseline comparison and style preference collection'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

---

## Project Context Analysis

### Requirements Overview

**Functional Requirements (14 FRs across 3 capability areas):**

- **Ingestion Pipeline (FR-1–5):** Three-stage PDF processing — page classification,
  hierarchical text parsing, and visual content extraction for landscape pages. Rich
  metadata schema mandatory on every chunk; pre-build corpus scan required before any
  ingestion begins.
- **Query Engine (FR-6–11):** Four distinct query flows (direct answer, conditional
  clarification, out-of-scope hard refusal, metadata-filtered). These four flows are
  routed by an explicit query classifier/router layer that runs before retrieval — a
  lightweight GPT-4o-mini structured call that classifies query intent and extracts
  metadata filters in a single pass. One-clarifying-question hard limit per session.
  Automatic fallback from filtered to unfiltered search when results < 3.
- **Hybrid Search & Re-Ranking (FR-12–14):** BM25 keyword search + vector semantic
  search (both top-N=20, tunable), merged into a candidate set of M=40, re-ranked by
  cross-encoder to top-K=5. All retrieval parameters are capability parameters — not
  fixed implementation details.

**Non-Functional Requirements (19 NFRs):**

- **Answer Quality (NFR-1–6):** RAGAS thresholds (Faithfulness ≥ 0.80, Answer
  Relevancy ≥ 0.75, Context Precision/Recall ≥ 0.70), 100% out-of-scope refusal rate,
  1-question-per-session interaction limit.
- **Performance (NFR-7–9):** p95 response time ≤ 30s for direct answers — high-risk
  NFR given multi-stage pipeline latency. The cross-encoder re-ranker loads in-process
  at Fargate startup; container cold-start time and ECS health check strategy must be
  accounted for. 95% availability during business hours, ≥5 concurrent users without
  degradation.
- **Security & Operational (NFR-11–19):** TLS 1.2+ everywhere, AWS KMS at rest, zero
  OpenAI data retention, no PII in logs, 15-min session expiry, 90-day audit log
  retention, structured JSON logging (CloudWatch), RTO 4h / RPO 1h, manual
  re-ingestion trigger.

**API Response Format (locked):**

- Three response statuses only: `success`, `needs_clarification`, `out_of_scope`
- No envelope wrapper — flat Pydantic models
- Error responses use exact HTTP status codes and body shapes from PRD Section 6.4

**Scale & Complexity:**

- Primary domain: API Backend / RAG Service
- Complexity level: High
- Estimated architectural components: 10 (API service, query classifier/router,
  ingestion pipeline, Qdrant vector store, PostgreSQL, Redis, S3, OpenAI API, RAGAS
  evaluation pipeline, SSM ingestion workflow)

### MVP Infrastructure Scope

**In scope for internal MVP:**

- Fargate — API container (private subnet)
- ALB — public subnet, routes traffic to Fargate
- NAT Gateway — controlled egress for Fargate → OpenAI
- Qdrant on EC2 (self-hosted, private subnet)
- RDS PostgreSQL (managed, private subnet)
- ElastiCache Redis (managed, private subnet)
- S3 — private bucket for PDFs (SKU-prefixed structure, e.g. `BKF219/book.pdf`)
- OpenAI API with zero-retention DPA (GPT-4o for generation, GPT-4o-mini for
  classification, text-embedding-3-large for embeddings)
- Static API key auth (`X-API-Key` header)
- Single AZ VPC (public + private subnets)
- Terraform — all Zone A infrastructure defined as IaC; Zones B and C defined as
  commented-out code with documented intent (PRD AC #1)
- GitHub Actions CI/CD — build, test, lint, ECR push, Fargate deploy on push to `main`
  (PRD AC #2); ingestion triggered from GHA but all processing runs inside VPC via SSM
- ECR — Docker image registry for API and ingestion containers
- Container vulnerability scanning — integrated into CI pipeline; critical/high CVEs
  block deployment (PRD NFR-007)
- Minimal test client — single-page input UI for internal testers only (PRD Section 2.2)

**Deferred (not needed for internal MVP):**

- CloudWatch advanced dashboards and alarms
- Three-Zone VPC topology — document intent, build Zone A only
- Multi-AZ / high availability

**FERPA posture:** The MVP handles zero student data — only proprietary book content.
FERPA does not apply to the MVP. The Three-Zone Tenant Enclave model is a documented
design intent for future phases when student data enters the system, not a current
implementation requirement. Qdrant is self-hosted to protect proprietary IP (the
books). The OpenAI zero-retention DPA is worth executing now as it is required for
future phases and low effort.

### Locked Decisions from Context Analysis

| # | Decision | Choice |
|---|---|---|
| D-CA-1 | S3 corpus structure | SKU-prefixed (`{SKU}/book.pdf`) |
| D-CA-2 | Golden dataset file format | JSON (in `tests/`) — questions only, no book excerpts |
| D-CA-3 | Ingestion idempotency | Unique constraint on `(book_id, page_number, chunk_hash)` |
| D-CA-4 | Out-of-scope detection sequencing | Pre-retrieval, handled by query classifier |
| D-CA-5 | Metadata filter extraction | GPT-4o-mini structured call (same pass as query classification) |
| D-CA-6 | RAGAS in CI | Unit/integration tests on every PR; RAGAS on merge-to-main only |
| D-CA-7 | Repository structure | Monorepo: `apps/api/`, `apps/ingestion/`, `eval/`, `tests/`, `corpus/` (gitignored) |
| D-CA-8 | API response format | Three statuses, flat Pydantic models, no envelope wrapper |

### Technical Constraints & Dependencies

- **Hard constraint — data sovereignty:** Qdrant self-hosted on EC2 in private VPC.
  Embeddings of proprietary PLC @ Work® content must never reach third-party managed
  vector DB infrastructure.
- **Hard constraint — ingestion runs inside VPC:** PDF content processed via SSM Run
  Command — not on GitHub Actions public runners.
- **Hard constraint — OpenAI zero-retention DPA:** Must be executed before production
  use.
- **Dependency — pre-build corpus scan:** Must complete before application coding
  begins (FR-5).
- **Dependency — golden dataset:** Questions in `tests/` (JSON) assembled before build
  starts. Questions only — no book excerpts — safe for public CI runners.
- **PDF corpus location:** Local `corpus/` directory (gitignored) during development;
  SKU-prefixed S3 bucket before AWS deployment.
- **Re-ranker startup:** Cross-encoder loads in-process at Fargate startup. ECS health
  check must not pass until model is warm.
- **Session state:** Redis is source of truth for clarification sessions; must survive
  container restarts.

### Cross-Cutting Concerns

- **Dual pipeline separation:** Ingestion and query API are distinct execution contexts
  — separate entry points, Docker images, and IAM roles. Must not share imports.
- **Query classifier/router:** Single GPT-4o-mini structured call classifies intent
  (direct / clarification / out-of-scope / metadata-filtered) and extracts filters
  before retrieval. Pre-retrieval out-of-scope detection saves compute on junk queries.
- **Evaluation pipeline as product capability:** RAGAS proves measurable superiority
  over general LLMs — it is a product deliverable, not just a test harness. Must be
  versioned, accessible to CI, and runnable in both reference-free (build) and
  reference-based (Phase 3) modes.
- **Observability:** Structured JSON logging, no PII even in debug mode, enforced
  across query pipeline, ingestion pipeline, and evaluation pipeline.
- **Hybrid retrieval coordination:** BM25 and vector results merged before re-ranking;
  fallback logic (filtered → unfiltered when < 3 results) centrally managed in the
  pipeline layer.

---

## Starter Template Evaluation

### Primary Technology Domain

Python API Backend / RAG Service — no UI starter applicable.

### Selected Approach: uv Workspace Scaffold (Manual)

**Rationale:** No existing starter template fits a Python RAG monorepo with separate
API and ingestion packages. The FastAPI team now recommends uv for all FastAPI projects
(official docs updated 2025). uv workspaces provide the cleanest multi-package monorepo
support for Python, with lockfile-based reproducibility and fast installs.

**Initialization Commands:**

```bash
# From repo root — initialize workspace
uv init --bare                          # creates root pyproject.toml

# Initialize each package
uv init apps/api --package
uv init apps/ingestion --package
uv init eval --package

# Root pyproject.toml workspace config (add manually):
# [tool.uv.workspace]
# members = ["apps/api", "apps/ingestion", "eval"]
```

**Local development stack (Docker Compose):**

```bash
# docker-compose.yml at repo root covers:
#   qdrant:   qdrant/qdrant   (port 6333)
#   postgres: postgres:15     (port 5432)
#   redis:    redis:7         (port 6379)
docker compose up -d
```

**Architectural Decisions Established by This Scaffold:**

**Language & Runtime:**
- Python 3.11+ (locked in pyproject.toml per-package)
- uv for dependency management and virtual environments
- uv.lock for reproducible installs across environments

**Package Structure:**
- `apps/api/` — FastAPI service entry point (`fastapi[standard]`, LlamaIndex, Pydantic)
- `apps/ingestion/` — ingestion pipeline entry point (PyMuPDF, llmsherpa client,
  LlamaIndex ingestion nodes)
- `eval/` — RAGAS evaluation scripts
- `tests/` — golden dataset (JSON) + pytest test suite
- `corpus/` — PDF source files (gitignored)

**API Runtime:**
- `fastapi dev` — development with live reload (via fastapi-cli, included in
  `fastapi[standard]`)
- `fastapi run` — production-oriented startup

**Testing Framework:**
- pytest + pytest-asyncio for async FastAPI routes
- httpx for async test client
- RAGAS on merge-to-main only (not every PR)

**Code Organization Pattern:**

```
apps/api/src/
  api/        ← routes, dependencies, auth middleware
  pipeline/   ← query classifier, retrieval, reranking, generation
  models/     ← Pydantic schemas (request/response)
  core/       ← config, logging, startup
```

**Development Experience:**
- `uv run fastapi dev apps/api/src/main.py` — live reload during development
- `uv run pytest` — test runner
- `docker compose up -d` — spins up local Qdrant + PostgreSQL + Redis
- Ruff for linting and formatting (replaces black + flake8 + isort)

**Note:** Workspace initialization and Docker Compose setup are the first
implementation tasks before any feature work begins.

---

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (block implementation):**
- PostgreSQL access layer and async driver
- Database migration strategy
- Secrets and configuration management
- Health check endpoint design
- OpenAI SDK async client

**Deferred Decisions (post-MVP):**
- Connection pool tuning (default pool size of 5 sufficient for ≤5 concurrent users)
- Rate limiting strategy (PRD Decision #12)
- Multi-AZ / high availability infrastructure
- Terraform IaC
- GitHub Actions CI/CD

### Data Architecture

| Decision | Choice | Version | Rationale |
|---|---|---|---|
| PostgreSQL access layer | SQLAlchemy async ORM | 2.0.44 (`sqlalchemy[asyncio]`) | Separate DB models from Pydantic API schemas; handles non-relational fields (`qdrant_id`) cleanly; best testability with real DB integration tests |
| Async DB driver | asyncpg | latest stable | Native async, faster than psycopg2; connection string scheme: `postgresql+asyncpg://` |
| DB ↔ API schema separation | Explicit — two separate model files | — | `models/db.py` (SQLAlchemy ORM models), `models/schemas.py` (Pydantic request/response schemas); never shared |
| Database migrations | Alembic | latest stable | `alembic upgrade head` runs at Fargate container startup; version-controlled schema; initial migration generated before first corpus scan |
| Unique constraint | `(book_id, page_number, chunk_hash)` on `chunks` table | — | Enforces ingestion idempotency at the database level; verified by integration tests |
| Connection pooling | SQLAlchemy default (pool_size=5) | — | Sufficient for MVP ≤5 concurrent users |

### Authentication & Security

| Decision | Choice | Version | Rationale |
|---|---|---|---|
| API key validation | FastAPI `Depends` + `Security` | — | Route-level dependency; overridable in pytest; no custom middleware needed |
| Secrets management | pydantic-settings | 2.13.1 | `Settings(BaseSettings)` reads `.env` locally, env vars in ECS; Secrets Manager values injected as ECS task definition env vars; no boto3 at startup |
| OpenAI API key | `SecretStr` field in `Settings` | — | Prevents accidental logging |
| AWS KMS | At-rest encryption for RDS, S3, EBS | — | Configured at infrastructure provisioning time, not in application code |

```python
# apps/api/src/core/config.py
class Settings(BaseSettings):
    openai_api_key: SecretStr
    qdrant_host: str
    database_url: str          # postgresql+asyncpg://...
    api_key: SecretStr
    redis_url: str
    environment: str = "development"

    model_config = SettingsConfigDict(env_file=".env")

settings = Settings()
```

### API & Communication Patterns

| Decision | Choice | Rationale |
|---|---|---|
| API style | REST, single endpoint `POST /api/v1/query` | Locked by PRD Section 6 |
| Response format | Three flat Pydantic models (`SuccessResponse`, `ClarificationResponse`, `OutOfScopeResponse`) | No envelope wrapper; discriminated union on `status` field |
| Error handling | Exact HTTP status codes from PRD Section 6.4 | FastAPI exception handlers |
| API documentation | Auto-generated OpenAPI 3.0 at `/docs` | FastAPI built-in |
| Async strategy | All async throughout | `async def` handlers, `AsyncOpenAI`, SQLAlchemy async session, aioredis |
| OpenAI SDK | Official `openai` Python library, `AsyncOpenAI` client | Native async; GPT-4o (generation), GPT-4o-mini (classification), text-embedding-3-large |
| Inter-service communication | None for MVP | Ingestion triggered via SSM, not API; no message queue |

### Infrastructure & Deployment

| Decision | Choice | Rationale |
|---|---|---|
| Health check endpoint | `GET /health` → `{"status": "ok", "model_loaded": true}` | ECS health check; ALB only routes after re-ranker model warm |
| Container base image | `python:3.11-slim` | Minimal footprint |
| ECS health check config | Path: `/health`, interval: 30s, timeout: 10s, healthy: 2, unhealthy: 3 | Allows ~90s for re-ranker to load |
| Secrets injection | AWS Secrets Manager → ECS task definition env vars | pydantic-settings reads as standard env vars |
| Local development | Docker Compose (Qdrant + PostgreSQL + Redis) + `.env` file | Matches production topology |
| PDF corpus (local dev) | `corpus/` directory (gitignored) | Move to SKU-prefixed S3 before AWS deployment |
| IaC | Terraform | All Zone A resources defined as code; Zones B/C as commented-out blocks (PRD AC #1) |
| CI/CD | GitHub Actions | Push to `main` triggers: lint → test → docker build → ECR push → Fargate task update (PRD AC #2) |
| Container registry | Amazon ECR | Single private registry for both `plc-api` and `plc-ingestion` images |
| Container scanning | Amazon ECR image scanning (or Trivy in GHA) | Critical/high CVEs block CI pipeline before push (PRD NFR-007) |
| Ingestion trigger | GitHub Actions → AWS SSM Run Command | GHA provides the trigger; SSM executes the ingestion script inside the VPC so proprietary content never passes through public runners (PRD Decision #10) |
| Minimal test client | Single-page static UI (`apps/client/`) | Internal testers only; single input field + disclaimer banner; no styling or auth complexity |

### Decision Impact Analysis

**Implementation sequence (order matters):**
1. Terraform Zone A infrastructure + ECR repositories
2. uv workspace scaffold + Docker Compose setup
3. `pydantic-settings` config class
4. SQLAlchemy async engine + Alembic initial migration
5. `GET /health` endpoint
6. GitHub Actions CI/CD pipeline (lint → test → build → ECR push → Fargate deploy)
7. `AsyncOpenAI` client wiring
8. Query classifier (GPT-4o-mini structured call)
9. Hybrid retrieval pipeline (Qdrant + BM25)
10. Re-ranker integration (cross-encoder in-process)
11. Response models + `POST /api/v1/query` route
12. Redis clarification session management
13. Ingestion pipeline (separate package)
14. RAGAS evaluation pipeline (reference-free + baseline comparison + style generation)
15. Minimal test client (`apps/client/`)

**Cross-component dependencies:**
- `pydantic-settings` `Settings` is a dependency of every component — must exist first
- Alembic migration must run before ingestion writes any chunks
- Health check must pass before any route testing is possible
- Query classifier gates all four query flows — central to the pipeline
- Re-ranker cold-start time directly affects health check readiness timing

---

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:** 4 categories, 22 specific patterns locked

### Naming Patterns

**Database Naming Conventions:**
- Tables: plural snake_case (`books`, `chunks`, `query_sessions`)
- Columns: snake_case (`book_id`, `page_number`, `chunk_hash`)
- Foreign keys: `{referenced_table_singular}_id` (`book_id`, `session_id`)
- Indexes: `ix_{table}_{columns}` — let Alembic auto-generate

**API Naming Conventions:**
- JSON fields: snake_case (`book_title`, `page_number`, `response_status`)
- Endpoint paths: locked by PRD (`POST /api/v1/query`, `GET /health`)
- Query parameters: snake_case if added in future

**Code Naming Conventions:**
- PEP 8 throughout, no exceptions
- Modules: `query_classifier.py` (snake_case)
- Classes: `QueryClassifier` (PascalCase)
- Functions/variables: `classify_query`, `book_id` (snake_case)
- Constants: `MAX_RETRIEVAL_RESULTS` (UPPER_SNAKE_CASE)

### Structure Patterns

**Project Organization:**
- Tests co-located per package (`apps/api/tests/`, `apps/ingestion/tests/`,
  `eval/tests/`)
- Repo-root `tests/` reserved for golden dataset JSON only (D-CA-2)
- One file per concern (`pipeline/classifier.py`, `pipeline/retriever.py`,
  `pipeline/reranker.py`, `pipeline/generator.py`)
- Stay flat — only split a file into a directory when it exceeds ~300 lines

**Shared Code:**
- `libs/shared/` added to uv workspace for code shared between packages
- **Whitelisted contents only:** DB models (`models/db.py`), chunk Pydantic schema,
  config, logging setup
- Nothing else enters `libs/shared/` without explicit approval
- `apps/api/` and `apps/ingestion/` depend on `libs/shared/`, never on each other

**File Placement Rules:**
- New route → `api/routes/{resource}.py`
- New pipeline stage → `pipeline/{stage}.py`
- New Pydantic schema → `models/schemas.py` (split only if >300 lines)
- New DB model → `libs/shared/models/db.py`
- New config value → `Settings` class in `core/config.py`

### Process Patterns

**Error Handling:**
- Custom exception hierarchy: base `AppError` with subclasses (`OutOfScopeError`,
  `ClassificationError`, `RetrievalError`)
- Single exception handler in `core/` translates custom exceptions to PRD-specified
  HTTP responses
- Pipeline code never imports `HTTPException` — only the route layer does
- No bare `except Exception` — catch specific exceptions or let them propagate

**Logging:**
- `structlog` configured once in `core/logging.py`
- Import `get_logger` everywhere — never `print()`, never stdlib `logging` directly
- Bound loggers for context fields (`request_id`, `book_id`)
- Structured JSON output, no PII even in debug mode

**Async Client Management:**
- FastAPI `lifespan` context manager creates all clients at startup, closes at shutdown
- Clients: `AsyncOpenAI`, Qdrant async client, Redis async pool, SQLAlchemy
  `async_sessionmaker`
- All injected via FastAPI `Depends` — no global singletons
- **Re-ranker model loading:** happens in lifespan in `core/startup.py`, loaded model
  injected via `Depends`

**Retry Logic:**
- **Single retry authority:** `tenacity` decorators on external service call functions
- **Disable OpenAI SDK built-in retries** (`max_retries=0` on `AsyncOpenAI`) —
  `tenacity` is the sole retry controller
- Exponential backoff, max 3 attempts, only on transient errors (429, 500, 503,
  connection errors)
- No retry on 400-level client errors

**Validation:**
- Pydantic validates at the API boundary (route handler request models)
- No manual validation inside pipeline code — trust typed data
- DB-level constraints (unique on `(book_id, page_number, chunk_hash)`) as final
  safety net

### Test Patterns

**Test File Naming:**
- Files: `test_{module_name}.py` mirroring source structure
- `pipeline/classifier.py` → `tests/test_classifier.py`
- Functions: `test_{behavior_under_test}`
  (e.g., `test_classify_returns_out_of_scope_for_unrelated_query`)
- No class-based tests unless grouping is genuinely needed

**Fixture & Factory Patterns:**
- `conftest.py` at each test directory level
- Shared fixtures for: async DB session, async httpx test client, mock OpenAI client
- Pydantic model factories as plain functions in `tests/factories.py`
- No `pytest-factoryboy` or third-party factory libraries

### Enforcement Guidelines

**All AI Agents MUST:**
- Follow snake_case everywhere (DB, Python, JSON API) — zero exceptions
- Place new code in the correct location per file placement rules
- Use `structlog` for all logging, `tenacity` for all retries, `Depends` for all
  client injection
- Run through the custom exception hierarchy — never raise `HTTPException` from
  pipeline code

**Import Boundaries (enforced by CI):**
- `apps/api/` and `apps/ingestion/` NEVER import from each other
- `pipeline/` modules never import from `api/` (routes layer)
- Both packages import from `libs/shared/` only
- CI check (ruff rule or grep script) fails the build on violations

**Anti-Patterns (agents MUST NOT):**
- Use `print()` for logging
- Create global client instances outside lifespan
- Catch bare `Exception`
- Put business logic in route handlers — routes are thin, delegate to `pipeline/`
- Hard-code configuration values — everything through `pydantic-settings`
- Import `HTTPException` outside `api/` layer
- Add `# type: ignore` without an explaining comment
- Create utility grab-bag files (`utils.py`, `helpers.py`) — name by purpose
- Add anything to `libs/shared/` outside the whitelist without approval

### Pattern Examples

**Good:**

```python
# Thin route, delegates to pipeline
@router.post("/api/v1/query")
async def query(request: QueryRequest, pipeline: QueryPipeline = Depends(get_pipeline)):
    result = await pipeline.execute(request)
    return result

# Custom exception from pipeline
raise OutOfScopeError(query=request.query)

# Structured logging
logger = get_logger()
logger.info("query_classified", intent=classification.intent, book_id=request.book_id)

# Retry with tenacity (single authority)
@retry(stop=stop_after_attempt(3), wait=wait_exponential(), retry=retry_if_exception_type(TRANSIENT_ERRORS))
async def embed_text(self, text: str) -> list[float]:
    ...
```

**Anti-Patterns:**

```python
# BAD — business logic in route
@router.post("/api/v1/query")
async def query(request: QueryRequest, openai: AsyncOpenAI = Depends(get_openai)):
    classification = await openai.chat.completions.create(...)  # 50 lines of pipeline logic

# BAD — HTTP concern in pipeline
raise HTTPException(status_code=400, detail="Out of scope")

# BAD — print instead of structlog
print(f"Processing query: {request.query}")

# BAD — double retry (SDK + tenacity)
client = AsyncOpenAI(max_retries=2)  # SDK retries internally
@retry(stop=stop_after_attempt(3))   # tenacity retries on top
async def classify(self, query: str): ...
```

---

## Project Structure & Boundaries

### Requirements to Structure Mapping

**FR-1–5 (Ingestion Pipeline) → `apps/ingestion/`**
- Page classification, hierarchical text parsing, visual content extraction
- Metadata schema enforcement, pre-build corpus scan

**FR-6–11 (Query Engine) → `apps/api/src/api_service/pipeline/` + `apps/api/src/api_service/api/`**
- Query classifier/router, four query flows, clarification sessions
- Metadata-filtered retrieval, fallback logic

**FR-12–14 (Hybrid Search & Re-Ranking) → `apps/api/src/api_service/pipeline/`**
- BM25 + vector search, candidate merging, cross-encoder re-ranking

**Cross-Cutting → `libs/shared/`**
- DB models, chunk schema, config, logging (shared between API and ingestion)

**Evaluation → `eval/`**
- RAGAS pipeline (reference-free for build, reference-based for Phase 3)

### Complete Project Directory Structure

```
plc-copilot/
├── pyproject.toml                          # uv workspace root
├── uv.lock                                 # reproducible lockfile
├── docker-compose.yml                      # local Qdrant + PostgreSQL + Redis
├── .env.example                            # template for local .env
├── .gitignore                              # corpus/, .env, __pycache__, etc.
├── ruff.toml                               # linting + formatting config
├── README.md
│
├── .github/
│   └── workflows/
│       ├── ci.yml                          # lint → test → docker build → ECR push → Fargate deploy
│       └── ingest.yml                      # manual trigger → SSM Run Command (ingestion inside VPC)
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf                              # VPC, subnets, NAT Gateway
│   ├── fargate.tf                          # ECS cluster, task definition, service
│   ├── qdrant_ec2.tf                       # EC2 instance + security group (Zone A)
│   ├── rds.tf                              # PostgreSQL RDS instance
│   ├── elasticache.tf                      # Redis ElastiCache cluster
│   ├── s3.tf                               # private S3 bucket (SKU-prefixed)
│   ├── ecr.tf                              # ECR repos for plc-api and plc-ingestion
│   ├── alb.tf                              # Application Load Balancer
│   ├── secrets.tf                          # AWS Secrets Manager entries
│   ├── iam.tf                              # IAM roles + least-privilege policies
│   └── zones_bc_intent.tf                  # COMMENTED OUT — Zone B/C design intent
│
├── libs/
│   └── shared/
│       ├── pyproject.toml                  # workspace member
│       └── src/
│           └── shared/
│               ├── __init__.py
│               ├── config.py               # Settings(BaseSettings) — single source
│               ├── logging.py              # structlog configuration
│               ├── exceptions.py           # AppError hierarchy
│               └── models/
│                   ├── __init__.py
│                   └── db.py               # SQLAlchemy ORM models (books, chunks, query_sessions)
│
├── apps/
│   ├── api/
│   │   ├── pyproject.toml                  # workspace member — depends on libs/shared
│   │   ├── alembic.ini
│   │   ├── alembic/
│   │   │   ├── env.py
│   │   │   └── versions/                   # migration scripts
│   │   ├── Dockerfile
│   │   ├── src/
│   │   │   └── api_service/
│   │   │       ├── __init__.py
│   │   │       ├── main.py                 # FastAPI app, lifespan, router includes
│   │   │       ├── core/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── startup.py          # lifespan: client init, re-ranker model load
│   │   │       │   └── dependencies.py     # Depends providers (get_pipeline, get_db, etc.)
│   │   │       ├── api/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── routes/
│   │   │       │   │   ├── __init__.py
│   │   │       │   │   ├── query.py        # POST /api/v1/query
│   │   │       │   │   └── health.py       # GET /health
│   │   │       │   ├── middleware/
│   │   │       │   │   ├── __init__.py
│   │   │       │   │   └── auth.py         # X-API-Key validation via Depends
│   │   │       │   └── exception_handlers.py  # AppError → HTTP response mapping
│   │   │       ├── pipeline/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── classifier.py       # GPT-4o-mini query classification + filter extraction
│   │   │       │   ├── retriever.py        # hybrid search: BM25 + vector, fallback logic
│   │   │       │   ├── reranker.py         # cross-encoder re-ranking (top-K=5)
│   │   │       │   ├── generator.py        # GPT-4o answer generation with context
│   │   │       │   ├── session.py          # Redis clarification session management
│   │   │       │   └── orchestrator.py     # QueryPipeline: classifier → retriever → reranker → generator
│   │   │       └── models/
│   │   │           ├── __init__.py
│   │   │           └── schemas.py          # Pydantic: QueryRequest, SuccessResponse, ClarificationResponse, OutOfScopeResponse
│   │   └── tests/
│   │       ├── __init__.py
│   │       ├── conftest.py                 # async DB session, httpx client, mock OpenAI
│   │       ├── factories.py                # Pydantic model factory functions
│   │       ├── test_health.py
│   │       ├── test_query.py               # route-level integration tests
│   │       ├── test_classifier.py
│   │       ├── test_retriever.py
│   │       ├── test_reranker.py
│   │       ├── test_generator.py
│   │       ├── test_session.py
│   │       └── test_orchestrator.py
│   │
│   └── ingestion/
│       ├── pyproject.toml                  # workspace member — depends on libs/shared
│       ├── Dockerfile
│       ├── src/
│       │   └── ingestion/
│       │       ├── __init__.py
│       │       ├── main.py                 # CLI entry point (invoked via SSM)
│       │       ├── scanner.py              # pre-build corpus scan (FR-5)
│       │       ├── classifier.py           # page classification (portrait/landscape)
│       │       ├── parser.py               # hierarchical text parsing
│       │       ├── extractor.py            # visual content extraction (landscape pages)
│       │       ├── chunker.py              # chunk creation with metadata schema
│       │       ├── embedder.py             # text-embedding-3-large via OpenAI
│       │       └── loader.py               # write chunks to PostgreSQL + Qdrant
│       └── tests/
│           ├── __init__.py
│           ├── conftest.py
│           ├── factories.py
│           ├── test_scanner.py
│           ├── test_classifier.py
│           ├── test_parser.py
│           ├── test_extractor.py
│           ├── test_chunker.py
│           ├── test_embedder.py
│           └── test_loader.py
│
├── eval/
│   ├── pyproject.toml                      # workspace member — depends on libs/shared
│   ├── src/
│   │   └── eval/
│   │       ├── __init__.py
│   │       ├── run_ragas.py                # RAGAS evaluation entry point (reference-free + reference-based)
│   │       ├── run_baseline.py             # baseline: submit golden dataset to raw GPT-4o (no RAG); compare scores (AC #14)
│   │       ├── run_style_comparison.py     # generate Book-Faithful + Coaching-Oriented responses per query; emit preference log (AC #15)
│   │       ├── metrics.py                  # metric configuration and thresholds
│   │       └── dataset.py                  # golden dataset loader from tests/
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py
│       └── test_metrics.py
│
├── apps/
│   └── client/                             # minimal internal test client (PRD Section 2.2)
│       ├── index.html                      # single input field + disclaimer banner
│       └── README.md                       # "internal testing only" notice
│
├── tests/
│   └── golden_dataset.json                 # questions only, no book excerpts (D-CA-2)
│
└── corpus/                                 # gitignored — local PDF source files
    └── BKF219/
        └── book.pdf
```

### Architectural Boundaries

**API Boundaries:**
- Single external endpoint: `POST /api/v1/query` (authenticated via `X-API-Key`)
- Health check: `GET /health` (unauthenticated, used by ALB)
- No internal service-to-service API calls in MVP

**Package Boundaries (import rules):**

```
libs/shared ←── apps/api
libs/shared ←── apps/ingestion
libs/shared ←── eval

apps/api ✗── apps/ingestion    (NEVER)
apps/ingestion ✗── apps/api    (NEVER)
```

**Layer Boundaries within `apps/api/`:**

```
api/routes → pipeline/orchestrator → pipeline/{classifier,retriever,reranker,generator}
                                   → pipeline/session (Redis)
api/routes → models/schemas (request/response types)
pipeline/* → shared/models/db (DB access)
pipeline/* → shared/exceptions (error raising)
api/exception_handlers → shared/exceptions (error catching → HTTP response)
```

- `api/` layer: HTTP concerns, auth, exception-to-response mapping
- `pipeline/` layer: business logic, external service calls, orchestration
- `models/` layer: data shapes (Pydantic schemas)
- `core/` layer: startup, DI wiring, config

**Data Boundaries:**
- PostgreSQL: chunk metadata, book catalog, session audit (via SQLAlchemy async)
- Qdrant: vector embeddings only (accessed via Qdrant async client)
- Redis: clarification session state (15-min TTL)
- S3: PDF source files (read-only from ingestion, SKU-prefixed)
- OpenAI: generation + classification + embeddings (stateless, zero-retention)

### Integration Points

**Internal Data Flow (Query):**

```
Client → ALB → Fargate → FastAPI route
  → QueryPipeline.execute()
    → Classifier (OpenAI GPT-4o-mini) → intent + filters
    → Retriever (Qdrant vectors + PostgreSQL BM25) → candidates (M=40)
    → Reranker (cross-encoder in-process) → top-K=5
    → Generator (OpenAI GPT-4o) → answer with citations
  → Pydantic response model → JSON response
```

**Internal Data Flow (Ingestion):**

```
GitHub Actions → AWS SSM Run Command → EC2/Fargate → ingestion CLI
  (trigger only — no content passes through GHA runners)
  → Scanner (corpus/ or S3) → book manifest
  → per-book pipeline:
    → Classifier → page types
    → Parser → hierarchical text
    → Extractor → visual content (landscape pages)
    → Chunker → chunks with metadata
    → Embedder (OpenAI text-embedding-3-large) → vectors
    → Loader → PostgreSQL (chunk metadata) + Qdrant (vectors)
```

**External Integrations:**
- OpenAI API: 3 model endpoints (GPT-4o, GPT-4o-mini, text-embedding-3-large)
- AWS S3: PDF storage (read-only)
- AWS SSM: ingestion trigger (Run Command)
- AWS Secrets Manager: secrets → ECS env vars → pydantic-settings

### Development Workflow Integration

**Local Development:**

```bash
docker compose up -d                          # Qdrant + PostgreSQL + Redis
cp .env.example .env                          # configure local secrets
uv sync                                       # install all workspace packages
uv run alembic upgrade head                   # run migrations
uv run fastapi dev apps/api/src/api_service/main.py  # live reload
```

**Testing:**

```bash
uv run pytest apps/api/tests/                 # API unit + integration tests
uv run pytest apps/ingestion/tests/           # ingestion tests
uv run pytest eval/tests/                     # eval pipeline tests
uv run python -m eval.run_ragas               # full RAGAS evaluation (merge-to-main only)
```

**Deployment (manual for MVP):**

```bash
docker build -f apps/api/Dockerfile -t plc-api .
docker build -f apps/ingestion/Dockerfile -t plc-ingestion .
# Push to ECR, update ECS task definition
```

---

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:** All technology choices are compatible. SQLAlchemy 2.0
async + asyncpg + FastAPI + Pydantic v2 is a well-tested combination. `structlog` +
`tenacity` + `pydantic-settings` are standard companions. No version conflicts.

**Pattern Consistency:** snake_case everywhere eliminates translation layers. Import
boundaries align with the package structure. Process patterns (lifespan clients,
Depends injection) are consistent with FastAPI idioms. No contradictions found.

**Structure Alignment:** The directory tree maps 1:1 to all architectural decisions.
Every decision has a home in the structure. Boundaries are clean.

### Requirements Coverage — FR Traceability

| FR | Requirement | Architectural Home | Status |
|---|---|---|---|
| FR-1 | Page classification | `apps/ingestion/classifier.py` | Covered |
| FR-2 | Hierarchical parsing | `apps/ingestion/parser.py` | Covered |
| FR-3 | Landscape extraction | `apps/ingestion/extractor.py` | Covered |
| FR-4 | Metadata schema on every chunk | `apps/ingestion/chunker.py` + `libs/shared/models/db.py` | Covered |
| FR-5 | Pre-build corpus scan | `apps/ingestion/scanner.py` | Covered |
| FR-6 | Direct answer (success) | `pipeline/orchestrator.py` → `pipeline/generator.py` | Covered |
| FR-7 | Ambiguity → needs_clarification | `pipeline/classifier.py` + `pipeline/session.py` | Covered |
| FR-8 | One-question hard limit | `pipeline/session.py` (Redis TTL + state) | Covered |
| FR-9 | Out-of-scope hard refusal | `pipeline/classifier.py` (pre-retrieval) | Covered |
| FR-10 | Metadata filter extraction | `pipeline/classifier.py` (same GPT-4o-mini pass) | Covered |
| FR-11 | Fallback when < 3 results | `pipeline/retriever.py` | Covered |
| FR-12 | Semantic search top-N | `pipeline/retriever.py` (Qdrant) | Covered |
| FR-13 | Keyword search top-N | `pipeline/retriever.py` (BM25) | Covered |
| FR-14 | Merge + re-rank top-K | `pipeline/retriever.py` + `pipeline/reranker.py` | Covered |

**All 14 FRs: Covered.**

### Requirements Coverage — NFR Traceability

| NFR | Requirement | Architectural Support | Status |
|---|---|---|---|
| PRD NFR | Requirement | Architectural Support | Status |
|---|---|---|---|
| NFR-001 | p95 ≤ 30s at 1–3 concurrent users | Async throughout + per-stage timing logs in `orchestrator.py` | Covered |
| NFR-002 | 95% uptime during business hours | Fargate + ALB health check | Covered |
| NFR-003 | 5 concurrent users without degradation | Async + connection pool (5) | Covered |
| NFR-004 | TLS 1.2+ in transit; KMS at rest | Infrastructure-level (ALB, RDS, ElastiCache, EBS) | Covered |
| NFR-005 | 90-day audit log retention; no PII in logs | CloudWatch log group config; structlog bound loggers | Covered |
| NFR-006 | RTO 4h / RPO 24h | RDS automated backups (7-day retention) | Covered |
| NFR-007 | Container vulnerability scanning; critical/high CVEs block deploy | ECR image scanning or Trivy step in GitHub Actions CI pipeline | Covered |
| Section 2.3 | RAGAS thresholds (Faithfulness ≥ 0.80, AR ≥ 0.75, CP/CR ≥ 0.70) | `eval/` pipeline | Covered |
| Section 2.3 | 100% out-of-scope refusal rate | Pre-retrieval classifier + golden dataset tests | Covered |
| Section 2.3 | Ambiguity detection precision ≥ 0.80, recall ≥ 0.70 | `pipeline/classifier.py` + labeled ambiguous test set in `tests/golden_dataset.json` | Covered |
| Section 2.3 | Max 1 clarification per session | Redis session state in `pipeline/session.py` | Covered |
| Section 2.3 | Golden dataset: ≥35 in-scope, ≥10 out-of-scope, ≥5 ambiguous | `tests/golden_dataset.json` | Covered |
| Section 7.2 | Zero OpenAI retention | DPA + API config | Covered |
| Section 8 (prev NFR-19) | Manual re-ingestion trigger | GitHub Actions → SSM Run Command | Covered |

**All PRD NFRs and quality targets: Covered.**

### Gap Analysis — Resolved

| Gap | Resolution |
|---|---|
| BM25 index storage | Build at API startup from PostgreSQL chunks; lives in lifespan state, injected via `Depends`. Re-ranker cold start dominates startup time; BM25 build is negligible at MVP corpus size. |
| Pipeline latency observability | `structlog` timing context per pipeline stage in `orchestrator.py` — log `classifier_ms`, `retriever_ms`, `reranker_ms`, `generator_ms` on every query. No new library needed. |
| Workspace members update | Root `pyproject.toml` members: `["apps/api", "apps/ingestion", "eval", "libs/shared"]` |
| `chunk_hash` column | Architecture addition to PRD schema for ingestion idempotency — add `chunk_hash` (string) column to `chunks` table. Unique constraint on `(book_id, page_number, chunk_hash)`. |
| Qdrant collection name | Constant `QDRANT_COLLECTION = "plc_copilot_v1"` in `libs/shared/config.py` as a `Settings` field. |
| Terraform and CI/CD (PRD v4.2 AC #1, #2) | Now in scope. `terraform/` directory at repo root covers all Zone A resources + commented-out Zones B/C. GitHub Actions `.github/workflows/ci.yml` runs lint → test → build → ECR push → Fargate deploy on push to `main`; `ingest.yml` triggers SSM Run Command. |
| RPO correction | PRD v4.2 NFR-006 relaxes RPO from 1h to 24h. Architecture NFR table updated accordingly. RDS 7-day automated backup retention remains the implementation. |
| Container vulnerability scanning (PRD v4.2 NFR-007) | ECR image scanning or Trivy step in GitHub Actions CI pipeline; critical/high CVEs block push to ECR. Assigned architectural home: `.github/workflows/ci.yml`. |
| Ambiguity detection metrics (PRD v4.2 FR-007, Section 2.3) | `pipeline/classifier.py` implements ambiguity classification; labeled ambiguous subset in `tests/golden_dataset.json` (≥5 questions); precision/recall measured in CI test suite. |
| Minimal test client (PRD v4.2 Section 2.2) | `apps/client/index.html` — single input field + disclaimer banner; no auth, no styling. Not a workspace member; served statically. |
| Eval pipeline gaps (PRD v4.2 AC #14, #15) | `eval/run_baseline.py` — submits golden dataset to raw GPT-4o without RAG context and compares RAGAS scores. `eval/run_style_comparison.py` — generates Book-Faithful and Coaching-Oriented responses per query and emits structured preference log. |

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**Architectural Decisions**
- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**Implementation Patterns**
- [x] Naming conventions established (snake_case everywhere)
- [x] Structure patterns defined (co-located tests, one file per concern, `libs/shared/`)
- [x] Process patterns documented (custom exceptions, structlog, lifespan clients, tenacity)
- [x] Test patterns specified (naming, fixtures, factories)
- [x] Enforcement rules and anti-patterns documented

**Project Structure**
- [x] Complete directory structure defined (including `terraform/`, `.github/workflows/`, `apps/client/`)
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete
- [x] All 13 FRs traceable to specific files
- [x] All PRD NFRs and quality targets architecturally supported
- [x] Terraform and CI/CD in scope and mapped to structure
- [x] Eval pipeline extended for baseline comparison and style preference collection

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — all FRs covered, all NFRs addressed, no critical gaps
remaining.

**Key Strengths:**
- Clean separation between API and ingestion packages with `libs/shared/` preventing
  circular dependencies
- Single retry authority (tenacity) prevents double-retry bugs
- Pre-retrieval out-of-scope detection saves compute on junk queries
- Lifespan-managed clients with Depends injection ensures testability
- Explicit anti-patterns prevent the most common AI agent mistakes
- Full FR and NFR traceability to specific files

**Areas for Future Enhancement (post-MVP):**
- Connection pool tuning when concurrent users exceed 5
- Rate limiting strategy before external-facing deployment
- Multi-AZ infrastructure for high availability
- CloudWatch advanced dashboards and metric alarms
- Distributed tracing (OpenTelemetry) for deeper latency analysis
- BM25 index pre-build optimization if corpus grows beyond 100k chunks
- Zone B (meeting transcripts) and Zone C (student directory) Terraform activation

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries — especially import rules
- Refer to this document for all architectural questions
- When in doubt, check the anti-patterns list before writing code

**First Implementation Priority:**
1. Terraform Zone A infrastructure (VPC, Fargate, Qdrant EC2, RDS, Redis, S3, ECR, ALB, Secrets Manager, IAM)
2. `uv init --bare` + workspace config with all four members (`apps/api`, `apps/ingestion`, `eval`, `libs/shared`)
3. `libs/shared/` package: config, logging, exceptions, DB models
4. `docker-compose.yml` for local Qdrant + PostgreSQL + Redis
5. `apps/api/` scaffold: FastAPI app, lifespan, health check
6. Alembic initial migration (importing models from `libs/shared/`)
7. GitHub Actions CI pipeline (lint → test → build → ECR push → Fargate deploy)
