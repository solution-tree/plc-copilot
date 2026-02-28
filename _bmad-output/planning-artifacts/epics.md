---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - apps/api/docs/research/ferpa-FINAL.md
---

# plc-copilot - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for plc-copilot, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR-001: The operator can trigger ingestion of all 25 PLC @ Work books in PDF format from cloud storage into the vector store and relational metadata database. Test: All 25 books present in both stores; row counts match expected totals.

FR-002: The operator can run layout-aware parsing that classifies each page by orientation (portrait vs. landscape) and text-layer presence, routing pages to the appropriate parser: portrait pages with text layers parsed for hierarchical structure; landscape pages processed by vision-capable model for structured textual description; pages without text layers flagged for manual review. Test: Portrait pages produce structured chunks verified by spot-checking 3 books; landscape pages produce descriptive text chunks tagged with chunk_type: reproducible; pages without text layers flagged and logged.

FR-003: The operator can verify that every chunk of ingested text is stored with standardized metadata: book title, authors, SKU, chapter, section, page number, and content type. Test: 100% of chunks have all required metadata fields populated; spot-check confirms accuracy.

FR-004: The operator can run an automated scan of all 25 source PDFs before ingestion to validate corpus assumptions (page counts, landscape page volumes, text-layer presence). Test: Scan report produced for all 25 books; anomalies documented.

FR-005: The API consumer can submit an unambiguous, in-scope query and receive a grounded, cited answer in a single round trip. Grounded = factually consistent with retrieved context, measured by RAGAS Faithfulness in FR-014. Test: Response includes success status with populated answer and sources fields; citations include book title, SKU, page number, text excerpt.

FR-006: The API consumer can submit any query and receive appropriate routing: a direct success answer for clear queries, or a needs_clarification response with a single clarifying question for ambiguous queries per FR-007. Test: Ambiguous queries from labeled test set return needs_clarification; clear queries return success.

FR-007: The API consumer can rely on a two-part ambiguity test: a query is ambiguous if and only if both conditions are true: (a) answer would reference different books/chapters/concepts depending on interpretation, AND (b) correct interpretation cannot be determined from query text alone. Three categories: Topic Ambiguity, Scope Ambiguity, Reference Ambiguity. Test: Labeled golden dataset subset measures precision >= 0.80, recall >= 0.70.

FR-008: The API consumer can complete any query interaction with at most one clarifying question per session. If follow-up remains ambiguous, system provides best-interpretation answer with interpretation statement appended. Test: 100% of multi-turn sessions contain at most one needs_clarification response.

FR-009: The API consumer can submit any query and receive a clear boundary signal: a hard refusal for out-of-scope queries stating the standard refusal message. Test: 100% of out-of-scope golden dataset queries receive refusal response.

FR-010: The API consumer can include metadata references in a query (book title, author name, content type) and receive filtered results. Extractable fields: book_title, authors, chunk_type. Fewer than 3 results triggers fallback to unfiltered mode. Test: Metadata-filtered queries return correctly filtered results; extraction accuracy >= 0.90 on 10+ query test set.

FR-011: The API consumer can retrieve conceptually similar content via vector embeddings even without exact word matches. Test: Ablation test comparing vector-only vs. full hybrid pipeline shows positive delta on Faithfulness or Answer Relevancy (minimum 0.03).

FR-012: The API consumer can retrieve content by exact keyword match, critical for PLC jargon and acronyms. Test: Jargon/acronym test set achieves recall >= 0.80 for exact-term queries.

FR-013: The API consumer can receive search results scored and re-ordered by relevance-based re-ranker. Test: Ablation test comparing with/without re-ranking shows positive improvement (minimum 0.05) on Faithfulness or Answer Relevancy.

FR-014: The evaluator can run RAGAS evaluation pipeline in reference-free mode against golden dataset, receiving Faithfulness and Answer Relevancy scores per query. Primary quality signal during development (Phase 0-B). Test: Pipeline produces per-query scores for all golden dataset in-scope questions.

FR-015: The evaluator can run RAGAS evaluation pipeline in full reference-based mode using Concise Answers book as ground truth, producing Context Precision and Context Recall in addition to FR-014 metrics. Final quality validation (Phase 3 Track A). Test: Pipeline produces all four metrics; aggregate scores meet defined thresholds.

FR-016: The evaluator can run the same golden dataset through raw GPT-4o without RAG context and receive a comparison report showing RAG vs. baseline scores. Test: Comparison report includes per-query and aggregate scores; RAG pipeline exceeds baseline on Faithfulness and Answer Relevancy.

FR-017: The evaluator can generate both answer styles (Book-Faithful and Coaching-Oriented) for each golden dataset query and record tester preferences in structured log. Phase 3 Track B data collection. Test: Preference log contains entries for all golden dataset in-scope queries with all required fields.

FR-018: The API consumer must provide a valid static API key in X-API-Key header. Requests without valid key receive 401 Unauthorized. Test: Valid key returns expected responses; missing/empty/invalid keys return 401.

FR-019: The operator can verify all query and answer events are captured in structured JSON audit logs with metadata. Logs never contain raw PII. Test: Code review confirms no PII logged; spot-check confirms required metadata fields present.

FR-020: The operator can verify service readiness via health check endpoint confirming API container, vector DB, and relational DB connections. Test: Returns 200 OK when all dependencies reachable; non-200 when any unreachable.

FR-021: The internal tester can access a minimal web-based test client with question input field and disclaimer banner. Test: Client submits queries and displays responses; disclaimer banner visible on load.

### NonFunctional Requirements

NFR-001: Response Time — API responds within 30 seconds for 95th percentile under normal load (1-3 concurrent users). Includes retrieval, re-ranking, and LLM generation. Measurement: Request duration monitoring.

NFR-002: Availability — 95% uptime during business hours (8 AM - 6 PM ET, weekdays). Off-hours deployment downtime acceptable. Measurement: Health-check monitoring on load balancer.

NFR-003: Concurrent Users — Supports at least 5 concurrent query requests without degradation beyond NFR-001 thresholds. Measurement: Load test script with 5 concurrent requests, all meeting NFR-001.

NFR-004: Data Encryption — All data encrypted in transit (TLS 1.2+) and at rest via managed encryption key service. No exceptions. Measurement: Infrastructure audit.

NFR-005: Audit Log Retention — Structured JSON audit logs retained minimum 90 days. No PII in logs. Measurement: Code review + spot-check of production log samples.

NFR-006: Backup & Recovery — RDS automated backups with 7-day retention. Vector store reconstructible via re-ingestion. RTO: 4 hours, RPO: 24 hours. Measurement: Pre-launch recovery drill.

NFR-007: Security Scanning — Container images scanned for CVEs before deployment. Critical/high-severity must be resolved before production. Measurement: Automated Trivy scan in CI/CD that blocks on critical/high.

NFR-008: Ingestion Pipeline Duration — Full ingestion (all 25 books) completes within 8 hours. Individual book failures do not block remaining corpus. Measurement: Timed end-to-end run with per-book logging.

NFR-009: Cold Start Tolerance — API container available within 120 seconds of task start (including model loading). Cold starts after idle acceptable during internal testing. Measurement: Health-check probe confirms readiness within 120s window.

### Additional Requirements

**From Architecture:**

- Custom scaffold via `uv init` — no starter template. Must establish full directory structure (src/plc_copilot/ with all layer folders + tests/) from day one.
- Terraform modules required: vpc/, rds/, elasticache/, qdrant/, ecs/, s3/ under terraform/modules/. S3 backend with DynamoDB lock. Staging + production environments.
- VPC with private subnets for data stores/compute, public subnet for ALB, NAT gateway. Single AZ for MVP.
- Fargate (not App Runner) for HIPAA eligibility. 1 vCPU / 2 GB minimum. Rolling update with circuit breaker.
- Qdrant on t3.medium EC2 with 50 GB gp3 EBS. API key auth. Security group restricts access to Fargate + ingestion SGs only.
- RDS db.t3.micro, 20 GB gp3, automated backups 7-day retention.
- ElastiCache cache.t3.micro, encryption at rest + in transit (rediss:// TLS required).
- SQLAlchemy 2.0 async sessions with defined connection pool settings: pool_size=5, max_overflow=5, pool_timeout=10s, pool_recycle=1800s.
- Redis shared pool: max_connections=20, socket_timeout=5s, socket_connect_timeout=2s. Session TTL 15min, cache TTL 24h.
- OpenAI store:false on every request. 2 retries with exponential backoff. On final failure return 503.
- Embedding model: text-embedding-3-large (3,072 dims). Version pinned. Mismatch detection at startup.
- S3 private/versioned/IAM-restricted for PDFs, BM25 index, Qdrant snapshots.
- Structured JSON logging via Python stdlib logging. 17 defined events in catalog. Service layer and middleware only.
- Separate CloudWatch log groups: /plc-copilot/audit (90-day + S3 Glacier archival) and /plc-copilot/app (30-day).
- FastAPI lifespan context manager for startup sequence: re-ranker model load, BM25 index from S3, connection pool warm-up.
- Retrieval abstraction interface in retrieval/base.py. Hybrid orchestrator coordinates vector + BM25 + re-ranker.
- Re-ranker model weights (~90MB) baked into Docker image at build time.
- BM25 pickle with SHA-256 checksum verification before deserialization.
- Dynamic metadata extraction with fuzzy matching (rapidfuzz) against vocabulary table loaded from PostgreSQL at startup.
- Exception hierarchy: PLCCopilotError base with subclasses. Global exception handler. No try/except in routes.
- GitHub Actions CI: PR pipeline (ruff → mypy → unit tests). Merge to main (Docker build → Trivy scan → push ECR → deploy staging → smoke test → manual production promotion).
- Ingestion CI: Manual/scheduled trigger → SSM Run Command on EC2.
- Three-stage ingestion parsing: PyMuPDF (classification) → llmsherpa (structure) → GPT-4o Vision (landscape pages). Per-book failure isolation.
- Two Dockerfiles: Dockerfile (API with re-ranker weights) and Dockerfile.ingestion (ingestion pipeline).
- Qdrant daily snapshots via cron + post-ingestion snapshot. S3 storage with 7-day retention. CloudWatch alarm on snapshot age.
- Single Pydantic Settings class in core/config.py reading from env vars. .env.example with all vars documented.
- Pre-commit hooks: ruff + mypy.
- Golden dataset in tests/evaluation/data/golden_dataset.json.
- Evaluation requests skip cache (X-Request-Source: evaluation header).
- Load test: 5 concurrent requests via asyncio + httpx, run manually against staging.

**From FERPA Research:**

- OpenAI zero-retention (store: false) is a mandatory FERPA compliance requirement, not just a best practice.
- Cache keys must use SHA-256 hashed query text — query text may contain student names (FERPA).
- No PII in logs at any level including debug — FERPA mandated.
- VPC-contained ingestion — proprietary content never leaves VPC. FERPA + content IP protection.
- API key authentication as defense-in-depth for FERPA compliance.
- Qdrant API key enabled — defense-in-depth beyond VPC isolation.
- Pre-launch compliance checklist: OpenAI DPA execution, zero-retention verification in code, spending limits, API key rotation procedure, Solution Tree content license, NFR-007 vulnerability scan passing.

### FR Coverage Map

| FR | Epic | Description |
|---|---|---|
| FR-001 | Epic 3 | Source material processing |
| FR-002 | Epic 3 | Layout-aware parsing |
| FR-003 | Epic 3 | Metadata capture |
| FR-004 | Epic 3 | Pre-build corpus scan (first story, PRD gate) |
| FR-005 | Epic 4 | Direct answer |
| FR-006 | Epic 5 | Conditional clarification |
| FR-007 | Epic 5 | Ambiguity detection |
| FR-008 | Epic 5 | One-question hard limit |
| FR-009 | Epic 5 | Out-of-scope detection |
| FR-010 | Epic 4 | Dynamic metadata filtering |
| FR-011 | Epic 4 | Semantic search |
| FR-012 | Epic 4 | Keyword search |
| FR-013 | Epic 4 | Re-ranking |
| FR-014 | Epic 6 | Reference-free evaluation |
| FR-015 | Epic 6 | Reference-based evaluation |
| FR-016 | Epic 6 | Baseline comparison |
| FR-017 | Epic 6 | Style preference collection |
| FR-018 | Epic 1 | API key authentication |
| FR-019 | Epic 1 | Audit logging |
| FR-020 | Epic 1 + Epic 4 | Health check (Epic 1: DB + Redis connectivity; Epic 4: re-ranker + BM25 model readiness via lifespan). FR-020 acceptance criteria fully met after Epic 4 |
| FR-021 | Epic 1 | Minimal test client |

### NFR Coverage Map

| NFR | Epic | Description |
|---|---|---|
| NFR-001 | Epic 4 | Response time (30s p95) — verified via request duration logging |
| NFR-002 | Epic 2 | Availability (95% business hours) — ALB health check config |
| NFR-003 | Epic 6 (post-Epic 5) | Concurrent users (5) — load test script. Must execute after Epic 5 complete to exercise full pipeline including clarification-flow sessions |
| NFR-004 | Epic 2 | Data encryption (TLS 1.2+ / KMS) — Terraform config |
| NFR-005 | Epic 2 | Audit log retention (1 year: 90-day CloudWatch + S3 Glacier archival) |
| NFR-006 | Epic 2 + 3 | Backup & recovery (RDS backups in E2, Qdrant snapshots in E3) |
| NFR-007 | Epic 2 | Security scanning (Trivy in CI/CD) |
| NFR-008 | Epic 3 | Ingestion duration (8h ceiling) |
| NFR-009 | Epic 4 | Cold start tolerance (120s) — lifespan model loading |

## Epic List

### Epic 1: Project Scaffold & Core API
The developer can clone the repo, run `docker compose up`, and have a working local API skeleton with auth, health checks, audit logging, error handling, and a test client — ready for feature development. Establishes the Redis service layer (connection pool management, session service skeleton, cache service skeleton) that Epic 4 (caching) and Epic 5 (sessions) build upon. Redis pool config per architecture doc: `max_connections=20`, `socket_timeout=5s`, `socket_connect_timeout=2s`. Cache key format: `cache:{sha256(normalized_query_text)}`.
**FRs covered:** FR-018, FR-019, FR-020 (partial — basic DB + Redis connectivity checks), FR-021

**Definition of Done:** All scaffolding, auth, logging, health (basic), error handling, and test client operational locally via `docker compose up`. Pre-commit hooks passing. Layer boundaries established. Redis service layer scaffolded with connection pool, session service skeleton, and cache service skeleton.

### Epic 2: Infrastructure & CI/CD
The operator can deploy the API to AWS staging and promote to production through an automated, security-scanned pipeline. Includes pre-launch compliance checklist as a deliverable: OpenAI DPA execution verification, `store: false` code assertion, spending limits configuration, API key rotation procedure documentation, Solution Tree content license confirmation, and NFR-007 Trivy scan gate. Code-verifiable items (store:false assertion, Trivy gate) become story acceptance criteria; operational/legal items (DPA, license, rotation procedure) become a documentation deliverable story.
**NFRs addressed:** NFR-002, NFR-004, NFR-005, NFR-007
**Additional deliverables:** Pre-launch compliance checklist (FERPA research requirements)

**Definition of Done:** Terraform applies to staging. CI pipeline runs on PR (ruff → mypy → unit tests). Merge-to-main pipeline builds, scans, deploys to staging. Production promotion workflow exists. Pre-launch compliance checklist items documented.

### Epic 3: Content Ingestion Pipeline
The operator can ingest the full 25-book PLC @ Work corpus through a layout-aware parsing pipeline, producing richly-tagged, searchable chunks in the vector store and relational database.
**FRs covered:** FR-001, FR-002, FR-003, FR-004
**NFRs addressed:** NFR-006 (Qdrant snapshots), NFR-008

**Risk level:** High — parsing pipeline involves unproven tools (llmsherpa, GPT-4o Vision) on real corpus.
**Mitigation:** FR-004 (corpus scan) is the first story and serves as a go/no-go gate.
**Recommendation:** Include a technical spike story after FR-004 to validate llmsherpa + GPT-4o Vision on 2-3 representative books before committing to full-corpus implementation. Sprint planning should include a risk buffer for Epic 3.

**Definition of Done:** All 25 books ingested. Corpus scan report reviewed. 100% chunk metadata coverage. Qdrant snapshots operational. BM25 index in S3 with checksum.

### Epic 4: RAG Query Engine
The API consumer can submit PLC @ Work questions and receive grounded, cited answers powered by hybrid retrieval, cross-encoder re-ranking, and metadata filtering. FR-020 completed in this epic — model readiness checks (re-ranker + BM25) added to health endpoint, NFR-009 cold start verified.
**FRs covered:** FR-005, FR-010, FR-011, FR-012, FR-013, FR-020 (completed — model readiness)
**NFRs addressed:** NFR-001, NFR-009

**Definition of Done:** Query endpoint returns grounded, cited answers against ingested corpus. Hybrid retrieval (vector + BM25 + re-ranker) operational. Metadata filtering works. Health check includes model readiness. RAGAS reference-free scores meet Phase 0-B expectations.

### Epic 5: Conversational Query Intelligence
The API consumer gets intelligent query handling — ambiguous queries receive exactly one targeted clarifying question via session management, and out-of-scope queries receive a clear boundary signal.
**FRs covered:** FR-006, FR-007, FR-008, FR-009

**Definition of Done:** Ambiguity detection, one-question clarification flow, and out-of-scope refusal all operational. Session management via Redis (building on Epic 1 session service skeleton). Golden dataset labeled subset validates precision >= 0.80, recall >= 0.70.

### Epic 6: Quality Evaluation & Validation
The evaluator can measure RAG pipeline quality using RAGAS metrics, compare against a raw GPT-4o baseline, and collect A/B style preference data for answer tuning.
**FRs covered:** FR-014, FR-015, FR-016, FR-017
**NFRs addressed:** NFR-003 (load test must execute after Epic 5 complete to exercise full pipeline including clarification-flow sessions)

**Definition of Done:** Full RAGAS evaluation (reference-free + reference-based). Baseline comparison complete. Style preference data collected. Load test passes with 5 concurrent users (after Epic 5 complete).

### Dependency Flow

```
Epic 1 → Epic 2 → Epic 3 → Epic 4 → Epic 5
                                    → Epic 6 (parallel with Epic 5)
```

### Cross-Cutting Patterns

Epic 1 establishes all cross-cutting patterns that every subsequent epic must conform to. These are mandatory, not optional:

1. **Structured JSON logging** — 17 events in catalog, service layer only. No undocumented events.
2. **FERPA compliance** — `store: false` on all OpenAI requests, SHA-256 cache keys, no PII in logs at any level.
3. **Exception hierarchy** — `PLCCopilotError` base with subclasses, global handler, no try/except in routes.
4. **Layer boundaries** — Routes → Services → Repositories/Retrieval. No shortcuts.
5. **Response format** — Pydantic `exclude_none=True` on all responses. No `null` values.
6. **Date/time** — UTC-only datetimes everywhere. `datetime.now(datetime.timezone.utc)`.

**Enforcement:** Code review criteria for every story in Epics 2–6 include pattern compliance. Reference: Architecture doc → Cross-Cutting Concerns; CLAUDE.md → Error Handling, Logging, FERPA sections.

### Cross-Epic Dependencies

| Dependency | Producer Epic | Consumer Epic | What Must Align |
|---|---|---|---|
| Re-ranker model in Docker image | Epic 4 (defines model) | Epic 2 (builds image) | Dockerfile must include model download/copy step from Epic 2 onward |
| Qdrant snapshot cron | Epic 2 (infra) + Epic 3 (data) | Operations | Epic 3 includes post-ingestion snapshot; cron setup as late Epic 3 story |
| BM25 serialized index | Epic 3 (produces) | Epic 4 (consumes) | S3 path, pickle format, SHA-256 checksum contract |
| Vocabulary table schema | Epic 3 (populates) | Epic 4 (reads at startup) | PostgreSQL table schema defined in Epic 1 migration, populated in Epic 3 |
| Redis session/cache service | Epic 1 (scaffolds) | Epic 4 (cache), Epic 5 (sessions) | Service interface defined in Epic 1, logic built in consuming epics |

---

## Epic 1: Project Scaffold & Core API

The developer can clone the repo, run `docker compose up`, and have a working local API skeleton with auth, health checks, audit logging, error handling, and a test client — ready for feature development. Establishes the Redis service layer (connection pool management, session service skeleton, cache service skeleton) that Epic 4 (caching) and Epic 5 (sessions) build upon.

### Story 1.1: Project Initialization and Directory Structure

As a developer,
I want to clone the repo and have a fully structured Python project with local dev services running,
So that I can begin feature development immediately with consistent tooling.

**Acceptance Criteria:**

**Given** a fresh clone of the repository
**When** the developer runs `uv sync`
**Then** all dependencies install successfully, including FastAPI, Pydantic, SQLAlchemy, Redis, and dev dependencies (ruff, mypy, pytest, pre-commit)

**Given** the project is initialized
**When** the developer inspects the directory structure
**Then** the following structure exists:
- `src/plc_copilot/api/routes/` (query.py, health.py placeholders)
- `src/plc_copilot/api/middleware/` (auth.py placeholder)
- `src/plc_copilot/models/`
- `src/plc_copilot/services/`
- `src/plc_copilot/repositories/`
- `src/plc_copilot/retrieval/`
- `src/plc_copilot/core/` (config.py, logging.py, exceptions.py placeholders)
- `src/plc_copilot/ingestion/`
- `src/plc_copilot/static/`
- `tests/unit/`, `tests/integration/`, `tests/evaluation/data/`, `tests/load/`
- `src/plc_copilot/main.py` with FastAPI app instance

**Given** Docker and Docker Compose are installed
**When** the developer runs `docker compose -f docker-compose.dev.yml up -d`
**Then** PostgreSQL, Redis, and Qdrant containers start and are reachable on their configured ports

**Given** the project is initialized
**When** the developer runs `pre-commit run --all-files`
**Then** ruff check, ruff format, and mypy hooks execute (may pass with no source files to check)

**Given** the project is initialized
**When** the developer runs `uv run uvicorn plc_copilot.main:app --reload`
**Then** the FastAPI app starts and returns a response on the root or docs endpoint

**Given** the project root
**When** the developer inspects `.env.example`
**Then** all environment variables from the architecture doc are listed with placeholder values and comments

### Story 1.2: Core Configuration and Exception Hierarchy

As a developer,
I want centralized configuration management and a consistent exception handling pattern,
So that all future features use the same config source and error handling conventions from day one.

**Acceptance Criteria:**

**Given** environment variables are set (or `.env` file exists)
**When** the application starts
**Then** a single Pydantic `Settings` class in `core/config.py` loads all configuration from environment variables, with validation errors raised on missing required vars

**Given** the exception module `core/exceptions.py`
**When** a developer inspects the module
**Then** it contains `PLCCopilotError` base class and subclasses: `SessionExpiredError`, `QueryProcessingError`, `RetrievalError`, `AuthenticationError`, and any others specified in the architecture doc

**Given** the FastAPI app is running
**When** a `PLCCopilotError` subclass is raised anywhere in the call stack
**Then** the global exception handler catches it and returns the corresponding PRD error body:
- `AuthenticationError` → 401 `{"error": "Unauthorized"}`
- `SessionExpiredError` → 400 `{"error": "Session expired or not found. Please resubmit your original query."}`
- `RetrievalError` or service unavailable → 503 `{"error": "The service is temporarily unavailable. Please try again."}`
- Unhandled exceptions → 500 `{"error": "An unexpected error occurred."}`
**And** no stack traces are leaked in any error response

**Given** Pydantic response models are defined
**When** a response is serialized
**Then** `model_config` uses `exclude_none=True` so no `null` values appear in JSON responses

**Given** any module that uses timestamps
**When** the current time is needed
**Then** `datetime.datetime.now(datetime.timezone.utc)` is used — never naive `datetime.now()`

### Story 1.3: Database Foundation

As a developer,
I want a configured async database layer with migration tooling,
So that future stories can define and migrate schemas as needed.

**Acceptance Criteria:**

**Given** the application configuration includes a database URL
**When** the SQLAlchemy engine is initialized
**Then** it uses async sessions with the following pool settings: `pool_size=5`, `max_overflow=5`, `pool_timeout=10`, `pool_recycle=1800`

**Given** the project has Alembic initialized
**When** the developer runs `uv run alembic upgrade head`
**Then** the database is migrated to the latest version, creating the `audit_logs` table with columns: `id` (UUID PK), `timestamp` (TIMESTAMP WITH TIME ZONE), `event` (VARCHAR), `level` (VARCHAR), `user_id` (VARCHAR, nullable), `source_ip` (VARCHAR, nullable), `conversation_id` (VARCHAR, nullable), `metadata` (JSONB, nullable)

**Given** the `audit_logs` table exists
**When** the developer inspects its indexes
**Then** indexes exist on `timestamp` and `event` columns following the naming convention `ix_audit_logs_{column}`

**Given** the repository layer
**When** a developer inspects `repositories/`
**Then** an `audit_log_repository.py` exists with async methods to insert audit log records using SQLAlchemy

### Story 1.4: Redis Connection Pool and Service Skeletons

As a developer,
I want Redis connectivity with defined service interfaces for sessions and caching,
So that Epic 4 (caching) and Epic 5 (sessions) can implement business logic against stable interfaces.

**Acceptance Criteria:**

**Given** the application configuration includes Redis connection settings
**When** the Redis connection pool is initialized
**Then** it uses the following settings: `max_connections=20`, `socket_timeout=5`, `socket_connect_timeout=2`
**And** the connection uses TLS (`rediss://` scheme) when configured for non-local environments

**Given** the session service skeleton in `services/session_service.py`
**When** a developer inspects the interface
**Then** it defines async methods: `create_session()`, `get_session()`, `update_session()`, `delete_session()` with session TTL defaulting to 15 minutes (900 seconds)
**And** methods raise `NotImplementedError` or return placeholder responses (skeleton only — logic built in Epic 5)

**Given** the cache service skeleton in `services/cache_service.py`
**When** a developer inspects the interface
**Then** it defines async methods: `get_cached_response()`, `set_cached_response()` with cache TTL defaulting to 24 hours (86400 seconds)
**And** cache key format is `cache:{sha256(normalized_query_text)}` — never raw query text (FERPA)
**And** methods raise `NotImplementedError` or return placeholder responses (skeleton only — logic built in Epic 4)

**Given** the Redis pool is initialized
**When** the application starts
**Then** the pool is created via FastAPI lifespan context manager and available for dependency injection into services

### Story 1.5: Structured JSON Audit Logging

As an operator,
I want all API events captured in structured JSON logs with request context,
So that I can verify system behavior and maintain FERPA-compliant audit trails (FR-019).

**Acceptance Criteria:**

**Given** the logging configuration in `core/logging.py`
**When** the application starts
**Then** Python stdlib `logging` is configured with a JSON formatter producing one JSON object per log line with required fields: `timestamp` (ISO 8601 UTC), `level`, `event`, `conversation_id` (when available), `user_id` (when in request context), `source_ip` (from `X-Forwarded-For`)

**Given** a request is processed by the API
**When** logging middleware executes
**Then** request context (user_id, source_ip, conversation_id) is captured and made available to all downstream loggers in the request scope

**Given** the event catalog
**When** a developer inspects the initial catalog entries
**Then** the following events are defined (at minimum): `auth_key_validated`, `auth_key_rejected`, `health_check_requested`, `query_received`, `query_completed`, `query_failed`
**And** all events use `snake_case` verb-noun naming prefixed by subsystem

**Given** any log entry at any level (including DEBUG)
**When** the log content is inspected
**Then** no PII is present — no query text, no student names, no student-identifiable content (FERPA mandated)

**Given** the audit log service in `services/`
**When** a loggable event occurs
**Then** the event is both written to structured stdout logging AND persisted to the `audit_logs` table via the audit log repository

### Story 1.6: API Key Authentication Middleware

As an API consumer,
I want requests authenticated via a static API key in the `X-API-Key` header,
So that only authorized clients can access the service (FR-018).

**Acceptance Criteria:**

**Given** a request with a valid `X-API-Key` header
**When** the authentication middleware processes the request
**Then** the request proceeds to the route handler
**And** an `auth_key_validated` event is logged

**Given** a request with a missing `X-API-Key` header
**When** the authentication middleware processes the request
**Then** a 401 response is returned with body `{"error": "Unauthorized"}`
**And** an `auth_key_rejected` event is logged

**Given** a request with an empty `X-API-Key` header value
**When** the authentication middleware processes the request
**Then** a 401 response is returned with body `{"error": "Unauthorized"}`

**Given** a request with an invalid `X-API-Key` header value
**When** the authentication middleware processes the request
**Then** a 401 response is returned with body `{"error": "Unauthorized"}`

**Given** the API key value
**When** the application is configured
**Then** the key is read from an environment variable (injected from AWS Secrets Manager in production), never hardcoded

**Given** the health check endpoint `/api/v1/health`
**When** a request is made without an API key
**Then** the health check is accessible without authentication (health checks are excluded from auth middleware)

### Story 1.7: Health Check Endpoint

As an operator,
I want a health check endpoint that reports service readiness,
So that I can verify the API and its dependencies are operational (FR-020 partial).

**Acceptance Criteria:**

**Given** the API is running and PostgreSQL and Redis are reachable
**When** a GET request is made to `/api/v1/health`
**Then** a 200 OK response is returned with a JSON body indicating healthy status for each dependency (database, redis)

**Given** the API is running but PostgreSQL is unreachable
**When** a GET request is made to `/api/v1/health`
**Then** a non-200 response is returned indicating the database dependency is unhealthy

**Given** the API is running but Redis is unreachable
**When** a GET request is made to `/api/v1/health`
**Then** a non-200 response is returned indicating the Redis dependency is unhealthy

**Given** the health check endpoint
**When** a request is made
**Then** a `health_check_requested` event is logged
**And** the response does not require API key authentication

**Given** this is Epic 1 (partial FR-020)
**When** the health check is reviewed
**Then** it checks DB and Redis connectivity only — model readiness checks (re-ranker, BM25) will be added in Epic 4 to complete FR-020

### Story 1.8: Minimal Test Client

As an internal tester,
I want a web-based test client to submit queries and view responses,
So that I can manually test the API without external tools (FR-021).

**Acceptance Criteria:**

**Given** the API is running
**When** a user navigates to `/static/test_client.html` in a browser
**Then** a minimal HTML page is displayed with a question input field and a response display area

**Given** the test client is loaded
**When** the page first renders
**Then** a disclaimer banner is visible stating this is an internal testing tool (exact text per PRD)

**Given** the test client page
**When** the user enters a question and submits
**Then** the client sends a POST request to `/api/v1/query` with the API key in the `X-API-Key` header and displays the response

**Given** the test client
**When** the API returns an error response
**Then** the error message is displayed to the user in the response area

**Given** the test client implementation
**When** a developer inspects the file
**Then** it is a single static HTML file (with inline CSS/JS) served by FastAPI's static file mounting — no build tooling required

---

## Epic 2: Infrastructure & CI/CD

The operator can deploy the API to AWS staging and promote to production through an automated, security-scanned pipeline. Includes pre-launch compliance checklist as a deliverable.

### Story 2.1: Terraform Foundation — VPC, Networking, and S3 Backend

As an operator,
I want a reproducible AWS network foundation with infrastructure state management,
So that all subsequent infrastructure modules deploy into a secure, consistent environment.

**Acceptance Criteria:**

**Given** Terraform is initialized with S3 backend
**When** `terraform init` is run
**Then** state is stored in an S3 bucket with DynamoDB lock table for concurrency control

**Given** the VPC module under `terraform/modules/vpc/`
**When** `terraform apply` is run for staging
**Then** a VPC is created with:
- Private subnets for data stores and compute
- Public subnet for ALB only
- NAT gateway for controlled egress from private subnets
- Single AZ deployment (MVP)
**And** the VPC CIDR and subnet CIDRs are configurable via variables

**Given** the networking resources
**When** the ALB is provisioned
**Then** it sits in the public subnet with HTTPS listener (TLS 1.2+ per NFR-004)
**And** health check path is configured to `/health` with interval 30s, unhealthy threshold 2, healthy threshold 2

**Given** the Terraform structure
**When** a developer inspects `terraform/`
**Then** separate environment variable files exist for staging and production (`terraform/environments/staging.tfvars`, `terraform/environments/production.tfvars`)

### Story 2.2: Terraform Data Stores — RDS, ElastiCache, S3 Bucket

As an operator,
I want managed data stores provisioned with encryption and backup policies,
So that the API has persistent storage meeting NFR-004 (encryption) and NFR-006 (backup) requirements.

**Acceptance Criteria:**

**Given** the RDS module under `terraform/modules/rds/`
**When** `terraform apply` is run
**Then** an RDS PostgreSQL instance is created: `db.t3.micro`, 20 GB `gp3` storage, encrypted at rest (KMS), automated backups with 7-day retention
**And** the instance is placed in a private subnet with a security group allowing connections only from the Fargate service and ingestion pipeline security groups

**Given** the ElastiCache module under `terraform/modules/elasticache/`
**When** `terraform apply` is run
**Then** a Redis instance is created: `cache.t3.micro`, single-node, `at_rest_encryption_enabled = true`, `transit_encryption_enabled = true`
**And** the instance is placed in a private subnet with a security group allowing connections only from the Fargate service security group

**Given** the S3 module under `terraform/modules/s3/`
**When** `terraform apply` is run
**Then** a private S3 bucket is created with versioning enabled, server-side encryption (SSE-S3 or SSE-KMS), and bucket policy restricting access via IAM only (no public access)
**And** IAM policies restrict `PutObject` on `bm25-index/` prefix to the ingestion pipeline role and `GetObject` to the Fargate task role

**Given** all data store resources
**When** network traffic is inspected
**Then** all data in transit uses TLS 1.2+ (NFR-004) — including the `rediss://` scheme for ElastiCache connections

### Story 2.3: Terraform Compute — Qdrant EC2 and ECS Fargate

As an operator,
I want compute infrastructure for the API service and vector database,
So that the application can run in a secure, right-sized AWS environment.

**Acceptance Criteria:**

**Given** the Qdrant module under `terraform/modules/qdrant/`
**When** `terraform apply` is run
**Then** a `t3.medium` EC2 instance is created with 50 GB `gp3` EBS (encrypted), Qdrant installed and running with API key authentication enabled
**And** the security group restricts port 6333/6334 inbound to only the Fargate service security group and the ingestion pipeline security group — not the entire VPC CIDR

**Given** the ECS module under `terraform/modules/ecs/`
**When** `terraform apply` is run
**Then** an ECS Fargate service is created with: 1 vCPU / 2 GB memory task definition, rolling update deployment with circuit breaker enabled (`deployment_circuit_breaker { enable = true, rollback = true }`), minimum healthy percent 100%, maximum percent 200%
**And** an ECR repository exists for the API Docker image

**Given** the Fargate task definition
**When** the task is inspected
**Then** environment variables are injected from AWS Secrets Manager (API key, database URL, Redis URL, Qdrant API key, OpenAI API key)
**And** the task role has least-privilege IAM permissions: S3 `GetObject` for BM25 index, CloudWatch Logs `PutLogEvents`, Secrets Manager `GetSecretValue`

**Given** the ECS service
**When** a deployment fails health checks
**Then** the circuit breaker automatically rolls back to the last working task definition

### Story 2.4: Terraform Observability — CloudWatch Log Groups and Backup Monitoring

As an operator,
I want separated log retention and backup monitoring,
So that audit logs meet NFR-005 retention requirements and backup failures are detected (NFR-006).

**Acceptance Criteria:**

**Given** the Terraform observability configuration
**When** `terraform apply` is run
**Then** two CloudWatch log groups are created:
- `/plc-copilot/audit` with 90-day retention and S3 Glacier archival policy for 1-year total retention
- `/plc-copilot/app` with 30-day retention
**And** retention periods are explicitly set in Terraform — not relying on CloudWatch defaults

**Given** the Qdrant backup monitoring
**When** `terraform apply` is run
**Then** a CloudWatch metric alarm monitors the S3 `LastModified` timestamp of the latest Qdrant snapshot object
**And** the alarm fires to SNS if no new snapshot appears within 26 hours (24h daily cron + 2h buffer)

**Given** the Fargate service logging
**When** the ECS task definition is inspected
**Then** the `awslogs` log driver is configured to send container stdout/stderr to the appropriate CloudWatch log group

### Story 2.5: CI/CD Pipeline — PR Checks and Staging Deploy

As a developer,
I want automated quality checks on PRs and automatic staging deployment on merge,
So that code quality is enforced and staging always reflects the latest main branch (NFR-007).

**Acceptance Criteria:**

**Given** a pull request is opened against `main`
**When** the PR pipeline runs
**Then** it executes in order: `ruff check .` → `ruff format --check .` → `mypy src/` → `pytest tests/unit/`
**And** the PR is blocked from merging if any step fails

**Given** a commit is merged to `main`
**When** the merge-to-main pipeline runs
**Then** it executes in order: build Docker image (with re-ranker model weights baked in at build time) → `trivy image --severity CRITICAL,HIGH --exit-code 1` → push to ECR → update ECS staging service with new task definition → run automated smoke test (health check + single query)
**And** the pipeline fails and does not push to ECR if Trivy finds critical or high CVEs (NFR-007)

**Given** the Dockerfile
**When** the Docker image is built
**Then** it includes a pre-cache step that downloads the cross-encoder/ms-marco-MiniLM-L-6-v2 model weights (~90MB) into the image layer during build — not at runtime

**Given** the staging deployment succeeds
**When** the smoke test runs
**Then** it verifies the health check endpoint returns 200 and a single test query returns a valid response shape

### Story 2.6: CI/CD Pipeline — Production Promotion and Ingestion Trigger

As an operator,
I want manual production promotion and a triggerable ingestion workflow,
So that production deploys are deliberate and ingestion can be run on-demand or on schedule.

**Acceptance Criteria:**

**Given** a successful staging deployment
**When** an operator manually triggers the production promotion workflow in GitHub Actions
**Then** the production ECS service is updated with the same Docker image tag that is running in staging — no rebuild, no re-scan
**And** the workflow requires explicit manual trigger (no automatic production deploys on merge)

**Given** the ingestion pipeline
**When** an operator manually triggers the ingestion workflow (or it runs on schedule)
**Then** GitHub Actions sends an SSM Run Command to the Qdrant EC2 instance to execute the ingestion Docker container
**And** the workflow accepts parameters for which books to ingest (all or specific subset)

**Given** the ingestion Docker image
**When** `Dockerfile.ingestion` is inspected
**Then** it is a separate Dockerfile from the API, containing the ingestion pipeline dependencies
**And** it is built and pushed to ECR via a separate workflow or as part of the merge-to-main pipeline

**Given** the production promotion workflow
**When** an operator needs to rollback
**Then** documented rollback procedure exists: `aws ecs update-service --cluster <cluster> --service <service> --task-definition <previous-revision> --force-new-deployment`

### Story 2.7: Pre-Launch Compliance Checklist Documentation

As an operator,
I want a documented compliance checklist with code-verifiable assertions,
So that all FERPA and security requirements are tracked and verified before production launch.

**Acceptance Criteria:**

**Given** the compliance checklist document
**When** an operator reviews it
**Then** it contains all items from the architecture doc's Pre-Launch Compliance Checklist:
- OpenAI DPA execution verification (operational — owner and target date fields)
- `store: false` code assertion (code-verifiable — unit test exists that greps for `store` parameter on all OpenAI calls)
- OpenAI spending limits configuration (operational — documented procedure)
- API key rotation procedure (operational — step-by-step documented)
- Solution Tree content license confirmation (legal — owner and target date fields)
- NFR-007 Trivy scan gate operational (code-verifiable — CI pipeline step verified in Story 2.5)

**Given** the code-verifiable compliance items
**When** the test suite runs
**Then** a dedicated test file `tests/unit/test_compliance.py` contains assertions that:
- All OpenAI client instantiations or call wrappers enforce `store=False`
- No log statements contain query text or PII patterns

**Given** the compliance documentation
**When** it is stored
**Then** it lives in the project repository (e.g., `docs/compliance-checklist.md`) and is version-controlled

---

## Epic 3: Content Ingestion Pipeline

The operator can ingest the full 25-book PLC @ Work corpus through a layout-aware parsing pipeline, producing richly-tagged, searchable chunks in the vector store and relational database.

### Story 3.1: Corpus Scan and Validation Report (FR-004)

As an operator,
I want an automated scan of all 25 source PDFs before ingestion,
So that I can validate corpus assumptions and make an informed go/no-go decision before committing to full parsing (FR-004).

**Acceptance Criteria:**

**Given** 25 PLC @ Work PDF files are available in the S3 source bucket
**When** the operator runs the corpus scan script (`uv run python -m plc_copilot.ingestion.scan`)
**Then** a scan report is produced for each book containing: total page count, portrait page count, landscape page count, pages with text layers, pages without text layers

**Given** the scan completes
**When** the operator reviews the report
**Then** anomalies are documented (e.g., books with unexpectedly high landscape page counts, books with missing text layers)
**And** the report includes aggregate totals across all 25 books

**Given** pages without text layers are detected
**When** they appear in the scan report
**Then** they are flagged for manual review with book title, page number, and reason

**Given** the scan report
**When** landscape page volumes are known
**Then** an estimated GPT-4o Vision processing time can be calculated (N landscape pages x estimated seconds per call) for comparison against the NFR-008 8-hour ceiling

**Given** the scan script
**When** a developer inspects it
**Then** it uses PyMuPDF for page classification (orientation detection and text-layer presence) and does not require any LLM calls

### Story 3.2: Database Schema for Books, Chunks, and Vocabulary

As a developer,
I want database tables to store book metadata, chunk data, and vocabulary for metadata extraction,
So that ingested content has a relational home and Epic 4 can use the vocabulary for dynamic metadata filtering (FR-003, cross-epic dependency).

**Acceptance Criteria:**

**Given** the Alembic migration is run
**When** `uv run alembic upgrade head` completes
**Then** a `books` table is created with columns: `id` (integer PK), `title` (VARCHAR, not null), `authors` (VARCHAR, not null), `sku` (VARCHAR, unique, not null), `page_count` (integer), `created_at` (TIMESTAMP WITH TIME ZONE)
**And** a unique constraint `uq_books_sku` exists on the `sku` column

**Given** the migration completes
**When** the `chunks` table is inspected
**Then** it contains columns: `id` (integer PK), `book_id` (integer FK to `books.id`, not null), `chapter_number` (integer, nullable), `section` (VARCHAR, nullable), `page_number` (integer), `content_type` (VARCHAR, not null), `chunk_text` (TEXT, not null), `qdrant_id` (UUID, unique), `embedding_model` (VARCHAR), `created_at` (TIMESTAMP WITH TIME ZONE)
**And** an index `ix_chunks_book_id` exists on `book_id`

**Given** the migration completes
**When** the `vocabulary` table is inspected
**Then** it contains columns: `id` (integer PK), `term` (VARCHAR, not null), `term_type` (VARCHAR, not null — one of 'book_title', 'author', 'chunk_type'), `reference_id` (integer, nullable — FK to books.id for book/author terms)
**And** an index exists on `term_type`

**Given** the repository layer
**When** a developer inspects `repositories/`
**Then** `book_repository.py` and `chunk_repository.py` exist with async CRUD methods

### Story 3.3: Parsing Spike — llmsherpa and GPT-4o Vision Validation

As a developer,
I want to validate that llmsherpa and GPT-4o Vision produce usable output on representative books,
So that I can make an informed go/no-go decision before building the full parsing pipeline (risk mitigation).

**Acceptance Criteria:**

**Given** 2-3 representative books are selected (at least one with significant landscape pages, one with complex portrait formatting)
**When** llmsherpa is run against portrait pages
**Then** the output is evaluated for: hierarchical structure preservation (chapters, sections), text extraction accuracy, handling of tables and figures
**And** findings are documented with examples of good and problematic output

**Given** the same representative books
**When** GPT-4o Vision is run against landscape pages
**Then** the output is evaluated for: structured textual description quality, reproducible content capture accuracy, processing time per page
**And** `store: false` is enforced on all OpenAI API calls (FERPA)

**Given** the spike results
**When** the findings are reviewed
**Then** a brief spike report documents: tool viability assessment, identified limitations, recommended workarounds, and go/no-go recommendation for each tool
**And** estimated total GPT-4o Vision cost and processing time for the full corpus are calculated

**Given** either tool is found unsuitable
**When** the spike report is reviewed
**Then** alternative approaches are documented for team discussion before proceeding

### Story 3.4: Portrait Page Parser — PyMuPDF Classification and llmsherpa Structure

As a developer,
I want portrait pages with text layers parsed into structured, hierarchical chunks,
So that the content is searchable with chapter and section context preserved (FR-002).

**Acceptance Criteria:**

**Given** a PDF is loaded into the ingestion pipeline
**When** PyMuPDF classifies each page
**Then** pages are categorized as: portrait with text layer, landscape (any), or portrait without text layer

**Given** portrait pages with text layers
**When** llmsherpa processes them
**Then** structured chunks are produced preserving hierarchical context: chapter number, section heading, page number
**And** each chunk contains meaningful, self-contained text (not fragments split mid-sentence)

**Given** pages without text layers are encountered
**When** the parser processes them
**Then** they are flagged and logged with book title and page number for manual review
**And** processing continues to the next page without failing

**Given** the parser module
**When** a developer inspects `ingestion/parsers/`
**Then** a `portrait_parser.py` module exists following the ingestion directory structure from the architecture doc

**Given** the parsed output
**When** chunks are inspected
**Then** each chunk carries metadata: book_id, chapter_number, section, page_number, content_type (e.g., 'text', 'table', 'figure_description')

### Story 3.5: Landscape Page Parser — GPT-4o Vision

As a developer,
I want landscape pages processed into structured textual descriptions,
So that reproducible content (worksheets, forms, diagrams) is searchable alongside regular text (FR-002).

**Acceptance Criteria:**

**Given** landscape pages identified by PyMuPDF classification
**When** GPT-4o Vision processes each page
**Then** a structured textual description is produced capturing the content's purpose and key elements

**Given** any OpenAI API call in the landscape parser
**When** the call is made
**Then** `store: false` is set on the request (FERPA mandatory — zero-retention)
**And** 2 retries with exponential backoff are configured; on final failure the page is logged as failed and processing continues

**Given** landscape page chunks
**When** they are stored
**Then** each chunk is tagged with `chunk_type: reproducible` to distinguish them from regular text chunks

**Given** the parser module
**When** a developer inspects `ingestion/parsers/`
**Then** a `landscape_parser.py` module exists

**Given** the estimated processing time from the corpus scan (Story 3.1)
**When** landscape pages are processed
**Then** actual per-page processing time is logged for comparison against NFR-008 estimates

### Story 3.6: Chunk Metadata Tagging and Dual-Store Storage (FR-003)

As an operator,
I want every chunk stored with standardized metadata in both the vector store and relational database,
So that 100% of content is searchable with complete provenance (FR-003).

**Acceptance Criteria:**

**Given** chunks produced by the portrait and landscape parsers
**When** they are stored
**Then** every chunk has all required metadata fields populated: book title, authors, SKU, chapter number (nullable for non-chapter content), section, page number, and content type

**Given** a chunk is ready for storage
**When** the storage step executes
**Then** the chunk is written to both:
- PostgreSQL `chunks` table with all metadata columns populated
- Qdrant collection with the text embedding vector and metadata payload (book_title, authors, sku, chapter_number, section, page_number, content_type)

**Given** embeddings are generated for chunks
**When** the OpenAI embedding API is called
**Then** the model `text-embedding-3-large` is used (3,072 dimensions)
**And** `store: false` is set on every embedding request (FERPA)
**And** the embedding model identifier is recorded in the Qdrant collection metadata and the `chunks.embedding_model` column

**Given** the vocabulary table
**When** book and chunk storage completes
**Then** the `vocabulary` table is populated with all book titles (term_type: 'book_title'), all authors (term_type: 'author'), and all distinct content types (term_type: 'chunk_type')

**Given** the full corpus is ingested
**When** an operator runs a metadata coverage check
**Then** 100% of chunks have all required metadata fields populated (spot-check confirms accuracy)

### Story 3.7: Full Corpus Ingestion Orchestrator (FR-001)

As an operator,
I want to run a single command that ingests all 25 books end-to-end with failure isolation,
So that the complete corpus is available for querying and individual failures don't block the pipeline (FR-001, NFR-008).

**Acceptance Criteria:**

**Given** 25 PLC @ Work PDFs are available in S3
**When** the operator runs `uv run python -m plc_copilot.ingestion`
**Then** all 25 books are processed through the classification → parsing → embedding → storage pipeline

**Given** a single book fails during processing
**When** the error occurs
**Then** the failure is logged with structured error details (book SKU, error type, stage of failure) via `ingestion_book_failed` event
**And** processing continues to the next book without interruption

**Given** the full ingestion completes
**When** the summary report is generated
**Then** it lists: books succeeded (count + SKUs), books failed (count + SKUs + error summaries), total chunks created, total duration
**And** `ingestion_completed` event is logged with `books_succeeded`, `books_failed`, `total_duration_ms`

**Given** ingestion completes successfully
**When** post-processing runs
**Then** a BM25 index is built from all chunk texts, serialized with pickle, a SHA-256 checksum file is generated, and both are uploaded to S3 at the configured path

**Given** the full ingestion run
**When** total elapsed time is measured
**Then** it completes within 8 hours (NFR-008)
**And** per-book duration is logged via `ingestion_book_completed` events for bottleneck identification

**Given** the ingestion pipeline
**When** it is run via SSM Run Command (production) or locally (development)
**Then** it uses the same entry point and configuration, differing only in environment variables

### Story 3.8: Qdrant Snapshots and Post-Ingestion Backup (NFR-006)

As an operator,
I want automated Qdrant snapshots with post-ingestion verification,
So that the vector store can be recovered within the 4-hour RTO target (NFR-006).

**Acceptance Criteria:**

**Given** ingestion completes successfully (Story 3.7)
**When** the post-ingestion step runs
**Then** a Qdrant snapshot is triggered via the Qdrant snapshot API
**And** the snapshot is uploaded to the S3 private bucket under `qdrant-snapshots/` prefix
**And** ingestion is not considered "done" until the snapshot upload is confirmed

**Given** the Qdrant EC2 instance
**When** a daily cron job runs
**Then** it triggers a Qdrant snapshot and uploads it to S3
**And** the cron job logs success or failure to the EC2 instance's CloudWatch agent log stream

**Given** Qdrant snapshots in S3
**When** snapshot retention is evaluated
**Then** snapshots older than 7 days are automatically deleted (matching RDS backup retention)

**Given** a disaster recovery scenario
**When** an operator follows the documented recovery procedure
**Then** the procedure covers: re-provision EC2 via `terraform apply`, download latest snapshot from S3, restore snapshot to Qdrant, verify collection health and expected point count, verify API health check passes

**Given** the snapshot monitoring
**When** no new snapshot appears in S3 within 26 hours
**Then** the CloudWatch alarm (configured in Story 2.4) fires to alert the operator

---

## Epic 4: RAG Query Engine

The API consumer can submit PLC @ Work questions and receive grounded, cited answers powered by hybrid retrieval, cross-encoder re-ranking, and metadata filtering. FR-020 completed in this epic — model readiness checks added to health endpoint, NFR-009 cold start verified.

### Story 4.1: Retrieval Abstraction Layer and Qdrant Vector Search (FR-011)

As a developer,
I want a retrieval abstraction with a working vector search implementation,
So that semantic search is available and future retrieval strategies can be swapped without changing the query engine (FR-011).

**Acceptance Criteria:**

**Given** the retrieval layer
**When** a developer inspects `retrieval/base.py`
**Then** an abstract base class defines the retriever interface with an async `retrieve(query_text, top_k, filters)` method returning a list of scored chunk results

**Given** the Qdrant vector retriever in `retrieval/vector_retriever.py`
**When** a query is submitted
**Then** the query text is embedded using `text-embedding-3-large` (3,072 dimensions) with `store: false` (FERPA)
**And** Qdrant is searched using the embedding vector, returning the top-k results with scores and full metadata payloads

**Given** the Qdrant client configuration
**When** the client is initialized
**Then** it uses API key authentication, gRPC port 6334 for search operations, and a 10-second timeout per request

**Given** the Qdrant collection
**When** the API starts and connects to Qdrant
**Then** the embedding model identifier stored in collection metadata is compared against the configured model
**And** if mismatched, an `ERROR`-level event is logged and the application refuses to start

**Given** an ablation test comparing vector-only retrieval vs. no retrieval
**When** the test is run against in-scope golden dataset queries
**Then** vector search returns relevant chunks demonstrating positive retrieval quality (foundation for FR-011 ablation in Epic 6)

### Story 4.2: BM25 Keyword Search (FR-012)

As a developer,
I want keyword-based search using BM25,
So that PLC jargon and acronyms are matched exactly when vector similarity alone would miss them (FR-012).

**Acceptance Criteria:**

**Given** the FastAPI lifespan startup sequence
**When** the application starts
**Then** the serialized BM25 index is downloaded from S3 at the configured path
**And** the SHA-256 checksum is verified against the accompanying checksum file before deserialization
**And** if checksum verification fails, the application logs an `ERROR` and refuses to start

**Given** the BM25 retriever in `retrieval/bm25_retriever.py`
**When** a query is submitted
**Then** the BM25 index is searched and the top-k results are returned with BM25 scores and chunk identifiers

**Given** the BM25 retriever implements the retrieval abstraction interface
**When** a developer inspects the class
**Then** it extends the base retriever class from `retrieval/base.py`

**Given** a set of PLC jargon and acronym queries (e.g., "SMART goals", "DuFour", "CFAs")
**When** BM25 search is run
**Then** results contain chunks with exact keyword matches, demonstrating keyword recall capability

### Story 4.3: Cross-Encoder Re-Ranking (FR-013)

As a developer,
I want retrieval results scored and reordered by a cross-encoder model,
So that the most relevant chunks are presented to the LLM for answer generation (FR-013).

**Acceptance Criteria:**

**Given** the re-ranker module in `retrieval/reranker.py`
**When** a list of candidate chunks and a query are provided
**Then** the cross-encoder/ms-marco-MiniLM-L-6-v2 model scores each chunk against the query
**And** results are returned sorted by re-ranker score in descending order

**Given** the FastAPI lifespan startup sequence
**When** the application starts
**Then** the re-ranker model is loaded from the Docker image's baked-in weights (not downloaded at runtime)
**And** model loading time is logged for NFR-009 cold start tracking

**Given** the re-ranker is loaded
**When** the health check is queried
**Then** the re-ranker model readiness is available as a status signal (consumed by Story 4.8)

**Given** a set of retrieval results before and after re-ranking
**When** results are compared
**Then** re-ranking demonstrably reorders results (top result after re-ranking differs from top result before for at least some queries)

### Story 4.4: Hybrid Retrieval Orchestrator

As a developer,
I want a single orchestrator that coordinates vector search, keyword search, and re-ranking,
So that the query service calls one method and gets the best possible retrieval results.

**Acceptance Criteria:**

**Given** the hybrid orchestrator in `retrieval/hybrid_orchestrator.py`
**When** a query is submitted with a top-k parameter
**Then** the orchestrator:
1. Runs vector search (Story 4.1) and BM25 search (Story 4.2) concurrently
2. Merges results from both retrievers
3. Deduplicates chunks that appear in both result sets (by qdrant_id)
4. Passes merged candidates to the re-ranker (Story 4.3)
5. Returns the top-k re-ranked results

**Given** metadata filters are provided (from Story 4.5)
**When** the orchestrator runs
**Then** the filters are passed to the vector retriever for Qdrant metadata filtering
**And** BM25 results are post-filtered to match the same metadata criteria

**Given** the retrieval completes
**When** the `retrieval_completed` event is logged
**Then** it includes: `vector_count` (results from vector search), `bm25_count` (results from BM25), `reranked_count` (final top-k), `duration_ms`

### Story 4.5: Dynamic Metadata Extraction and Filtering (FR-010)

As an API consumer,
I want my queries automatically filtered by mentioned books, authors, or content types,
So that results are scoped to the specific content I'm asking about (FR-010).

**Acceptance Criteria:**

**Given** the vocabulary table is populated (by Epic 3)
**When** the application starts
**Then** the vocabulary (book titles, authors, content types) is loaded from PostgreSQL into memory for fast matching

**Given** a query containing a book title, author name, or content type reference
**When** the metadata extraction step runs (pre-retrieval in the query service)
**Then** fuzzy matching via `rapidfuzz` identifies the referenced metadata against the loaded vocabulary
**And** extraction accuracy meets >= 0.90 on a 10+ query test set (FR-010 target)

**Given** metadata is extracted from a query
**When** retrieval is invoked
**Then** Qdrant metadata filters are applied to scope results to matching books/authors/content types

**Given** a metadata-filtered query returns fewer than 3 results
**When** the fallback logic triggers
**Then** the query is re-run without metadata filters (unfiltered mode)
**And** the user receives results from the full corpus rather than an empty or sparse result set

**Given** a query with no identifiable metadata references
**When** the extraction step runs
**Then** no filters are applied and retrieval searches the full corpus

### Story 4.6: Query Service and LLM Generation (FR-005)

As an API consumer,
I want to submit a PLC question and receive a grounded, cited answer,
So that I get accurate, source-backed guidance from the PLC @ Work corpus (FR-005).

**Acceptance Criteria:**

**Given** an unambiguous, in-scope query is submitted
**When** the query service processes it
**Then** the pipeline executes in order: cache check → metadata extraction → hybrid retrieval → LLM generation → cache write
**And** a `query_received` event is logged at the start and `query_completed` at the end with `duration_ms`

**Given** the LLM generation step
**When** GPT-4o is called with retrieved context and the user's query
**Then** `store: false` is set on the request (FERPA mandatory)
**And** 2 retries with exponential backoff are configured (1s, 2s)
**And** on final failure, a `RetrievalError` is raised (resulting in 503 per global handler)
**And** `llm_request_sent` and `llm_response_received` events are logged

**Given** a successful LLM response
**When** the response is constructed
**Then** it includes: `status: "success"`, `conversation_id`, `answer` (the generated text), and `sources` (array of citations)
**And** each source citation includes: `book_title`, `sku`, `page_number`, `text_excerpt` (up to 200 characters)

**Given** no PII logging rules
**When** query processing occurs
**Then** the raw query text is never written to any log at any level (FERPA)

### Story 4.7: Response Cache Implementation

As an API consumer,
I want identical queries served from cache when available,
So that repeated questions get fast responses and OpenAI costs are reduced.

**Acceptance Criteria:**

**Given** the cache service skeleton from Epic 1 (Story 1.4)
**When** cache logic is implemented
**Then** `get_cached_response()` checks Redis for a cached response using key `cache:{sha256(normalized_query_text)}`
**And** `set_cached_response()` stores the response with a 24-hour TTL

**Given** a query that has been previously answered
**When** the same query is submitted again (after normalization: lowercase, whitespace-normalized)
**Then** the cached response is returned without invoking retrieval or LLM
**And** a `cache_hit` event is logged

**Given** a query with no cached response
**When** the cache check misses
**Then** the full pipeline runs (retrieval → LLM) and the response is cached
**And** a `cache_miss` event is logged

**Given** a response with `status: "needs_clarification"` or `status: "out_of_scope"`
**When** the cache write step runs
**Then** the response is NOT cached (only `status: "success"` responses are cached)

**Given** a request with `X-Request-Source: evaluation` header
**When** the query is processed
**Then** the cache is skipped entirely — no cache read and no cache write
**And** the `source` field in audit logs is set to `evaluation`

### Story 4.8: Query Route, Health Check Completion, and Startup Sequence (FR-020)

As an API consumer,
I want the query endpoint fully operational with complete health checks,
So that I can submit queries and operators can verify full system readiness (FR-005, FR-020 complete).

**Acceptance Criteria:**

**Given** the query route at `POST /api/v1/query`
**When** a request is submitted with a valid body (`query` string, optional `conversation_id`, optional `session_id`)
**Then** the route delegates to the query service and returns the response per PRD Section 5.3 schema
**And** no try/except exists in the route handler — exceptions bubble to the global handler

**Given** the Pydantic request model
**When** a request is missing the required `query` field
**Then** FastAPI returns a 422 validation error (Pydantic default format)

**Given** the Pydantic response models
**When** a response is serialized
**Then** the `status` field acts as the discriminator: `success` (with `answer`, `sources`), `needs_clarification` (with `clarification_question`, `session_id`), `out_of_scope` (with `message`)
**And** `exclude_none=True` ensures absent fields are omitted, not set to null

**Given** the health check endpoint (Story 1.7)
**When** it is updated in this story
**Then** it additionally checks: re-ranker model loaded in memory AND BM25 index loaded in memory
**And** hard dependencies: PostgreSQL (SELECT 1), Qdrant (collection info)
**And** soft dependency: Redis (PING — failure logged as warning, does not cause unhealthy status)
**And** readiness: re-ranker + BM25 loaded (failure = unhealthy / 503)

**Given** the FastAPI lifespan context manager
**When** the application starts
**Then** the startup sequence executes in order: load re-ranker model from disk → download and verify BM25 index from S3 → warm up connection pools (PostgreSQL, Redis, Qdrant) → load vocabulary table into memory
**And** the health endpoint returns 503 until all startup steps complete
**And** total startup time stays within 120 seconds (NFR-009)

---

## Epic 5: Conversational Query Intelligence

The API consumer gets intelligent query handling — ambiguous queries receive exactly one targeted clarifying question via session management, and out-of-scope queries receive a clear boundary signal.

### Story 5.1: Out-of-Scope Detection and Refusal (FR-009)

As an API consumer,
I want out-of-scope queries clearly refused with a standard message,
So that I understand the system's boundaries without confusion (FR-009).

**Acceptance Criteria:**

**Given** a query that is outside the PLC @ Work corpus domain (e.g., "What's the weather?", "Help me with calculus")
**When** the query service processes it
**Then** the response returns `status: "out_of_scope"` with the standard refusal `message` per PRD
**And** no retrieval or LLM generation is invoked (short-circuit)

**Given** the golden dataset contains labeled out-of-scope queries
**When** all out-of-scope queries are submitted
**Then** 100% receive the out-of-scope refusal response (FR-009 acceptance criterion)

**Given** an out-of-scope response
**When** the response is inspected
**Then** it includes `status: "out_of_scope"`, `conversation_id`, and `message`
**And** no `answer`, `sources`, `session_id`, or `clarification_question` fields are present (excluded via `exclude_none=True`)

**Given** out-of-scope detection logic
**When** it is implemented
**Then** it uses the LLM with a classification prompt (not rule-based pattern matching) to determine scope relevance against the PLC @ Work domain
**And** `store: false` is enforced on the classification call (FERPA)

### Story 5.2: Ambiguity Detection Logic (FR-007)

As an API consumer,
I want ambiguous queries identified so I can clarify my intent,
So that I receive accurate answers instead of misinterpreted ones (FR-007).

**Acceptance Criteria:**

**Given** a query that meets BOTH conditions of the two-part ambiguity test:
(a) answer would reference different books/chapters/concepts depending on interpretation, AND
(b) correct interpretation cannot be determined from query text alone
**When** the ambiguity detection runs
**Then** the query is classified as ambiguous with one of three categories: Topic Ambiguity, Scope Ambiguity, or Reference Ambiguity

**Given** a clear, unambiguous query
**When** the ambiguity detection runs
**Then** the query is classified as unambiguous and proceeds to retrieval

**Given** the labeled golden dataset subset containing ambiguous and unambiguous queries
**When** the ambiguity detection is evaluated
**Then** precision >= 0.80 (at least 80% of queries flagged as ambiguous are truly ambiguous)
**And** recall >= 0.70 (at least 70% of truly ambiguous queries are correctly detected)

**Given** ambiguity detection logic
**When** it is implemented
**Then** it uses the LLM with a classification prompt that evaluates both conditions of the two-part test
**And** `store: false` is enforced on the classification call (FERPA)
**And** the classification result includes the ambiguity category and a brief rationale (for debugging, not returned to user)

### Story 5.3: Session Service Implementation

As a developer,
I want the session service fully implemented with Redis persistence,
So that clarification flow state is maintained across the request-response cycle (building on Epic 1 skeleton).

**Acceptance Criteria:**

**Given** the session service skeleton from Epic 1 (Story 1.4)
**When** `create_session()` is called with original query context
**Then** a new session is created in Redis with key `session:{uuid4()}`, value containing the original query text and ambiguity classification
**And** the session TTL is set to 15 minutes (900 seconds)
**And** the generated `session_id` is returned

**Given** a valid, non-expired `session_id`
**When** `get_session()` is called
**Then** the original query context is returned from Redis
**And** a `session_resumed` event is logged

**Given** an expired or invalid `session_id`
**When** `get_session()` is called
**Then** Redis returns nil and the service raises `SessionExpiredError`
**And** the global handler returns 400 with `{"error": "Session expired or not found. Please resubmit your original query."}`
**And** a `session_expired` event is logged

**Given** a session is created
**When** 15 minutes pass without interaction
**Then** Redis automatically expires the key (TTL-based expiration)

### Story 5.4: Clarification Flow — Single Question Response (FR-006, FR-008)

As an API consumer,
I want to receive exactly one clarifying question for ambiguous queries and then get an answer,
So that I can refine my intent without a long back-and-forth (FR-006, FR-008).

**Acceptance Criteria:**

**Given** a query is classified as ambiguous (Story 5.2)
**When** the clarification flow triggers
**Then** the LLM generates a single targeted clarifying question based on the ambiguity category
**And** a session is created (Story 5.3) storing the original query context
**And** the response returns `status: "needs_clarification"` with `clarification_question`, `session_id`, and `conversation_id`
**And** a `clarification_issued` event is logged with `conversation_id` and `session_id`

**Given** a follow-up query with a valid `session_id`
**When** the query service processes it
**Then** the original query context is retrieved from the session
**And** the follow-up is combined with the original context for retrieval and LLM generation
**And** the response returns `status: "success"` with the answer and sources
**And** the session is deleted after successful response

**Given** a follow-up query with a valid `session_id` that is STILL ambiguous
**When** the query service processes it
**Then** the system does NOT issue a second clarifying question (FR-008: one-question hard limit)
**And** instead provides a best-interpretation answer with an interpretation statement appended (e.g., "I interpreted your question as...")
**And** the response returns `status: "success"`

**Given** any multi-turn session
**When** the session history is inspected
**Then** at most one `needs_clarification` response exists per session (FR-008 acceptance criterion: 100% of sessions contain at most one clarification)

**Given** `store: false` compliance
**When** any LLM call is made during clarification flow (question generation or answer generation)
**Then** `store: false` is set on the request (FERPA)

### Story 5.5: Query Router Integration

As a developer,
I want all query intelligence integrated into a single routing flow,
So that every query follows the correct path through scope check, session handling, ambiguity detection, and retrieval.

**Acceptance Criteria:**

**Given** a query is submitted to the query service
**When** the routing logic executes
**Then** the query follows this decision tree in order:
1. **Cache check** — if hit, return cached response (from Story 4.7)
2. **Session check** — if `session_id` present, resume clarification flow (Story 5.4)
3. **Scope check** — if out-of-scope, return refusal (Story 5.1)
4. **Ambiguity check** — if ambiguous, return clarification question (Story 5.2 + 5.4)
5. **Retrieval + generation** — proceed to hybrid retrieval and LLM answer (Story 4.6)

**Given** the routing logic
**When** a developer inspects the query service
**Then** each step is clearly separated and the decision tree is readable
**And** all logging events are emitted at the correct points: `query_received` at entry, `cache_hit`/`cache_miss` at cache step, `session_resumed`/`session_expired` at session step, `clarification_issued` at ambiguity step, `query_completed` at exit

**Given** the full pipeline is operational
**When** the test client (Story 1.8) is used
**Then** it correctly handles all three response types: displaying success answers with sources, showing clarification questions with a follow-up input, and displaying out-of-scope refusal messages

**Given** a follow-up query with `session_id`
**When** the cache check runs
**Then** session follow-ups bypass the cache (they are contextual and should not be cached)

---

## Epic 6: Quality Evaluation & Validation

The evaluator can measure RAG pipeline quality using RAGAS metrics, compare against a raw GPT-4o baseline, and collect A/B style preference data for answer tuning.

### Story 6.1: Golden Dataset and Evaluation Framework

As an evaluator,
I want a structured golden dataset and CLI evaluation framework,
So that I can systematically test the RAG pipeline against known questions and expected behaviors.

**Acceptance Criteria:**

**Given** the evaluation data directory at `tests/evaluation/data/`
**When** the golden dataset is inspected
**Then** `golden_dataset.json` contains test questions with the following structure per entry: `query` (string), `expected_answer` (string, for reference-based evaluation), `category` (one of: 'in_scope', 'ambiguous', 'out_of_scope'), `ambiguity_type` (nullable — 'topic', 'scope', 'reference' for ambiguous queries), `metadata_references` (nullable — expected book/author references for FR-010 testing)
**And** the dataset contains a minimum of 10 in-scope questions, 10 ambiguous questions (labeled with ambiguity type), and 5 out-of-scope questions

**Given** the evaluation CLI script at `tests/evaluation/`
**When** the evaluator runs `uv run python -m tests.evaluation.run`
**Then** the script submits each golden dataset query to `POST /api/v1/query` with `X-Request-Source: evaluation` header and `user_id: evaluation-pipeline`
**And** responses are collected and written to a local results file (JSON or CSV)

**Given** evaluation requests
**When** they are processed by the API
**Then** they skip the cache entirely (both read and write) per Story 4.7
**And** audit log entries include `source: evaluation` to distinguish from real usage

**Given** the evaluation framework
**When** a developer inspects its structure
**Then** it is a standalone CLI script, not part of the FastAPI application — it runs against a deployed API endpoint (staging or production)

### Story 6.2: RAGAS Reference-Free Evaluation (FR-014)

As an evaluator,
I want Faithfulness and Answer Relevancy scores for each golden dataset query,
So that I can measure RAG pipeline quality during development without ground-truth answers (FR-014).

**Acceptance Criteria:**

**Given** the evaluation pipeline is configured for reference-free mode
**When** the evaluator runs the RAGAS evaluation
**Then** per-query Faithfulness and Answer Relevancy scores are produced for all in-scope golden dataset questions
**And** results are written to a scored report file (JSON or CSV) with query identifier, scores, and response metadata

**Given** the RAGAS evaluation runs
**When** `store: false` compliance is checked
**Then** all OpenAI calls made by RAGAS use `store: false` (FERPA) — or the evaluator confirms RAGAS does not persist data to OpenAI

**Given** the scored report
**When** the evaluator reviews it
**Then** aggregate scores (mean Faithfulness, mean Answer Relevancy) are calculated and displayed
**And** queries with scores below configurable thresholds are flagged for investigation

**Given** this is the primary quality signal during Phase 0-B
**When** the evaluation completes
**Then** results provide actionable feedback on retrieval and generation quality without requiring ground-truth reference answers

### Story 6.3: RAGAS Reference-Based Evaluation (FR-015)

As an evaluator,
I want full RAGAS evaluation with Context Precision and Context Recall using the Concise Answers book as ground truth,
So that I can validate final quality with reference-based metrics (FR-015).

**Acceptance Criteria:**

**Given** the evaluation pipeline is configured for reference-based mode
**When** the evaluator runs the full RAGAS evaluation
**Then** per-query scores are produced for all four metrics: Faithfulness, Answer Relevancy, Context Precision, and Context Recall
**And** reference answers from the Concise Answers book content (already in the ingested corpus) are used as ground truth

**Given** the full evaluation results
**When** aggregate scores are calculated
**Then** they meet defined quality thresholds (thresholds documented in the evaluation config or golden dataset metadata)

**Given** the scored report
**When** the evaluator compares reference-free (FR-014) and reference-based (FR-015) results
**Then** both sets of scores are available in compatible formats for side-by-side comparison

### Story 6.4: Baseline Comparison — RAG vs. Raw GPT-4o (FR-016)

As an evaluator,
I want to compare RAG pipeline answers against raw GPT-4o answers on the same questions,
So that I can quantify the value the RAG pipeline adds over the LLM alone (FR-016).

**Acceptance Criteria:**

**Given** the golden dataset in-scope questions
**When** the baseline evaluation runs
**Then** each question is submitted to raw GPT-4o (no RAG context — direct chat completion) with `store: false` (FERPA)
**And** the same questions are submitted through the full RAG pipeline (or results from FR-014/FR-015 are reused)

**Given** both sets of responses
**When** RAGAS evaluation is run on the baseline responses
**Then** per-query and aggregate Faithfulness and Answer Relevancy scores are produced for the baseline

**Given** the comparison report
**When** the evaluator reviews it
**Then** the report includes per-query and aggregate scores for both RAG and baseline
**And** the RAG pipeline exceeds the baseline on Faithfulness and Answer Relevancy (FR-016 acceptance criterion)

**Given** the comparison report format
**When** it is generated
**Then** it clearly shows the delta (RAG score minus baseline score) per metric, making the value-add quantifiable

### Story 6.5: Retrieval Ablation Tests (FR-011, FR-013)

As an evaluator,
I want ablation tests proving that vector search and re-ranking each improve quality,
So that the hybrid retrieval architecture is justified by measurable evidence (FR-011, FR-013).

**Acceptance Criteria:**

**Given** the vector search ablation test (FR-011)
**When** the evaluator runs the pipeline in two modes: vector-only retrieval vs. full hybrid (vector + BM25 + re-ranker)
**Then** RAGAS scores (Faithfulness and/or Answer Relevancy) are compared
**And** the full hybrid pipeline shows a positive delta of at least 0.03 over vector-only on at least one metric

**Given** the re-ranking ablation test (FR-013)
**When** the evaluator runs the pipeline in two modes: without re-ranking vs. with re-ranking
**Then** RAGAS scores are compared
**And** the re-ranked pipeline shows a positive improvement of at least 0.05 on Faithfulness or Answer Relevancy

**Given** the ablation test results
**When** they are documented
**Then** a report includes: test configuration, per-query scores for each mode, aggregate deltas, and a conclusion on whether each component meets its minimum improvement threshold

**Given** the jargon/acronym recall test (FR-012 supporting evidence)
**When** a test set of PLC jargon queries is run
**Then** BM25 recall >= 0.80 for exact-term queries, demonstrating keyword search value

### Story 6.6: Style Preference Data Collection (FR-017)

As an evaluator,
I want to collect tester preferences between Book-Faithful and Coaching-Oriented answer styles,
So that the team can make data-driven decisions about answer tuning (FR-017, Phase 3 Track B).

**Acceptance Criteria:**

**Given** the golden dataset in-scope questions
**When** the style preference evaluation runs
**Then** each question is submitted twice with different system prompts: one for Book-Faithful style (direct quotes, close to source text) and one for Coaching-Oriented style (practical guidance, action-oriented)
**And** `store: false` is enforced on all LLM calls (FERPA)

**Given** both response styles are generated
**When** they are written to the preference log
**Then** the preference log CSV contains: query identifier, Book-Faithful response, Coaching-Oriented response, and empty fields for tester preference and notes

**Given** the preference log
**When** it is ready for review
**Then** each golden dataset in-scope query has both response styles recorded with all required fields (FR-017 acceptance criterion)

**Given** the preference log format
**When** testers manually review it
**Then** they can record their preference (Book-Faithful, Coaching-Oriented, or No Preference) and optional notes per query

### Story 6.7: Load Test — Concurrent User Verification (NFR-003)

As an operator,
I want to verify the system handles 5 concurrent users without degradation,
So that the API meets its concurrency target before production launch (NFR-003).

**Acceptance Criteria:**

**Given** the load test script at `tests/load/test_concurrency.py`
**When** the script is run against the staging API
**Then** 5 concurrent requests are submitted using Python `asyncio` + `httpx`
**And** the requests exercise the full pipeline including at least one clarification-flow session (must run after Epic 5 is complete)

**Given** the 5 concurrent requests complete
**When** results are evaluated
**Then** all 5 responses return HTTP 200 with valid response bodies
**And** all 5 responses complete within 30 seconds wall-clock time per request (NFR-001 P95 threshold)

**Given** the load test results
**When** an operator reviews them
**Then** a summary report shows: per-request duration, response status, and pass/fail against NFR-001 thresholds

**Given** the load test script
**When** it is inspected
**Then** it is a standalone script run manually against staging — not part of the CI pipeline
**And** it can be promoted to a GitHub Actions workflow post-MVP
