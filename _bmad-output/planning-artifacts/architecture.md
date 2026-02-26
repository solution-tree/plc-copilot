---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - apps/api/docs/prd-v4.md
  - apps/api/docs/prd-v4-validation-report.md
  - apps/api/docs/research/ferpa-FINAL.md
workflowType: 'architecture'
project_name: 'plc-copilot'
user_name: 'vanes'
date: '2026-02-26'
lastStep: 8
status: 'complete'
completedAt: '2026-02-26'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

The system has 14 FRs across three functional areas:

- **Ingestion Pipeline (FR-1–FR-5):** A three-stage parser that classifies pages by orientation/text-layer, parses hierarchical structure from portrait pages via a self-hosted container, and extracts structured Markdown from landscape pages via a zero-retention vision model. Every chunk must carry complete metadata (book_title, authors, sku, chapter, section, page_number, chunk_type). A pre-build corpus scan is required before ingestion begins.

- **Query Engine (FR-6–FR-11):** A single endpoint serving three response modes — direct answer, conditional clarification, and out-of-scope refusal. Ambiguity detection uses a two-part test (meaningfully different answers + system cannot resolve alone). One-question hard limit on clarification. Metadata filters extracted from queries when recognized book titles, authors, or content-type keywords are present, with automatic fallback to unfiltered search when filtered results < 3.

- **Hybrid Search & Re-Ranking (FR-12–FR-14):** Semantic search (top-20 by vector similarity) and keyword search (top-20 by BM25 relevance) merged into a 40-candidate set, re-ranked by a neural cross-encoder, passing top-5 to the generation model. All retrieval parameters are tunable.

**Non-Functional Requirements:**

19 NFRs drive architectural decisions across two categories:

- **Quality & Performance (NFR-1–NFR-10):** RAGAS thresholds (Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70), 100% out-of-scope refusal rate, P95 response time ≤ 30s, 95% business-hours availability, 5 concurrent users minimum, golden dataset minimum 50 questions.

- **Security & Operational (NFR-11–NFR-19):** TLS 1.2+ everywhere, KMS at rest, zero-retention OpenAI, no PII in logs, 15-min session TTL, 90-day audit log retention, structured JSON observability, RTO 4h / RPO 1h, manual corpus re-ingestion.

**Scale & Complexity:**

- Primary domain: API backend (no UI for MVP)
- Complexity level: High
- Estimated architectural components: 8 (FastAPI service, LlamaIndex orchestration, Qdrant vector DB, PostgreSQL metadata store, Redis session cache, three-stage ingestion pipeline, in-process re-ranker, OpenAI LLM/embedding integration)

### Technical Constraints & Dependencies

- **Terraform-only IaC** — no ClickOps, CloudFormation, or CDK
- **Single AZ** for MVP cost optimization
- **Ingestion inside VPC** via SSM Run Command on EC2 — proprietary content never on public runners
- **Self-hosted Qdrant** on EC2 in private VPC — proprietary embeddings under direct control
- **BM25 at application layer** (LlamaIndex BM25Retriever) — avoids PostgreSQL ts_rank scaling issues
- **In-process re-ranker** — cross-encoder co-located in Fargate container, no separate service
- **Zero-retention OpenAI** — DPA executed, no PII sent in MVP
- **All secrets from AWS Secrets Manager** via IAM roles — never in code or env files
- **FERPA-forward design** — Three-Zone Tenant Enclave with Zones B/C as commented Terraform

### Cross-Cutting Concerns Identified

- **Security & encryption** — pervasive across all components (KMS, TLS, no PII in logs, secrets management)
- **Metadata consistency** — chunk metadata schema enforced from ingestion through retrieval to citation
- **Observability** — structured JSON logging for key events, CloudWatch integration, 30-day retention
- **Session management** — Redis-backed clarification state with TTL, cross-request correlation via conversation_id
- **Error handling** — five distinct error responses (401, 422, 400, 503, 500) with specific contract
- **Evaluation pipeline** — RAGAS integration as a continuous quality signal, not just post-build validation

## Starter Template Evaluation

### Primary Technology Domain

Python 3.11+ API Backend — identified from PRD Section 7 technology stack and project classification (api_backend, high complexity).

### Technical Preferences (Pre-Established)

The following technical decisions are locked in by the PRD and project configuration:

- **Language:** Python 3.11+ with type hints on all public signatures
- **Framework:** FastAPI with Pydantic v2
- **Linter/Formatter:** ruff (format + lint)
- **Testing:** pytest
- **ORM/DB Access:** Direct PostgreSQL access (no ORM specified — SQLAlchemy 2.0 or asyncpg TBD in architecture decisions)
- **Vector DB Client:** Qdrant Python client
- **RAG Orchestration:** LlamaIndex
- **Containerization:** Docker (single container with re-ranker)
- **Cloud:** AWS (Fargate, RDS, ElastiCache, EC2, S3)
- **IaC:** Terraform
- **CI/CD:** GitHub Actions

### Starter Options Considered

| Option | Type | Fit Score | Key Concern |
|--------|------|-----------|-------------|
| Custom scaffold | Manual | High | Requires manual setup of boilerplate (Docker, CI, testing config) |
| fastapi_template (s3rius) | CLI generator | Medium | ~30% coverage; monorepo restructuring needed |
| Tiangolo full-stack template | Copier | Low | Full-stack oriented; heavy stripping for API-only monorepo service |

### Selected Approach: Custom Scaffold

**Rationale:** The project's tech stack is comprehensively defined in the PRD, and the planned source layout is already documented in `apps/api/CLAUDE.md`. No existing starter template provides meaningful coverage of the RAG-specific components (LlamaIndex orchestration, Qdrant integration, three-stage ingestion pipeline, cross-encoder re-ranker, Redis clarification session management) that constitute the core architecture. Using a generic starter would require more stripping and restructuring than building from the planned layout.

**Initialization approach:** The first implementation story should scaffold the project structure following the planned layout in `apps/api/CLAUDE.md`, including:

- `pyproject.toml` with all dependencies (FastAPI, Pydantic v2, LlamaIndex, qdrant-client, redis, etc.)
- `Dockerfile` for single-container deployment (API + re-ranker)
- `apps/api/src/` directory structure per planned layout
- ruff configuration
- pytest configuration with `apps/api/tests/` structure
- `.github/workflows/` CI pipeline stub

**Architectural Decisions Provided by Approach:**

- **Language & Runtime:** Python 3.11+, async FastAPI, Pydantic v2 for all schemas
- **Build Tooling:** pyproject.toml (PEP 621), ruff for linting/formatting
- **Testing Framework:** pytest with asyncio support
- **Code Organization:** Layered structure — api/routes, schemas, services, ingestion, config
- **Development Experience:** uvicorn with --reload, ruff watch, pytest-watch

**Note:** Project initialization should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- PostgreSQL access layer, migration strategy, logging framework, dependency injection pattern

**Important Decisions (Shape Architecture):**
- Docker base image, settings management, error handling, testing strategy

**Deferred Decisions (Post-MVP):**
- Rate limiting strategy (PRD Decision #12)
- Full user authentication — OAuth/JWT (PRD Section 6.1)
- WCAG accessibility (PRD Decision #13)
- Multi-AZ deployment
- Distributed tracing and dashboards (PRD Section 7.1)

### Data Architecture

| Decision | Choice | Version | Rationale |
|----------|--------|---------|-----------|
| PostgreSQL access layer | SQLAlchemy 2.0 async | 2.0.47 | Industry standard with FastAPI; ORM simplifies the 2-table model; native Pydantic v2 conversion; async engine fits FastAPI |
| Migration strategy | Alembic | 1.18.4 | Bundled with SQLAlchemy; version-controlled schema migrations out of the box |

Affects: Database models, ingestion pipeline (chunk writes), query engine (citation lookups)

### Authentication & Security

No open decisions — all security architecture is locked in by the PRD:
- Static API key via `X-API-Key` header (PRD Section 6.1)
- AWS Secrets Manager via IAM for all secrets (PRD Section 7.1)
- KMS at rest, TLS 1.2+ in transit (PRD Section 8.2)
- Zero-retention OpenAI with executed DPA (PRD Section 7)
- No PII in logs (PRD Section 4.2, NFR-14)

### API & Communication Patterns

| Decision | Choice | Version | Rationale |
|----------|--------|---------|-----------|
| Logging framework | structlog | 25.5.0 | Processor pipeline enables automatic PII sanitization; native structured JSON output for CloudWatch; async-friendly |
| Dependency injection | Centralized `deps.py` with FastAPI `Depends()` | N/A | Single file for all shared resources; predictable for developers and AI agents; easy to split later |
| Error handling | Custom exception classes + FastAPI exception handlers | N/A | 1:1 mapping to PRD's 5 error responses; self-documenting exceptions; centralized error contract |
| Settings management | Pydantic Settings (`pydantic-settings`) | N/A | Native Pydantic v2 integration; auto-reads env vars from Secrets Manager/Fargate; type validation at startup |

### Frontend Architecture

Not applicable — MVP is API-only with no UI (PRD Section 2.2).

### Infrastructure & Deployment

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Docker base image | `python:3.11-slim` | Balanced size (~150MB) vs. compatibility; avoids Alpine build issues with ML packages (cross-encoder, LlamaIndex) |
| Testing strategy | Layered: mocked unit tests + testcontainers integration + RAGAS evaluation | Fast local feedback via mocks; real-service confidence via testcontainers in CI; separate evaluation pipeline for quality metrics |

All other infrastructure decisions locked in by PRD: Fargate, single AZ, Terraform, GitHub Actions, VPC with private subnets, NAT Gateway.

### Decision Impact Analysis

**Implementation Sequence:**
1. SQLAlchemy 2.0 + Alembic (models and migrations come first)
2. Pydantic Settings (config needed before any service connects)
3. structlog (logging wired in early)
4. `deps.py` with FastAPI `Depends()` (wires DB, Redis, Qdrant)
5. Custom exceptions + handlers (error contract before business logic)
6. Docker `python:3.11-slim` (containerization after app scaffold)
7. Test infrastructure (mocks + testcontainers setup)

**Cross-Component Dependencies:**
- SQLAlchemy models inform Alembic migrations and Pydantic response schemas
- Pydantic Settings feeds connection strings to `deps.py` dependencies
- structlog processors depend on the PII sanitization rules from security requirements
- Exception handlers depend on the error contract defined in the PRD
- Testcontainers config mirrors the real infrastructure (Postgres, Redis, Qdrant)

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**6 critical conflict areas** identified and resolved to ensure AI agents produce compatible, consistent code.

### Naming Patterns

**Database Naming Conventions:**
- Tables: `snake_case`, **plural** — `books`, `chunks` (matches PRD Section 5.1)
- Columns: `snake_case` — `book_id`, `text_content`, `page_number`
- Foreign keys: `{referenced_table_singular}_id` — `book_id` on `chunks`
- Indexes: `ix_{table}_{column}` — `ix_chunks_book_id`
- Constraints: `pk_{table}` for primary keys, `fk_{table}_{column}` for foreign keys, `uq_{table}_{column}` for unique

**API / JSON Naming Conventions:**
- All JSON fields: `snake_case` — no exceptions
- Matches PRD contract: `book_title`, `page_number`, `text_excerpt`, `conversation_id`, `session_id`, `clarification_question`
- Any new fields added during implementation must follow `snake_case`

**Code Naming Conventions:**
- Per CLAUDE.md: variables/functions `snake_case`, classes `PascalCase`, constants `UPPER_SNAKE_CASE`
- Files/directories: `snake_case` — `query_engine.py`, `scope_guard.py`
- Package name: `plc_coach` (defined in `pyproject.toml`)
- Imports: absolute from package root — `from plc_coach.services.query_engine import QueryEngine`

### Structure Patterns

**Project Organization:**
- Domain-grouped files — related logic stays together (e.g., `services/query_engine.py` contains `QueryEngine` plus its private helpers)
- No strict one-class-per-file rule; split only when a file exceeds ~300 lines or has clearly separable concerns
- Shared utilities go in `plc_coach/utils/` only when used by 2+ modules; otherwise keep private to the owning module

**Test Organization:**
- Mirror source tree: `tests/services/test_query_engine.py`, `tests/schemas/test_request.py`
- `conftest.py` per directory — shared fixtures in `tests/conftest.py`, scoped fixtures in subdirectory `conftest.py` files
- Golden dataset fixtures stay in `tests/fixtures/`

### Format Patterns

**API Response Formats:**
- Three response statuses only: `success`, `needs_clarification`, `out_of_scope` (PRD Section 6.3)
- No envelope wrapper — responses are flat Pydantic models, not wrapped in `{"data": ...}`
- Error responses use the exact HTTP status codes and body shapes from PRD Section 6.4

**Date/Time Formats:**
- Database: PostgreSQL `timestamp with time zone`
- JSON/API: ISO 8601 strings (`2026-02-26T17:30:00Z`)
- Internal Python: `datetime.datetime` with UTC timezone

### Communication Patterns

**Logging Patterns (structlog):**
- One logger per module: `logger = structlog.get_logger(__name__)`
- Event names: `snake_case` verbs — `query_received`, `answer_generated`, `scope_check_failed`
- Bound context for request tracing: `logger.bind(conversation_id=..., user_id=...)`
- NEVER log raw query text, answer text, or PII — metadata only (NFR-14)
- Log levels: `info` for business events, `warning` for fallbacks/degradation, `error` for failures requiring attention

**No Event System for MVP:**
- No pub/sub, message bus, or event sourcing
- Direct service-to-service calls via dependency injection
- Event patterns deferred to post-MVP

### Process Patterns

**Error Handling:**
- Flat exception hierarchy — single `PLCCoachError` base class
- One exception per PRD error response:

| Exception | HTTP Status | Maps To |
|-----------|-------------|---------|
| `UnauthorizedError` | 401 | Missing/invalid API key |
| _(Pydantic validation)_ | 422 | Malformed request body |
| `SessionExpiredError` | 400 | Expired/invalid session_id |
| `ServiceUnavailableError` | 503 | LLM or vector DB failure |
| `PLCCoachError` (base, catch-all) | 500 | Unexpected error |

- All exceptions registered as FastAPI exception handlers in `main.py`
- Services raise domain exceptions; route handlers never catch them directly

**Service Layer Patterns:**
- Classes with injected dependencies — constructor receives clients/config
- Wired via `deps.py` using FastAPI `Depends()` chain
- Example: `QueryEngine(qdrant_client, redis_client, reranker)`

**Async Pattern:**
- Route handlers: `async def` (FastAPI requirement)
- Network I/O (Qdrant, OpenAI, Redis): `async`/`await`
- CPU-bound work (re-ranker inference, BM25 scoring): plain sync — no `run_in_executor` wrappers
- Service methods that mix both: `async def` that awaits network calls, then calls sync methods inline

**Retry & Resilience:**
- Retry only on transient network failures (OpenAI 429/503, Qdrant connection errors)
- Max 3 retries with exponential backoff
- No retry on validation errors, auth errors, or business logic failures
- Circuit breaking deferred to post-MVP

### Enforcement Guidelines

**All AI Agents MUST:**
- Use absolute imports from `plc_coach` package root
- Follow the flat exception hierarchy — never create exception subclasses beyond the 4 defined above
- Use `structlog.get_logger(__name__)` — never `logging.getLogger` or print statements
- Name test files mirroring source: `test_{source_filename}.py`
- Use `snake_case` for all JSON fields, database columns, Python variables, and log event names
- Create service classes with constructor injection, never module-level singletons

**Pattern Verification:**
- ruff enforces code style (naming, imports, formatting)
- PR review checklist includes pattern compliance
- Test names must follow `test_what_when_then` convention

## Project Structure & Boundaries

### Complete Project Directory Structure

```
plc-copilot/                              # Monorepo root
├── .github/
│   └── workflows/
│       ├── ci.yml                        # Lint, test, build pipeline
│       └── deploy.yml                    # ECR push + Fargate deploy
├── apps/
│   ├── api/                              # PLC Coach Service
│   │   ├── pyproject.toml               # PEP 621 — deps, ruff, pytest config
│   │   ├── Dockerfile                   # python:3.11-slim, single container (API + re-ranker)
│   │   ├── alembic.ini                  # Alembic config pointing to migrations/
│   │   ├── alembic/
│   │   │   ├── env.py                   # Async engine setup for migrations
│   │   │   └── versions/               # Auto-generated migration scripts
│   │   ├── src/
│   │   │   └── plc_coach/              # Importable package root
│   │   │       ├── __init__.py
│   │   │       ├── api/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── main.py          # FastAPI app, lifespan, middleware, exception handlers
│   │   │       │   └── routes/
│   │   │       │       ├── __init__.py
│   │   │       │       ├── query.py     # POST /api/v1/query handler
│   │   │       │       └── health.py    # GET /health (ALB health check, no auth)
│   │   │       ├── schemas/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── request.py       # QueryRequest (Pydantic v2)
│   │   │       │   └── response.py      # QueryResponse, Source, error models
│   │   │       ├── models/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── book.py          # SQLAlchemy Book model
│   │   │       │   └── chunk.py         # SQLAlchemy Chunk model
│   │   │       ├── services/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── query_engine.py  # LlamaIndex orchestration, hybrid search, re-rank
│   │   │       │   ├── clarification.py # Ambiguity detection, Redis session management
│   │   │       │   └── scope_guard.py   # Out-of-scope detection
│   │   │       ├── ingestion/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── pipeline.py      # Three-stage parser orchestrator
│   │   │       │   ├── pymupdf_classifier.py  # Page orientation + text-layer detection
│   │   │       │   ├── llmsherpa_parser.py    # Portrait page parsing via nlm-ingestor
│   │   │       │   ├── vision_parser.py       # Landscape page → GPT-4o Vision
│   │   │       │   └── metadata.py      # ChunkMetadata schema + validation
│   │   │       ├── config/
│   │   │       │   ├── __init__.py
│   │   │       │   ├── settings.py      # Pydantic Settings (env / Secrets Manager)
│   │   │       │   └── logging.py       # structlog processor pipeline + PII sanitizer
│   │   │       ├── deps.py              # Centralized FastAPI Depends() — DB, Redis, Qdrant, services
│   │   │       └── exceptions.py        # PLCCoachError base + flat exception hierarchy
│   │   ├── scripts/
│   │   │   ├── corpus_scan.py           # Pre-build corpus analysis (PRD Section 10)
│   │   │   └── ingest.py               # Full ingestion entry point (runs via SSM in VPC)
│   │   ├── tests/
│   │   │   ├── conftest.py              # Shared fixtures — async client, DB session, mock settings
│   │   │   ├── fixtures/
│   │   │   │   └── golden_dataset.json  # Evaluation queries (in-scope + out-of-scope + ambiguous)
│   │   │   ├── schemas/
│   │   │   │   ├── conftest.py
│   │   │   │   ├── test_request.py
│   │   │   │   └── test_response.py
│   │   │   ├── services/
│   │   │   │   ├── conftest.py          # Service-specific fixtures — mock Qdrant, mock Redis
│   │   │   │   ├── test_query_engine.py
│   │   │   │   ├── test_clarification.py
│   │   │   │   └── test_scope_guard.py
│   │   │   ├── ingestion/
│   │   │   │   ├── conftest.py
│   │   │   │   ├── test_pipeline.py
│   │   │   │   ├── test_pymupdf_classifier.py
│   │   │   │   └── test_metadata.py
│   │   │   ├── integration/
│   │   │   │   ├── conftest.py          # Testcontainers — Postgres, Redis, Qdrant
│   │   │   │   └── test_query_flow.py   # End-to-end query through real services
│   │   │   └── evaluation/
│   │   │       └── test_ragas.py        # RAGAS evaluation pipeline against golden dataset
│   │   └── docs/
│   │       ├── prd-v4.md
│   │       └── research/
│   │           └── ferpa-FINAL.md
│   ├── teachers-portal/                 # (Planned — empty)
│   └── admins-portal/                   # (Planned — empty)
├── infra/
│   └── terraform/                       # (Future — all AWS resources)
├── packages/                            # (Planned — shared code, empty)
├── .gitignore
├── CLAUDE.md
├── CONTRIBUTING.md
└── README.md
```

### Architectural Boundaries

**API Boundary (External):**
- Single entry point: `POST /api/v1/query`
- Authentication: `X-API-Key` header validated in middleware (`main.py`)
- Request/response contract defined exclusively in `schemas/` — route handlers accept `QueryRequest`, return `QueryResponse`
- No direct database or service access from route handlers — everything through `deps.py`

**Service Boundary (Internal):**
- `routes/query.py` → calls services via injected dependencies, never instantiates directly
- `services/query_engine.py` → orchestrates search + re-rank, calls Qdrant and OpenAI
- `services/clarification.py` → manages Redis session state, decides whether to clarify
- `services/scope_guard.py` → classifies in-scope vs out-of-scope before query engine runs
- Services may call each other only through constructor injection — no circular dependencies

**Data Boundary:**
- `models/` — SQLAlchemy models are the only code that touches PostgreSQL
- Qdrant access isolated to `services/query_engine.py` (search) and `ingestion/pipeline.py` (upsert)
- Redis access isolated to `services/clarification.py` (session state) and `deps.py` (connection)
- No raw SQL anywhere — all queries through SQLAlchemy ORM

**Ingestion Boundary:**
- `ingestion/` is a self-contained pipeline — shares `models/` and `config/` but does not import from `services/` or `api/`
- Runs as a separate process via `scripts/ingest.py` — never triggered by the API
- `scripts/corpus_scan.py` is read-only analysis — no writes to any datastore

### Requirements to Structure Mapping

**Ingestion Pipeline (FR-1 → FR-5):**

| FR | File(s) |
|----|---------|
| FR-1: Page classification | `ingestion/pymupdf_classifier.py` |
| FR-2: Hierarchical parsing | `ingestion/llmsherpa_parser.py` |
| FR-3: Visual content extraction | `ingestion/vision_parser.py` |
| FR-4: Metadata enforcement | `ingestion/metadata.py` |
| FR-5: Pre-build corpus scan | `scripts/corpus_scan.py` |

**Query Engine (FR-6 → FR-11):**

| FR | File(s) |
|----|---------|
| FR-6: Direct answer | `services/query_engine.py`, `routes/query.py` |
| FR-7: Ambiguity detection | `services/clarification.py` |
| FR-8: One-question limit | `services/clarification.py` |
| FR-9: Out-of-scope refusal | `services/scope_guard.py` |
| FR-10: Metadata filter extraction | `services/query_engine.py` |
| FR-11: Filter fallback (< 3 results) | `services/query_engine.py` |

**Hybrid Search & Re-Ranking (FR-12 → FR-14):**

| FR | File(s) |
|----|---------|
| FR-12: Semantic search (top-20) | `services/query_engine.py` |
| FR-13: Keyword search / BM25 (top-20) | `services/query_engine.py` |
| FR-14: Merge + re-rank (top-5) | `services/query_engine.py` |

**Cross-Cutting Concerns:**

| Concern | File(s) |
|---------|---------|
| Authentication (API key) | `api/main.py` (middleware) |
| Settings management | `config/settings.py` |
| Structured logging | `config/logging.py` |
| PII sanitization | `config/logging.py` (structlog processor) |
| Exception handling | `exceptions.py` + `api/main.py` (handlers) |
| Dependency injection | `deps.py` |
| Database models + migrations | `models/`, `alembic/` |

### Data Flow

**Query Flow (runtime):**
```
Client → ALB → Fargate
  → main.py (API key check, structlog bind)
    → routes/query.py (parse QueryRequest)
      → scope_guard.py (in-scope check → out_of_scope or continue)
      → clarification.py (ambiguity check → needs_clarification or continue)
      → query_engine.py
        → Qdrant (semantic search, top-20)
        → BM25Retriever (keyword search, top-20)
        → cross-encoder (re-rank merged 40 → top-5)
        → OpenAI GPT-4o (generate answer from top-5 context)
      → routes/query.py (build QueryResponse with sources)
    → Client
```

**Ingestion Flow (offline, via SSM):**
```
scripts/ingest.py
  → pipeline.py (orchestrator)
    → pymupdf_classifier.py (classify every page)
    → llmsherpa_parser.py (portrait pages → structured chunks)
    → vision_parser.py (landscape pages → GPT-4o Vision → Markdown)
    → metadata.py (validate ChunkMetadata — fail on missing fields)
    → OpenAI text-embedding-3-large (embed chunks → 3072-dim vectors)
    → Qdrant (upsert vectors + payload)
    → PostgreSQL (insert books + chunks via SQLAlchemy)
```

### Development Workflow Integration

**Local development:**
```bash
uvicorn plc_coach.api.main:app --reload          # API server
pytest apps/api/tests/ -v                          # Unit tests (mocked)
pytest apps/api/tests/integration/ -v              # Integration (testcontainers)
ruff check apps/api/src/ && ruff format apps/api/src/  # Lint + format
alembic -c apps/api/alembic.ini upgrade head       # Run migrations
```

**CI pipeline (GitHub Actions):**
1. `ruff check` + `ruff format --check` — code style
2. `pytest apps/api/tests/ -v --ignore=apps/api/tests/integration --ignore=apps/api/tests/evaluation` — unit tests
3. `pytest apps/api/tests/integration/ -v` — integration tests (testcontainers)
4. Docker build + push to ECR
5. Deploy to Fargate (deploy workflow, manual trigger)

**RAGAS evaluation (separate from CI):**
```bash
pytest apps/api/tests/evaluation/test_ragas.py -v  # Run against live or staging
```

## Architecture Validation Results

### Coherence Validation

**Decision Compatibility:** All technology choices are compatible and well-tested together. SQLAlchemy 2.0 async integrates cleanly with FastAPI's async runtime. Pydantic v2 is natively supported by both FastAPI and Pydantic Settings. structlog's processor pipeline works without conflict alongside FastAPI's middleware chain. Alembic 1.18 supports SQLAlchemy 2.0's async engine. The `python:3.11-slim` Docker base image supports all ML dependencies (cross-encoder, LlamaIndex, PyMuPDF) without Alpine build issues.

**Pattern Consistency:** All naming conventions are snake_case throughout — database columns, JSON fields, Python code, log events, file names. The class-based DI pattern aligns with FastAPI's `Depends()` system. The flat exception hierarchy maps 1:1 to PRD error responses. Test mirroring pattern works naturally with pytest's conftest discovery.

**Structure Alignment:** The `plc_coach` package with src layout supports absolute imports. Domain-grouped files align with the service class pattern. The ingestion boundary (no imports from `services/` or `api/`) prevents circular dependencies. Test structure mirrors source, enabling easy navigation.

### Requirements Coverage Validation

**Functional Requirements (FR-1 → FR-14):** All 14 FRs mapped to specific source files in the project structure. No FR lacks architectural support.

**Non-Functional Requirements (NFR-1 → NFR-19):**

| NFR | Architectural Support |
|-----|----------------------|
| NFR-1 to NFR-4 (RAGAS thresholds) | `tests/evaluation/test_ragas.py` + golden dataset |
| NFR-5 (100% out-of-scope refusal) | `services/scope_guard.py` + golden dataset out-of-scope queries |
| NFR-6 (1 clarification max) | `services/clarification.py` + Redis session with one-question enforcement |
| NFR-7 (P95 ≤ 30s) | In-process re-ranker (no network hop), async I/O for Qdrant/OpenAI |
| NFR-8 (95% availability) | Fargate managed compute + ALB health checks |
| NFR-9 (5 concurrent users) | Async FastAPI + connection pooling via SQLAlchemy/Redis |
| NFR-10 (50+ golden questions) | `tests/fixtures/golden_dataset.json` already in repo |
| NFR-11 (TLS 1.2+) | Terraform ALB/RDS/ElastiCache config |
| NFR-12 (KMS at rest) | Terraform RDS/S3/EBS encryption config |
| NFR-13 (zero-retention OpenAI) | OpenAI client config + DPA documentation |
| NFR-14 (no PII in logs) | `config/logging.py` structlog PII sanitizer processor |
| NFR-15 (15-min session TTL) | `services/clarification.py` Redis TTL + `SessionExpiredError` |
| NFR-16 (90-day audit logs) | CloudWatch log group retention config (Terraform) |
| NFR-17 (structured JSON logs) | structlog JSON renderer → CloudWatch |
| NFR-18 (RTO 4h / RPO 1h) | RDS automated backups (Terraform) |
| NFR-19 (manual re-ingestion) | `scripts/ingest.py` triggered via SSM |

### Gap Analysis — Resolved

**Gap 1 (Resolved): Resource Lifecycle / Lifespan Pattern**

Heavy resources are loaded once at startup via FastAPI's `lifespan` context manager and stored in `app.state`. Per-request resources are created fresh in `deps.py`.

| Resource | Lifecycle | Where |
|----------|-----------|-------|
| Cross-encoder re-ranker model | Singleton — loaded in `lifespan`, stored in `app.state.reranker` | `api/main.py` |
| BM25 index | Singleton — built in `lifespan` from PostgreSQL chunks, stored in `app.state.bm25_index` | `api/main.py` |
| Qdrant client | Singleton — connected in `lifespan`, stored in `app.state.qdrant` | `api/main.py` |
| OpenAI client | Singleton — initialized in `lifespan`, stored in `app.state.openai` | `api/main.py` |
| SQLAlchemy async engine | Singleton — created in `lifespan`, stored in `app.state.db_engine` | `api/main.py` |
| Redis connection pool | Singleton — created in `lifespan`, stored in `app.state.redis` | `api/main.py` |
| DB session | Per-request — created from `app.state.db_engine` in `deps.py` | `deps.py` |
| Service instances (QueryEngine, etc.) | Per-request — constructed in `deps.py` with singleton deps from `app.state` | `deps.py` |

**Gap 2 (Resolved): Health Check Endpoint**

`GET /health` returning `{"status": "ok"}` with HTTP 200. Located in `api/routes/health.py`. Used by ALB target group health check. No authentication required.

**Gap 3 (Resolved): BM25 Index Lifecycle**

The BM25 index is built at application startup from all chunk text in PostgreSQL:
1. `lifespan` queries all `chunks.text_content` from PostgreSQL
2. Passes text corpus to LlamaIndex `BM25Retriever` to build the in-memory index
3. Stored in `app.state.bm25_index`
4. After re-ingestion, the API container is restarted to rebuild the index

Acceptable for MVP (~25 books, estimated ~10k chunks). Post-MVP optimization: pre-build and serialize the index during ingestion.

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed (8 components, high complexity)
- [x] Technical constraints identified (Terraform-only, VPC ingestion, single AZ)
- [x] Cross-cutting concerns mapped (security, metadata, observability, sessions, errors, evaluation)

**Architectural Decisions**
- [x] Critical decisions documented with versions (SQLAlchemy 2.0.47, Alembic 1.18.4, structlog 25.5.0)
- [x] Technology stack fully specified per PRD Section 7
- [x] Integration patterns defined (DI via deps.py, lifespan for singletons)
- [x] Performance considerations addressed (in-process re-ranker, async I/O, BM25 at app layer)

**Implementation Patterns**
- [x] Naming conventions established (snake_case everywhere, PascalCase classes, UPPER_SNAKE constants)
- [x] Structure patterns defined (domain-grouped files, mirror test tree, conftest per directory)
- [x] Communication patterns specified (structlog per module, no event system for MVP)
- [x] Process patterns documented (flat exceptions, class DI, async at boundaries, retry with backoff)

**Project Structure**
- [x] Complete directory structure defined with every file annotated
- [x] Component boundaries established (API, service, data, ingestion)
- [x] Integration points mapped (data flow diagrams for query + ingestion)
- [x] Requirements to structure mapping complete (all 14 FRs → specific files)

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — all FRs and NFRs have explicit architectural support, all technology decisions are versioned and compatible, patterns are comprehensive with enforcement guidelines.

**Key Strengths:**
- PRD-first architecture — every decision traces back to a specific requirement
- Clear boundaries — ingestion, query, and infrastructure are fully isolated
- Agent-friendly — naming conventions, DI patterns, and exception hierarchy leave no room for interpretation
- FERPA-forward — Zone A built, Zones B/C prepared as commented Terraform

**Areas for Future Enhancement:**
- BM25 index serialization (avoid rebuild on every restart)
- Circuit breaker for OpenAI/Qdrant (post-MVP resilience)
- Distributed tracing with request correlation IDs
- Rate limiting middleware
- Multi-AZ deployment for higher availability

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries — especially the ingestion/services separation
- Refer to this document for all architectural questions
- When in doubt, the PRD v4 is the ultimate source of truth

**First Implementation Priority:**
Project scaffold — `pyproject.toml`, directory structure, `Dockerfile`, ruff/pytest config, `settings.py`, `main.py` with lifespan stub, `health.py`, CI pipeline.

