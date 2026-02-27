---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - apps/api/docs/prd-v4.md
  - apps/api/docs/prd-v4-validation-report.md
  - apps/api/docs/research/ferpa-FINAL.md
workflowType: 'architecture'
project_name: 'plc-copilot'
user_name: 'vanes'
date: '2026-02-27'
lastStep: 8
status: 'complete'
completedAt: '2026-02-27'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

The PRD v4.2 defines 13 functional requirements across three areas:

- **Ingestion Pipeline (FR-001 through FR-004):** Processes the 25-book PLC @ Work corpus into a searchable knowledge base. FR-001 triggers ingestion of all books from S3 into the vector store and relational metadata database. FR-002 implements layout-aware parsing that classifies each page by orientation (portrait vs. landscape) and text-layer presence, routing pages to the appropriate parser — portrait pages with text layers are parsed for hierarchical structure; landscape pages are processed by a vision model that generates structured textual descriptions; pages without text layers are flagged for manual review. FR-003 enforces a standardized metadata schema on every chunk (book title, authors, SKU, chapter, section, page number, content type). FR-004 provides a pre-build corpus scan to validate assumptions about the corpus before ingestion begins.

- **Query Engine (FR-005 through FR-010):** A single endpoint (`POST /api/v1/query`) serving three response modes — direct answer (`success`), conditional clarification (`needs_clarification`), and out-of-scope refusal (`out_of_scope`). FR-005 handles clear, in-scope queries with grounded, cited answers. FR-006 returns clarification when a query is ambiguous per FR-007's two-part test. FR-007 defines ambiguity as requiring both conditions: (a) the answer would reference different books/chapters/concepts depending on interpretation, AND (b) the correct interpretation cannot be determined from the query text alone. FR-008 imposes a one-question hard limit on clarification — if the follow-up is still ambiguous, the system provides its best-interpretation answer with a statement of that interpretation appended. FR-009 returns a hard refusal for out-of-scope queries. FR-010 supports dynamic metadata filtering when queries reference specific books, authors, or content types, with automatic fallback to unfiltered search when filtered results return fewer than three hits.

- **Hybrid Search & Re-Ranking (FR-011 through FR-013):** FR-011 provides semantic search via vector embeddings for conceptually similar content. FR-012 provides keyword search critical for PLC-specific jargon and acronyms (RTI, SMART goals, guaranteed and viable curriculum). FR-013 re-ranks the merged result set using a neural cross-encoder before passing top results to the generation model. Each component requires ablation testing to demonstrate its contribution to answer quality.

**Non-Functional Requirements:**

The PRD defines 7 NFRs, all scoped to an internal testing tool with a small user base:

| NFR | Description | Target | Measurement |
|-----|-------------|--------|-------------|
| NFR-001 | Response Time | P95 ≤ 30 seconds under normal load (1–3 concurrent users) | Request duration monitoring |
| NFR-002 | Availability | 95% uptime during business hours (8 AM – 6 PM ET, weekdays) | Health-check monitoring on load balancer |
| NFR-003 | Concurrent Users | At least 5 concurrent query requests without degradation | Load testing against NFR-001 thresholds |
| NFR-004 | Data Encryption | TLS 1.2+ in transit, managed encryption key service at rest, no exceptions | Infrastructure audit |
| NFR-005 | Audit Log Retention | Structured JSON logs retained 90 days minimum; never contain PII, even in debug mode | Log retention policy verification |
| NFR-006 | Backup & Recovery | RTO 4 hours, RPO 24 hours; vector store reconstructable via re-ingestion | Backup configuration audit, recovery drill |
| NFR-007 | Security Scanning | Container images scanned; critical and high-severity CVEs resolved before deployment | CI pipeline scan results |

**Additional Architectural Constraints (derived from PRD Sections 2.3, 5–7, 9):**

Beyond the formal NFRs, the PRD establishes constraints that drive architectural decisions:

- **Quality thresholds:** RAGAS scores — Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70 (Section 2.3)
- **Out-of-scope refusal rate:** 100% of out-of-scope test queries must return the hard refusal (Section 2.3)
- **Ambiguity detection:** Precision ≥ 0.80, recall ≥ 0.70 (FR-007 test criteria)
- **Golden dataset:** Minimum 50 questions (target 100): at least 35 in-scope, 10 out-of-scope, 5 ambiguous (Section 2.3)
- **Session management:** Redis-backed clarification state; session TTL defined by implementation (Section 5)
- **Security:** Zero-retention OpenAI via executed DPA; static API key via `X-API-Key` header; no PII in logs even in debug mode (Sections 5.1, 7.2)
- **Observability:** Structured JSON audit logs to centralized log store; basic CloudWatch log groups for MVP (Section 6.2)
- **Baseline comparison:** RAG pipeline must exceed raw GPT-4o scores on Faithfulness and Answer Relevancy (Section 2.3)

**Scale & Complexity:**

- Primary domain: API backend (no UI for MVP)
- Complexity level: High — RAG pipeline with hybrid search, neural re-ranking, multi-stage ingestion, ambiguity detection, session state management, and FERPA-forward security architecture
- Estimated architectural components: 8 (FastAPI service, LlamaIndex orchestration, Qdrant vector DB, PostgreSQL metadata store, Redis session cache, three-stage ingestion pipeline, in-process re-ranker, OpenAI LLM/embedding integration)

### Technical Constraints & Dependencies

- **Terraform-only IaC** — no ClickOps, CloudFormation, or CDK
- **Single AZ** for MVP cost optimization (PRD Section 6.2)
- **Ingestion inside VPC** via SSM Run Command on EC2 — proprietary content never on public runners (PRD Decision #10)
- **Self-hosted Qdrant** on EC2 in private VPC — proprietary embeddings under direct organizational control (PRD Decision #4)
- **BM25 at application layer** (LlamaIndex BM25Retriever) — avoids PostgreSQL `ts_rank` scaling bottleneck under concurrent load (PRD Decision #5)
- **In-process re-ranker** — `cross-encoder/ms-marco-MiniLM-L-6-v2` co-located in Fargate container, no separate service or network hop (PRD Section 6)
- **Zero-retention OpenAI** — DPA executed, all usage through enterprise-grade endpoints; no PII sent in MVP (PRD Section 6)
- **All secrets from AWS Secrets Manager** via IAM roles — never in code or environment files (PRD Section 6.2)
- **FERPA-forward design** — Three-Zone Tenant Enclave with Zone A built for MVP; Zones B/C defined as commented-out Terraform (PRD Section 7.1)

### Cross-Cutting Concerns Identified

- **Security & encryption** — pervasive across all components: KMS at rest, TLS 1.2+ in transit, no PII in logs, secrets management via IAM, zero-retention LLM vendor
- **Metadata consistency** — chunk metadata schema (book_title, authors, SKU, chapter, section, page_number, chunk_type) enforced from ingestion through retrieval to citation in API responses
- **Observability** — structured JSON logging for key events (query received, answer generated, scope check, session management); CloudWatch integration for MVP
- **Session management** — Redis-backed clarification state with TTL; cross-request correlation via `conversation_id` (echoed in every response) and `session_id` (scoped to one clarification loop)
- **Error handling** — five distinct error responses with specific HTTP status codes and body shapes: 401 (missing/invalid API key), 422 (malformed request), 400 (expired session), 503 (service failure), 500 (unexpected error)
- **Evaluation pipeline** — RAGAS integration as a continuous quality signal throughout development (Phase 0-B), not just post-build validation (Phase 3)

### Input Document Context

**PRD Validation Report (4/5 — Good):**

The PRD v4.2 validation identified 27 total violations. Key findings relevant to architecture:

- **Implementation leakage in NFRs:** 8 violations where NFR measurement methods reference specific AWS services. This is expected in the architecture document — the PRD should use capability descriptions, but the architecture appropriately names specific technologies.
- **Traceability gap:** Journey C (Evaluator Runs Evaluation Pipeline) lacks a dedicated FR. The evaluation pipeline is governed by Section 2.3 narrative and acceptance criteria. The architecture must support this pipeline despite the absence of a formal FR.
- **Quality strengths:** Test criteria on all 13 FRs, zero implementation leakage in FRs, SMART average 4.78/5.0, comprehensive evaluation strategy.

**FERPA Compliance Report:**

The companion FERPA report (`apps/api/docs/research/ferpa-FINAL.md`) establishes the regulatory framework for future phases:

- **School Official Exception:** PLC Coach qualifies as a "school official" under FERPA through a comprehensive DPA, allowing access to education records without separate parental consent.
- **Three-Zone Architecture:** Zone A (Content — proprietary books, no PII), Zone B (Meeting/Transcript — future, de-identified), Zone C (Identity/Student Directory — future, highest sensitivity). MVP builds Zone A only.
- **RAG Privacy Benefit:** The vector database contains only book content embeddings, not student information. No training or fine-tuning on student data.
- **State Law Compliance:** Architecture designed to meet the strictest state laws (California SOPIPA, New York Ed Law § 2-d, Illinois ISSRA) from day one.

These FERPA findings inform the architecture's security-first posture: encryption everywhere, audit logging with PII exclusion, and the Tenant Enclave zoning model — even though the MVP only handles proprietary book content with no student data.

## Starter Template Evaluation

### Primary Technology Domain

Python 3.11+ API Backend — identified from PRD Section 6 technology stack and project classification (`api_backend`, high complexity).

### Technical Preferences (Pre-Established)

The following technical decisions are locked in by the PRD and project configuration:

- **Language:** Python 3.11+ with type hints on all public signatures
- **Framework:** FastAPI with Pydantic v2
- **Linter/Formatter:** ruff (format + lint)
- **Testing:** pytest
- **ORM/DB Access:** SQLAlchemy 2.0 async (decided in Step 4)
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

**Rationale:** The project's tech stack is comprehensively defined in the PRD, and the planned source layout is documented in `apps/api/CLAUDE.md`. No existing starter template provides meaningful coverage of the RAG-specific components (LlamaIndex orchestration, Qdrant integration, three-stage ingestion pipeline, cross-encoder re-ranker, Redis clarification session management) that constitute the core architecture. Using a generic starter would require more stripping and restructuring than building from the planned layout.

**Initialization approach:** The first implementation story should scaffold the project structure following the planned layout, including:

- `pyproject.toml` with all dependencies (FastAPI, Pydantic v2, LlamaIndex, qdrant-client, redis, etc.)
- `Dockerfile` for single-container deployment (API + re-ranker)
- `apps/api/src/` directory structure per architecture
- ruff configuration
- pytest configuration with `apps/api/tests/` structure
- `.github/workflows/` CI pipeline stub

**Architectural Decisions Provided by Approach:**

- **Language & Runtime:** Python 3.11+, async FastAPI, Pydantic v2 for all schemas
- **Build Tooling:** pyproject.toml (PEP 621), ruff for linting/formatting
- **Testing Framework:** pytest with asyncio support
- **Code Organization:** Layered structure — api/routes, schemas, services, ingestion, config
- **Development Experience:** uvicorn with `--reload`, ruff watch, pytest-watch

**Note:** Project initialization should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- PostgreSQL access layer, migration strategy, logging framework, dependency injection pattern

**Important Decisions (Shape Architecture):**
- Docker base image, settings management, error handling, testing strategy

**Deferred Decisions (Post-MVP):**
- Rate limiting strategy (PRD Section 2.2: "No Rate Limiting")
- Full user authentication — OAuth/JWT (PRD Section 2.2: "No User Authentication")
- WCAG accessibility compliance (PRD Section 2.2: "No Accessibility Compliance")
- Multi-AZ deployment
- Distributed tracing and dashboards (PRD Section 6.2: deferred to future release)
- Circuit breaker for external service calls

### Data Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| PostgreSQL access layer | SQLAlchemy 2.0 async | Industry standard with FastAPI; ORM simplifies the 2-table model (books, chunks); native Pydantic v2 conversion via `model_validate`; async engine fits FastAPI's event loop |
| Migration strategy | Alembic | Bundled with SQLAlchemy; version-controlled schema migrations; `--autogenerate` detects model changes |

Affects: Database models (`models/book.py`, `models/chunk.py`), ingestion pipeline (chunk writes), query engine (citation lookups for `text_excerpt`)

### Authentication & Security

No open decisions — all security architecture is locked in by the PRD:

- Static API key via `X-API-Key` header (PRD Section 5.1)
- AWS Secrets Manager via IAM for all secrets (PRD Section 6.2)
- KMS at rest, TLS 1.2+ in transit (PRD Section 7.2, NFR-004)
- Zero-retention OpenAI with executed DPA (PRD Section 6, Section 7.2)
- No PII in logs, even in debug mode (PRD Section 7.2, NFR-005)

### API & Communication Patterns

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Logging framework | structlog | Processor pipeline enables automatic PII sanitization; native structured JSON output for CloudWatch; async-friendly; bound context for request tracing |
| Dependency injection | Centralized `deps.py` with FastAPI `Depends()` | Single file for all shared resources; predictable for developers and AI agents; easy to split later if needed |
| Error handling | Custom exception classes + FastAPI exception handlers | 1:1 mapping to PRD's 5 error responses (Section 5.4); self-documenting exceptions; centralized error contract |
| Settings management | Pydantic Settings (`pydantic-settings`) | Native Pydantic v2 integration; auto-reads env vars and supports Secrets Manager/Fargate injection; type validation at startup catches misconfig early |

### Frontend Architecture

Not applicable — MVP is API-only with no UI (PRD Section 2.2).

### Infrastructure & Deployment

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Docker base image | `python:3.11-slim` | Balanced size (~150 MB) vs. compatibility; avoids Alpine musl build issues with ML packages (cross-encoder, LlamaIndex, PyMuPDF) |
| Testing strategy | Layered: mocked unit tests + testcontainers integration + RAGAS evaluation | Fast local feedback via mocks; real-service confidence via testcontainers (Postgres, Redis, Qdrant) in CI; separate evaluation pipeline for RAGAS quality metrics against golden dataset |

All other infrastructure decisions locked in by PRD: Fargate (HIPAA-eligible, PRD Decision #8), single AZ, Terraform, GitHub Actions, VPC with private subnets, NAT Gateway for controlled egress.

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
- Exception handlers depend on the error contract defined in PRD Section 5.4
- Testcontainers config mirrors the real infrastructure (Postgres, Redis, Qdrant)

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**6 critical conflict areas** identified and resolved to ensure AI agents produce compatible, consistent code.

### Naming Patterns

**Database Naming Conventions:**
- Tables: `snake_case`, **plural** — `books`, `chunks` (matches PRD Section 4.1)
- Columns: `snake_case` — `book_id`, `text_content`, `page_number`
- Foreign keys: `{referenced_table_singular}_id` — `book_id` on `chunks`
- Indexes: `ix_{table}_{column}` — `ix_chunks_book_id`
- Constraints: `pk_{table}` for primary keys, `fk_{table}_{column}` for foreign keys, `uq_{table}_{column}` for unique

**API / JSON Naming Conventions:**
- All JSON fields: `snake_case` — no exceptions
- Matches PRD contract: `book_title`, `page_number`, `text_excerpt`, `conversation_id`, `session_id`, `clarification_question`
- Any new fields added during implementation must follow `snake_case`

**Code Naming Conventions:**
- Variables and functions: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Files and directories: `snake_case` — `query_engine.py`, `scope_guard.py`
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
- Three response statuses only: `success`, `needs_clarification`, `out_of_scope` (PRD Section 5.3)
- No envelope wrapper — responses are flat Pydantic models, not wrapped in `{"data": ...}`
- Error responses use the exact HTTP status codes and body shapes from PRD Section 5.4

**Date/Time Formats:**
- Database: PostgreSQL `timestamp with time zone`
- JSON/API: ISO 8601 strings (`2026-02-27T17:30:00Z`)
- Internal Python: `datetime.datetime` with UTC timezone

### Communication Patterns

**Logging Patterns (structlog):**
- One logger per module: `logger = structlog.get_logger(__name__)`
- Event names: `snake_case` verbs — `query_received`, `answer_generated`, `scope_check_failed`, `session_created`, `session_expired`
- Bound context for request tracing: `logger.bind(conversation_id=..., user_id=...)`
- **NEVER** log raw query text, answer text, or PII — metadata only (NFR-005)
- Log levels: `info` for business events, `warning` for fallbacks/degradation, `error` for failures requiring attention

**No Event System for MVP:**
- No pub/sub, message bus, or event sourcing
- Direct service-to-service calls via dependency injection
- Event-driven patterns deferred to post-MVP

### Process Patterns

**Error Handling:**
- Flat exception hierarchy — single `PLCCoachError` base class
- One exception per PRD error response:

| Exception | HTTP Status | Maps To (PRD Section 5.4) |
|-----------|-------------|---------------------------|
| `UnauthorizedError` | 401 | Missing/invalid API key |
| _(Pydantic validation)_ | 422 | Malformed request body |
| `SessionExpiredError` | 400 | Expired/invalid `session_id` |
| `ServiceUnavailableError` | 503 | LLM or vector DB failure |
| `PLCCoachError` (base, catch-all) | 500 | Unexpected error |

- All exceptions registered as FastAPI exception handlers in `main.py`
- Services raise domain exceptions; route handlers never catch them directly

**Service Layer Patterns:**
- Classes with injected dependencies — constructor receives clients/config
- Wired via `deps.py` using FastAPI `Depends()` chain
- Example: `QueryEngine(qdrant_client, redis_client, reranker, openai_client)`

**Async Pattern:**
- Route handlers: `async def` (FastAPI requirement)
- Network I/O (Qdrant, OpenAI, Redis): `async`/`await`
- CPU-bound work (re-ranker inference, BM25 scoring): plain sync — no `run_in_executor` wrappers for MVP
- Service methods that mix both: `async def` that awaits network calls, then calls sync methods inline

**Retry & Resilience:**
- Retry only on transient network failures (OpenAI 429/503, Qdrant connection errors)
- Max 3 retries with exponential backoff (1s, 2s, 4s)
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
- Add type hints to all public function signatures

**Pattern Verification:**
- ruff enforces code style (naming, imports, formatting)
- PR review checklist includes pattern compliance
- Test names must follow `test_{what}_{when}_{then}` convention

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
│   │   ├── alembic.ini                  # Alembic config pointing to alembic/
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
│   │   │   ├── corpus_scan.py           # Pre-build corpus analysis (FR-004)
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
│   │       ├── prd-v4-validation-report.md
│   │       └── research/
│   │           └── ferpa-FINAL.md
│   ├── teachers-portal/                 # (Planned — empty for MVP)
│   └── admins-portal/                   # (Planned — empty for MVP)
├── infra/
│   └── terraform/                       # All AWS resources defined here
│       ├── main.tf                      # Provider config, backend state
│       ├── vpc.tf                       # VPC, subnets, NAT Gateway, security groups
│       ├── fargate.tf                   # ECS cluster, task definition, service, ALB
│       ├── rds.tf                       # PostgreSQL RDS instance
│       ├── elasticache.tf               # Redis ElastiCache instance
│       ├── ec2_qdrant.tf                # Qdrant EC2 instance in private subnet
│       ├── s3.tf                        # Source PDF bucket with versioning
│       ├── ecr.tf                       # Container registry
│       ├── secrets.tf                   # Secrets Manager resources
│       ├── iam.tf                       # IAM roles and policies (least-privilege)
│       ├── cloudwatch.tf                # Log groups with retention config
│       ├── variables.tf                 # Input variables
│       ├── outputs.tf                   # Output values
│       └── zones_b_c.tf                # FERPA Zones B/C — commented out, ready to activate
├── packages/                            # (Planned — shared code, empty for MVP)
├── .gitignore
└── apps/api/CLAUDE.md                   # Claude Code context for the API project
```

### Architectural Boundaries

**API Boundary (External):**
- Single entry point: `POST /api/v1/query`
- Health check: `GET /health` (no auth, used by ALB)
- Authentication: `X-API-Key` header validated in middleware (`main.py`)
- Request/response contract defined exclusively in `schemas/` — route handlers accept `QueryRequest`, return `QueryResponse`
- No direct database or service access from route handlers — everything through `deps.py`

**Service Boundary (Internal):**
- `routes/query.py` → calls services via injected dependencies, never instantiates directly
- `services/scope_guard.py` → classifies in-scope vs out-of-scope **before** query engine runs
- `services/clarification.py` → manages Redis session state, decides whether to clarify or answer
- `services/query_engine.py` → orchestrates hybrid search + re-rank + LLM generation
- Services may call each other only through constructor injection — no circular dependencies

**Data Boundary:**
- `models/` — SQLAlchemy models are the only code that touches PostgreSQL
- Qdrant access isolated to `services/query_engine.py` (search) and `ingestion/pipeline.py` (upsert)
- Redis access isolated to `services/clarification.py` (session state) and `deps.py` (connection pool)
- No raw SQL anywhere — all queries through SQLAlchemy ORM

**Ingestion Boundary:**
- `ingestion/` is a self-contained pipeline — shares `models/` and `config/` but does **not** import from `services/` or `api/`
- Runs as a separate process via `scripts/ingest.py` — never triggered by the API at runtime
- `scripts/corpus_scan.py` is read-only analysis — no writes to any datastore

### Requirements to Structure Mapping

**Ingestion Pipeline (FR-001 through FR-004):**

| FR | Description | File(s) |
|----|-------------|---------|
| FR-001 | Source Material Processing | `ingestion/pipeline.py` (orchestrator), `scripts/ingest.py` (entry point) |
| FR-002 | Layout-Aware Parsing | `ingestion/pymupdf_classifier.py` (page classification), `ingestion/llmsherpa_parser.py` (portrait pages), `ingestion/vision_parser.py` (landscape pages) |
| FR-003 | Metadata Capture | `ingestion/metadata.py` (ChunkMetadata schema + validation) |
| FR-004 | Pre-Build Corpus Scan | `scripts/corpus_scan.py` |

**Query Engine (FR-005 through FR-010):**

| FR | Description | File(s) |
|----|-------------|---------|
| FR-005 | Direct Answer | `services/query_engine.py`, `routes/query.py` |
| FR-006 | Conditional Clarification | `services/clarification.py`, `routes/query.py` |
| FR-007 | Ambiguity Detection | `services/clarification.py` |
| FR-008 | One-Question Hard Limit | `services/clarification.py` (Redis session enforces single turn) |
| FR-009 | Out-of-Scope Detection | `services/scope_guard.py` |
| FR-010 | Dynamic Metadata Filtering | `services/query_engine.py` (filter extraction + fallback logic) |

**Hybrid Search & Re-Ranking (FR-011 through FR-013):**

| FR | Description | File(s) |
|----|-------------|---------|
| FR-011 | Semantic Search | `services/query_engine.py` (Qdrant vector search) |
| FR-012 | Keyword Search | `services/query_engine.py` (BM25Retriever) |
| FR-013 | Re-Ranking | `services/query_engine.py` (cross-encoder merge + re-rank) |

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
| Evaluation pipeline | `tests/evaluation/test_ragas.py`, `tests/fixtures/golden_dataset.json` |

### Data Flow

**Query Flow (runtime):**
```
Client → ALB → Fargate
  → main.py (API key check, structlog bind conversation_id + user_id)
    → routes/query.py (parse QueryRequest via Pydantic v2)
      → scope_guard.py (in-scope? → out_of_scope response or continue)
      → clarification.py (session_id present? → resolve follow-up
                          ambiguous? → needs_clarification response or continue)
      → query_engine.py
        → Extract metadata filters from query (book_title, authors, chunk_type)
        → Qdrant (semantic search, top-20 by vector similarity)
        → BM25Retriever (keyword search, top-20 by BM25 relevance)
        → Merge into 40-candidate set, deduplicate
        → cross-encoder (re-rank merged set → top-k to generation)
        → OpenAI GPT-4o (generate grounded answer from top-k context)
      → routes/query.py (build QueryResponse with sources: book_title, sku, page_number, text_excerpt)
    → Client
```

**Ingestion Flow (offline, via SSM in VPC):**
```
scripts/ingest.py
  → pipeline.py (orchestrator)
    → pymupdf_classifier.py (classify every page: orientation + text-layer presence)
    → llmsherpa_parser.py (portrait pages with text → structured chunks with hierarchy)
    → vision_parser.py (landscape pages → GPT-4o Vision → structured Markdown description)
    → metadata.py (validate ChunkMetadata — fail-fast on missing required fields)
    → OpenAI text-embedding-3-large (embed chunks → 3,072-dim vectors)
    → Qdrant (upsert vectors + payload: book_sku, authors, book_title, chunk_type, page_number)
    → PostgreSQL (insert books + chunks via SQLAlchemy ORM)
```

**Resource Lifecycle (lifespan pattern):**

Heavy resources are loaded once at startup via FastAPI's `lifespan` context manager and stored in `app.state`. Per-request resources are created fresh in `deps.py`.

| Resource | Lifecycle | Where |
|----------|-----------|-------|
| Cross-encoder re-ranker model | Singleton — loaded in `lifespan`, stored in `app.state.reranker` | `api/main.py` |
| BM25 index | Singleton — built from PostgreSQL chunks at startup, stored in `app.state.bm25_index` | `api/main.py` |
| Qdrant client | Singleton — connected in `lifespan`, stored in `app.state.qdrant` | `api/main.py` |
| OpenAI client | Singleton — initialized in `lifespan`, stored in `app.state.openai` | `api/main.py` |
| SQLAlchemy async engine | Singleton — created in `lifespan`, stored in `app.state.db_engine` | `api/main.py` |
| Redis connection pool | Singleton — created in `lifespan`, stored in `app.state.redis` | `api/main.py` |
| DB session | Per-request — created from `app.state.db_engine` in `deps.py` | `deps.py` |
| Service instances | Per-request — constructed in `deps.py` with singleton deps from `app.state` | `deps.py` |

**BM25 Index Lifecycle:**
1. At startup, `lifespan` queries all `chunks.text_content` from PostgreSQL
2. Passes text corpus to LlamaIndex `BM25Retriever` to build the in-memory index
3. Stored in `app.state.bm25_index`
4. After re-ingestion, the API container must be restarted to rebuild the index
5. Acceptable for MVP scale (~25 books, estimated ~10,000 chunks). Post-MVP optimization: pre-build and serialize the index during ingestion.

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

**Decision Compatibility:** All technology choices are compatible and well-tested together. SQLAlchemy 2.0 async integrates cleanly with FastAPI's async runtime. Pydantic v2 is natively supported by both FastAPI and Pydantic Settings. structlog's processor pipeline works without conflict alongside FastAPI's middleware chain. Alembic supports SQLAlchemy 2.0's async engine for migrations. The `python:3.11-slim` Docker base image supports all ML dependencies (cross-encoder, LlamaIndex, PyMuPDF) without Alpine musl build issues.

**Pattern Consistency:** All naming conventions are `snake_case` throughout — database columns, JSON fields, Python code, log events, file names. The class-based DI pattern aligns with FastAPI's `Depends()` system. The flat exception hierarchy maps 1:1 to PRD error responses. Test mirroring pattern works naturally with pytest's conftest discovery. The service layer pattern (constructor injection, never direct instantiation in route handlers) is consistently applied.

**Structure Alignment:** The `plc_coach` package with src layout supports absolute imports. Domain-grouped files align with the service class pattern. The ingestion boundary (no imports from `services/` or `api/`) prevents circular dependencies. Test structure mirrors source, enabling easy navigation between implementation and test files.

### Requirements Coverage Validation

**Functional Requirements (FR-001 through FR-013):** All 13 FRs mapped to specific source files in the project structure. No FR lacks architectural support.

| FR | Architectural Support |
|----|----------------------|
| FR-001 | `ingestion/pipeline.py` + `scripts/ingest.py` — orchestrates all 25 books from S3 to Qdrant + PostgreSQL |
| FR-002 | Three parser files: `pymupdf_classifier.py` (classification), `llmsherpa_parser.py` (portrait), `vision_parser.py` (landscape) |
| FR-003 | `ingestion/metadata.py` — ChunkMetadata Pydantic schema validates all required fields; fail-fast on missing data |
| FR-004 | `scripts/corpus_scan.py` — standalone read-only analysis, runs before ingestion |
| FR-005 | `query_engine.py` + `routes/query.py` — hybrid search → re-rank → generate → `success` response with sources |
| FR-006 | `clarification.py` — checks ambiguity before query engine; returns `needs_clarification` with `session_id` |
| FR-007 | `clarification.py` — implements two-part ambiguity test (different answers by interpretation + unresolvable from query alone) |
| FR-008 | `clarification.py` — Redis session tracks turn count; second ambiguous query gets best-interpretation answer |
| FR-009 | `scope_guard.py` — classifies query before any search; returns `out_of_scope` with fixed refusal text |
| FR-010 | `query_engine.py` — extracts `book_title`, `authors`, `chunk_type` from query; applies Qdrant payload filter; falls back to unfiltered when < 3 results |
| FR-011 | `query_engine.py` — Qdrant vector search using `text-embedding-3-large` (3,072-dim) |
| FR-012 | `query_engine.py` — LlamaIndex `BM25Retriever` for exact keyword matching of PLC jargon |
| FR-013 | `query_engine.py` — `cross-encoder/ms-marco-MiniLM-L-6-v2` re-ranks merged candidate set |

**Non-Functional Requirements (NFR-001 through NFR-007):**

| NFR | Architectural Support |
|-----|----------------------|
| NFR-001 (P95 ≤ 30s) | In-process re-ranker (no network hop); async I/O for Qdrant/OpenAI/Redis; singleton clients avoid connection overhead |
| NFR-002 (95% availability) | Fargate managed compute + ALB health checks (`GET /health`); single-AZ accepted for MVP |
| NFR-003 (5 concurrent users) | Async FastAPI; SQLAlchemy connection pool; Redis connection pool; Qdrant async client |
| NFR-004 (encryption everywhere) | Terraform configs: RDS encryption, S3 encryption, EBS encryption for Qdrant EC2, ALB TLS termination, ElastiCache in-transit encryption |
| NFR-005 (audit logs, no PII) | `config/logging.py` structlog PII sanitizer processor strips sensitive fields; CloudWatch log group with 90-day retention (Terraform) |
| NFR-006 (RTO 4h, RPO 24h) | RDS automated backups with 7-day retention (Terraform); Qdrant reconstructable via `scripts/ingest.py` from S3 source PDFs |
| NFR-007 (security scanning) | CI pipeline: container image scanning step before ECR push; block deployment on critical/high CVEs |

**Evaluation Pipeline Support (PRD Section 2.3, Journey C):**

Although the evaluation pipeline lacks a dedicated FR (noted in the validation report as a traceability gap), the architecture provides full support:

- `tests/evaluation/test_ragas.py` — RAGAS evaluation runner for Phase 0-B (reference-free) and Phase 3 Track A (reference-based)
- `tests/fixtures/golden_dataset.json` — stores the golden dataset (in-scope, out-of-scope, ambiguous queries)
- Baseline comparison: same golden dataset submitted to raw GPT-4o (no RAG context) for score comparison
- Style preference collection (Phase 3 Track B): both answer styles generated per query; preference logging is an evaluation-time concern, not an API architectural concern

### Gap Analysis — Resolved

**Gap 1 (Resolved): Resource Lifecycle / Lifespan Pattern**

Heavy resources (re-ranker model, BM25 index, Qdrant client, OpenAI client, DB engine, Redis pool) are loaded once at startup via FastAPI's `lifespan` context manager and stored in `app.state`. Per-request resources (DB session, service instances) are created fresh in `deps.py`. Documented in the Data Flow section above.

**Gap 2 (Resolved): Health Check Endpoint**

`GET /health` returning `{"status": "ok"}` with HTTP 200. Located in `api/routes/health.py`. Used by ALB target group health check. No authentication required — health checks must work without the API key.

**Gap 3 (Resolved): BM25 Index Lifecycle**

BM25 index built at application startup from all chunk text in PostgreSQL. After re-ingestion, the API container is restarted to rebuild the index. Acceptable for MVP scale. Documented in the Data Flow section above.

**Gap 4 (Resolved): Evaluation Pipeline Without FR**

The PRD validation report identified that Journey C (Evaluator Runs Evaluation Pipeline) lacks a dedicated FR. The architecture addresses this by including `tests/evaluation/test_ragas.py` and the golden dataset in the project structure. The evaluation pipeline is an internal quality assurance tool governed by PRD Section 2.3, not a product feature requiring an FR.

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed (13 FRs, 7 NFRs, additional architectural constraints)
- [x] Scale and complexity assessed (8 components, high complexity)
- [x] Technical constraints identified (Terraform-only, VPC ingestion, single AZ, self-hosted Qdrant)
- [x] Cross-cutting concerns mapped (security, metadata, observability, sessions, errors, evaluation)
- [x] PRD validation findings incorporated as context
- [x] FERPA compliance context incorporated for security architecture decisions

**Architectural Decisions**
- [x] Critical decisions documented (SQLAlchemy, Alembic, structlog, deps.py DI, Pydantic Settings)
- [x] Technology stack fully specified per PRD Section 6
- [x] Integration patterns defined (DI via deps.py, lifespan for singletons, service layer)
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
- [x] Requirements to structure mapping complete (all 13 FRs mapped to specific files)
- [x] Terraform infrastructure structure defined with FERPA zone comments

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — all FRs and NFRs have explicit architectural support, all technology decisions are compatible, patterns are comprehensive with enforcement guidelines, and the architecture faithfully traces to the PRD v4.2 as the source of truth.

**Key Strengths:**
- **PRD-faithful architecture** — every decision traces back to a specific PRD requirement or section; FR/NFR numbering matches the PRD exactly
- **Clear boundaries** — ingestion, query, and infrastructure are fully isolated with explicit dependency rules
- **Agent-friendly** — naming conventions, DI patterns, exception hierarchy, and enforcement guidelines leave no room for interpretation
- **FERPA-forward** — Zone A infrastructure built for MVP; Zones B/C prepared as commented Terraform code, ready for activation
- **Validation-informed** — PRD validation report findings (traceability gap, evaluation pipeline support) explicitly addressed in the architecture
- **Security-first** — encryption everywhere, PII sanitization in logging, zero-retention LLM vendor, secrets management via IAM

**Areas for Future Enhancement:**
- BM25 index serialization (avoid full rebuild on every container restart)
- Circuit breaker for OpenAI/Qdrant (post-MVP resilience)
- Distributed tracing with request correlation IDs across services
- Rate limiting middleware when API is exposed externally
- Multi-AZ deployment for higher availability target
- Full user authentication (OAuth/JWT) replacing static API key

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries — especially the ingestion/services separation
- Refer to this document for all architectural questions
- When in doubt, the PRD v4.2 (`apps/api/docs/prd-v4.md`) is the ultimate source of truth

**First Implementation Priority:**
Project scaffold — `pyproject.toml`, directory structure, `Dockerfile`, ruff/pytest config, `settings.py`, `main.py` with lifespan stub, `health.py`, `exceptions.py`, CI pipeline.
