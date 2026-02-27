---
stepsCompleted: [1, 2, 3, 4, 5, 6]
adversarialReviewsApplied: [round-1, round-2]
inputDocuments:
  - apps/api/docs/prd-v4.md
  - apps/api/docs/prd-v4-validation-report.md
  - apps/api/docs/research/ferpa-FINAL.md
workflowType: 'architecture'
project_name: 'plc-copilot'
user_name: 'Nani'
date: '2026-02-27'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Guiding Architectural Principle

**Scale-ready, not scale-built.** This MVP is the first phase of an enterprise-level application targeting millions of users. Every architectural decision must pass a dual test: (1) Does it avoid over-engineering the MVP? (2) Would scaling require only configuration changes and infrastructure provisioning — not a rewrite? When in doubt, choose patterns and abstractions that scale horizontally, but deploy the minimal instance for MVP.

### Requirements Overview

**Functional Requirements:**
21 FRs across 5 subsystems:
- **Ingestion Pipeline (FR-001–004):** Batch processing of 25 PLC books from S3 into Qdrant + PostgreSQL. Three-stage parsing: PyMuPDF (classification) → llmsherpa (structure) → GPT-4o Vision (landscape pages). Runs inside VPC via SSM, not part of the live API.
- **Query Engine (FR-005–010):** Single API endpoint with 3 response modes: direct answer, conditional clarification (1-question hard limit via Redis session), and out-of-scope refusal. Includes ambiguity detection and dynamic metadata filtering.
- **Hybrid Search & Re-Ranking (FR-011–013):** Dual retrieval (BM25 keyword + vector semantic) with cross-encoder re-ranking before LLM generation. Quality-critical path with ablation test requirements.
- **Evaluation Pipeline (FR-014–017):** Offline RAGAS evaluation — reference-free scoring, reference-based scoring against Concise Answers, baseline comparison vs. raw GPT-4o, and style preference data collection.
- **Operations & Security (FR-018–021):** API key authentication, structured audit logging (no PII), health check endpoint, and minimal test client for internal testers.

**Non-Functional Requirements:**
9 NFRs scoped for internal testing:
- Response time: 30s P95 (1-3 concurrent users)
- Availability: 95% uptime during business hours
- Concurrency: 5 simultaneous queries
- Encryption: TLS 1.2+ in transit, KMS at rest (no exceptions)
- Audit logs: 90-day retention, no PII even in debug mode
- Backup/Recovery: RTO 4h, RPO 24h
- Security scanning: Critical/high CVEs blocked before deployment
- Ingestion duration: 8-hour ceiling for full 25-book corpus
- Cold start tolerance: API container ready within 120 seconds

**Scale & Complexity:**

- Primary domain: API backend (Python/FastAPI RAG service on AWS)
- Complexity level: Medium
- Estimated architectural components: 8 (API service, Qdrant, RDS, ElastiCache, S3, ALB, NAT Gateway, ingestion pipeline)
- Long-term target: Enterprise-level, millions of users

### Technical Constraints & Dependencies

- **Technology stack pre-decided:** Python 3.11+/FastAPI, LlamaIndex, Qdrant (self-hosted EC2), PostgreSQL (RDS), Redis (ElastiCache), OpenAI GPT-4o + text-embedding-3-large, cross-encoder/ms-marco-MiniLM-L-6-v2 (in-process)
- **Single AZ deployment** for MVP simplicity. **Risk accepted:** A single-AZ failure causes 100% service downtime. NFR-002 allows 5% downtime during business hours (~13 hours/month). Historical AWS AZ incidents last 1–4 hours — one incident per month is within budget, but two incidents or one extended outage could breach the target. For internal testing with 1–3 users, brief AZ outages are tolerable and no SLA penalty exists. **Post-MVP action:** Before external users onboard, migrate to multi-AZ Fargate deployment and multi-AZ RDS.
- **HIPAA-eligible compute required** (Fargate, not App Runner)
- **External API dependency:** OpenAI (must have executed DPA with zero-retention)
- **VPC-contained ingestion:** Proprietary content never leaves VPC; ingestion triggered via GitHub Actions but executed via SSM Run Command on EC2
- **Ingestion is a separate workload** from the live API — runs as a Docker container only during batch processing

### Cross-Cutting Concerns Identified

- **FERPA compliance:** Shapes every data handling decision — self-hosted Qdrant, VPC-only ingestion, DPA requirements, no-PII audit logs, three-zone enclave model
- **Encryption:** Universal requirement — KMS at rest, TLS 1.2+ in transit, all data stores, all network communication
- **Audit logging:** Structured JSON logs for all key events, must never capture PII, 90-day retention
- **Secrets management:** All credentials and API keys in AWS Secrets Manager, IAM least-privilege for all service-to-service access
- **VPC networking:** Private subnets for all data stores and compute, public subnet for ALB only, NAT gateway for controlled egress
- **Observability:** CloudWatch log groups for Fargate service (basic for MVP); dashboards and distributed tracing deferred

## Starter Template Evaluation

### Primary Technology Domain

API backend (Python/FastAPI RAG service on AWS) based on project requirements analysis.

### Technical Tooling Decisions

| Category | Selection | Rationale | Alternatives Considered |
|---|---|---|---|
| Package Manager | **uv** | 10-100x faster than alternatives, handles Python version management, PEP 621 compliant `pyproject.toml`, single binary, native workspace support for future monorepo | Poetry (heavier, slower, better for PyPI publishing — not relevant here), PDM (good but smaller community momentum), pip (no lockfile, no dependency resolution) |
| Testing | **pytest** | Industry standard, native FastAPI `TestClient` integration, rich plugin ecosystem | unittest (more verbose, no fixture system), nose2 (smaller community) |
| Linting & Formatting | **ruff** | Replaces black + flake8 + isort + autoflake in a single Rust-based tool, current Python standard | black + flake8 + isort (3 separate tools, 3 configs), pylint (heavy, slow) |
| Type Checking | **mypy** | Standard Python type checker, strong Pydantic/FastAPI integration | pyright (also viable but mypy more established in Python ecosystem) |
| Pre-commit | **pre-commit** | Enforces ruff + mypy on every commit, prevents quality regressions | Manual enforcement (unreliable) |

### Starter Options Considered

| Starter | Evaluated | Verdict |
|---|---|---|
| fastapi-template-uv | Good tooling (uv + ruff + pytest) | Too generic — no RAG, no dual-store pattern |
| py-fastapi-starter | Clean modular architecture | No RAG patterns, wrong deployment model |
| fastapi-production-template | Docker + CI/CD included | Targets Render/Koyeb, not AWS Fargate |
| **Custom scaffold (uv init)** | Full control over structure | **Best fit for domain-specific requirements** |

### Selected Approach: Custom Scaffold via `uv init`

**Rationale:** No existing starter template addresses the project's specific requirements: LlamaIndex RAG orchestration, Qdrant + PostgreSQL dual storage, hybrid BM25/vector search, FERPA-compliant VPC architecture, and a separate ingestion pipeline workload. A custom scaffold avoids rip-and-replace overhead while adopting current best-practice tooling.

**Initialization Commands:**

```bash
uv init plc-copilot-api
cd plc-copilot-api
uv add fastapi pydantic uvicorn
uv add --dev pytest pytest-asyncio pytest-cov ruff mypy pre-commit
```

### Scale-Ready Enhancements (from ADR Review)

**uv Workspace Readiness:** The single-package `uv init` is MVP-appropriate. The `pyproject.toml` structure is natively workspace-compatible — when the project grows to include separate packages (e.g., `plc-copilot-ingestion`, `plc-copilot-eval`, `plc-copilot-shared`), uv workspaces can be enabled without migration. No action needed now; the pattern scales naturally.

**Async Test Infrastructure:** `pytest-asyncio` is included from day one because FastAPI is async. `pytest-cov` is included with a minimum coverage gate configured in CI from the first story. These are not optional for a production async service.

**Test Directory Structure:** The scaffold must establish a test directory structure that mirrors the application and supports the PRD's evaluation requirements:
- `tests/unit/` — Unit tests for individual components
- `tests/integration/` — Integration tests for component interactions (Qdrant, RDS, Redis)
- `tests/evaluation/` — Golden dataset evaluation pipeline, ablation tests (FR-011, FR-013), RAGAS scoring

**Retrieval Layer Abstraction (Forward Flag):** The retrieval mechanism (BM25 + vector + re-ranker) should be structured behind an abstraction that allows the implementation to be swapped without changing the query engine. This is an architectural decision for Step 4, flagged here because the project structure must accommodate it.

**Note:** Project initialization using these commands should be the first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- SQLAlchemy 2.0 + Alembic for database access and migrations
- Single Qdrant collection with rich metadata; retrieval abstraction layer is collection-aware from day one
- Redis for session storage + response caching (24h TTL)
- Terraform for infrastructure as code
- GitHub Actions for CI/CD pipeline

**Important Decisions (Shape Architecture):**
- API key authentication for MVP (swap to production auth system post-MVP)
- Two environments: staging + production
- CloudWatch logs + ALB health checks (per PRD Section 6.2)

**Deferred Decisions (Post-MVP):**
- Semantic caching in Redis (add when thousands of users generate similar queries)
- Production auth system — JWT or AWS Cognito (add when real teachers onboard)
- Third environment for development (add when team grows)
- Full observability stack — CloudWatch dashboards, metric alarms, email/Slack alerting, DataDog/Grafana with distributed tracing (add when external users onboard)
- Rate limiting — Redis-based, configurable threshold per API key (add when external users onboard; Redis infrastructure is already present)

### Data Architecture

| Decision | Selection | Version | Rationale | Alternatives Considered |
|---|---|---|---|---|
| ORM & Database Access | **SQLAlchemy 2.0 + Alembic** | SQLAlchemy 2.0.47, Alembic 1.18.4 | Industry standard, massive ecosystem, strong async support, AI agents produce reliable code with it. Alembic provides version-controlled schema migrations. | SQLModel (less mature ecosystem), asyncpg + raw SQL (no migration tooling) |
| Qdrant Collection Strategy | **Single collection, rich metadata** | — | Re-ranker handles quality sorting after retrieval; metadata filters (book, chapter, page type) provide precise targeting without multi-collection complexity. Retrieval abstraction layer is collection-aware from day one — adding collections for transcripts/workflows post-MVP is a config change, not a rewrite. | Multiple collections by content type (unnecessary complexity for single content type at MVP) |
| Caching Strategy | **Redis: session + response cache** | — | Session storage required by PRD for clarification flow. Response caching (24h TTL) saves OpenAI costs on identical queries — common during QA and demos. **Cache scope rule:** Only cache responses with `status: "success"`. Never cache `needs_clarification` responses (contain server-generated `session_id` bound to a specific session — caching would serve stale session references that always fail on follow-up). Never cache `out_of_scope` responses (lightweight, no LLM generation cost, no caching benefit). | Session-only (misses easy cost savings), semantic cache (overkill for MVP) |
| Migration Strategy | **Auto-generate + review gate** | — | Alembic auto-generates migration scripts from model changes; review step catches edge cases before applying. Scales to CI pipeline check post-MVP. | Hand-written (slower, error-prone), auto-generate without review (risky) |

### Authentication & Security

| Decision | Selection | Rationale | Alternatives Considered |
|---|---|---|---|
| API Authentication | **API key in request header** | MVP is internal testing with 1-3 users. API key provides authorization with near-zero implementation effort. Key stored in AWS Secrets Manager, passed via environment variable to Fargate. Auth logic sits behind an abstraction — swap to JWT/Cognito post-MVP without rewriting route handlers. | AWS IAM auth via ALB (overkill for MVP), JWT tokens (needs token issuer infrastructure) |

### API & Communication Patterns

| Decision | Selection | Rationale | Alternatives Considered |
|---|---|---|---|
| Error Handling | **PRD-specified flat JSON error bodies** | The PRD (Section 5.4) defines flat JSON error bodies with a single `error` string key for all error conditions. Simple, consistent with MVP's internal-tool scope, and defines an unambiguous contract. Specified errors: `401`: `{"error": "Unauthorized"}`, `400`: `{"error": "Session expired or not found. Please resubmit your original query."}`, `503`: `{"error": "The service is temporarily unavailable. Please try again."}`, `500`: `{"error": "An unexpected error occurred."}`, `422`: FastAPI/Pydantic default validation error format. | RFC 7807 Problem Details (deferred — appropriate when external consumers onboard) |
| Request/Response Contract | **PRD-specified flat response schema with status discriminator** | The PRD (Section 5.3) defines a flat response schema where `status` is the discriminator (`success`, `needs_clarification`, `out_of_scope`). Each status has defined fields: success includes `conversation_id`, `answer`, `sources`; needs_clarification includes `conversation_id`, `session_id`, `clarification_question`; out_of_scope includes `conversation_id`, `message`. Simple, requires no envelope unwrapping, documented with examples in the PRD. | Envelope pattern with `{status, data, meta}` wrapper (deferred — appropriate when cross-cutting metadata warrants a standardized outer structure) |
| API Documentation | **FastAPI auto-generated (OpenAPI/Swagger)** | Free with FastAPI — Pydantic models become the documentation. Interactive `/docs` endpoint for testers. Stays in sync with code automatically. | Separate documentation site (maintenance burden, gets out of sync) |

### Infrastructure & Deployment

| Decision | Selection | Rationale | Alternatives Considered |
|---|---|---|---|
| Infrastructure as Code | **Terraform** | Industry standard, largest IaC training data for AI agents, cloud-agnostic, explicit resource definitions. State stored in S3 with DynamoDB lock table. | AWS CDK Python (surprising abstractions, AWS-locked), CloudFormation (verbose YAML, slow), manual setup (not repeatable) |
| CI/CD Pipeline | **GitHub Actions** | Already used for ingestion pipeline triggers (per PRD). Single automation platform. Pipeline: PR → ruff + mypy + pytest; merge to main → build Docker → **Trivy scan (block on critical/high CVEs per NFR-007)** → push ECR → deploy Fargate. | AWS CodePipeline (clunkier, less community), GitLab CI/CircleCI (extra vendor) |
| Container Scanning (NFR-007) | **Trivy** | Open source, widely adopted, runs natively in GitHub Actions, scans Docker images for OS and language-level CVEs. Runs `trivy image --severity CRITICAL,HIGH --exit-code 1` after Docker build — non-zero exit code fails the pipeline and blocks ECR push. | ECR native scanning (asynchronous, requires polling — adds pipeline complexity), Grype/Anchore (viable but smaller community and fewer GitHub Actions examples) |
| Environment Strategy | **Two environments: staging + production** | Staging mirrors production for pre-release validation. Local Docker covers development. Terraform makes both environments identical configs with different variables. Third environment deferred until team grows. | Single environment (too risky), three environments (triple cost, overkill for MVP) |
| Observability | **CloudWatch log groups (Fargate service) + ALB health check** | CloudWatch log groups are built into Fargate — zero setup. ALB health check at `/health` provides availability signaling. Structured JSON audit logs (PRD Section 7.2) are emitted to the same CloudWatch log stream. Dashboards, metric alarms, and distributed tracing are explicitly deferred per PRD Section 6.2. | Full observability stack with dashboards and alerts (deferred to post-MVP per PRD) |

### Decision Impact Analysis

**Implementation Sequence:**
1. Terraform — VPC, RDS, ElastiCache, ECR, Fargate service, ALB, S3 (foundation for everything)
2. Project scaffold — uv init, SQLAlchemy models, Alembic setup, FastAPI app structure
3. Database schema — Initial Alembic migration for metadata and audit tables
4. Auth middleware — API key validation from Secrets Manager
5. Health endpoint — `/health` with database and Redis connectivity checks
6. Query endpoint — PRD flat response schema, PRD error bodies, Redis session/cache
7. Qdrant integration — Single collection, retrieval abstraction layer
8. CI/CD — GitHub Actions pipeline (lint → type check → test → build → deploy)
9. Observability — CloudWatch log group configuration and structured log format verification
10. Ingestion pipeline — Separate Docker workload, SSM-triggered

**Cross-Component Dependencies:**
- Session storage and response caching share the Redis instance — connection pooling configuration must be consistent
- Response schema follows PRD Section 5.3 (flat structure, status discriminator). Error bodies follow PRD Section 5.4 (flat `{"error": "..."}` format)
- Terraform must provision all infrastructure before CI/CD can deploy — bootstrap sequence required
- Health check endpoint must verify all downstream dependencies (RDS, Redis, Qdrant) to give ALB accurate signals

## Evaluation Pipeline Architecture

_Covers FR-014 (reference-free evaluation), FR-015 (reference-based evaluation), FR-016 (baseline comparison), FR-017 (style preference data collection)._

### Subsystem Description

The evaluation pipeline is a **separate offline workload** — not part of the live API container. It runs as a standalone Python CLI script invocable locally or via GitHub Actions. It is not a user-facing service.

### Execution Model

The evaluator runs the pipeline locally (or in CI) with access to the staging or production API endpoint. The pipeline submits golden dataset questions to `POST /api/v1/query`, collects responses, and passes them to RAGAS for scoring. No dedicated compute service is needed for MVP.

### Tool Decision

RAGAS library for metric computation. The evaluation scripts live in `tests/evaluation/` (matching the test directory structure already defined in the Starter Template Evaluation section).

### Data Inputs

- **Golden dataset:** Stored in the repository as JSON or CSV. Contains test questions, expected answers (for reference-based evaluation), and metadata.
- **FR-015 reference content:** The Concise Answers book content is already part of the ingested corpus — its chunks exist in Qdrant and PostgreSQL. No separate data pipeline needed.

### Outputs

Per-query scored report (JSON or CSV) written to a local directory. Not persisted to any data store for MVP.

### FR-017 Style Preference

A separate evaluation pass submitting each query twice with different system prompts (Book-Faithful and Coaching-Oriented). Both responses are written to a preference log CSV for manual review by the team.

### Forward Note

When evaluation grows beyond manual invocation (nightly runs, CI quality gates), it becomes a scheduled GitHub Actions workflow. The script structure supports this without modification — only the trigger changes.

## Minimal Test Client (FR-021)

| Decision | Selection | Rationale | Alternatives Considered |
|---|---|---|---|
| Test Client Technology | **Single static HTML file with inline CSS and vanilla JavaScript** | No framework, no build step, no additional infrastructure. Ships inside the same Docker container as the API. Serves the sole purpose of giving internal testers a browser-based way to submit queries. | React/Vue SPA (massive overkill for a single input field), Streamlit (adds Python dependency and a separate process) |

- **Serving:** FastAPI `StaticFiles` mount or a dedicated GET route at `/test-client`
- **Container:** Ships inside the API Docker image — zero additional infrastructure
- **Disclaimer:** FR-021 disclaimer banner text is hardcoded in the HTML
- **Scope boundary:** No auth *management* UI, no session management display, no styling beyond functional layout. This is a test tool, not a product feature.
- **API Key Handling:** The test client includes a text input field for the API key. The key is stored in the browser's `sessionStorage` for the duration of the tab and included in the `X-API-Key` header on every request. The key is never persisted to `localStorage` or cookies. Alternatives rejected: (1) Hardcoding the key in HTML — bakes a secret into the Docker image layer; (2) Exempting the test client from auth — creates a bypass that complicates middleware and could be exploited.
- **OpenAPI:** Not advertised in the auto-generated `/docs`

## Ingestion Pipeline Analysis

### NFR-008: Ingestion Duration (8-Hour Ceiling)

**Bottleneck Identification:** GPT-4o Vision calls for landscape pages are the primary time risk. Portrait page processing via PyMuPDF and llmsherpa is fast (seconds per book).

**Sizing Approach:** The corpus scan (FR-004) will produce landscape page counts per book. With N landscape pages and an estimated X seconds per Vision API call, total landscape processing time = N × X. This must be compared against the 8-hour ceiling after FR-004 completes. The first ingestion run will establish actual timings.

**Parallelism Decision:** If serial processing exceeds 8 hours, the ingestion container can run concurrent asyncio tasks for Vision API calls within the same SSM-triggered EC2 model. No additional infrastructure required — this is a code-level change, not an architecture change.

**Per-Book Failure Isolation:** NFR-008 specifies that individual book failures must not block remaining books. The ingestion pipeline must implement try/except per book with structured failure logging. A summary report at completion lists successful and failed books.

**Resource Contention Risk:** Ingestion runs via SSM Run Command on the same EC2 instance that hosts Qdrant. During an up-to-8-hour ingestion run, the ingestion container consumes CPU, memory, and disk I/O on the machine also serving vector search queries for the live API. **MVP mitigation:** Schedule ingestion runs during off-hours (evenings/weekends) when no testers are using the API — NFR-002 only requires 95% uptime during business hours (8 AM – 6 PM ET, weekdays). **Instance sizing:** The Qdrant EC2 instance must be sized for peak ingestion load, not just steady-state query serving — this is a Terraform variable decision. **Post-MVP action:** If corpus grows or ingestion frequency increases, move ingestion to a separate EC2 instance or Fargate task with network access to Qdrant's private IP.

### NFR-009: Cold Start (120-Second Readiness)

**Model Packaging:** The cross-encoder re-ranker model weights (~90MB) must be **baked into the Docker image at build time**. The Dockerfile runs a pre-cache step during build that downloads the model from HuggingFace and stores it in the image layer. Downloading at runtime was rejected — it adds unpredictable latency and an external dependency failure mode during startup.

**Load Time Estimate:** Re-ranker loads from local disk in ~5–15 seconds on Fargate. Combined with FastAPI startup, dependency initialization, and connection pool warm-up, total startup is estimated at 30–60 seconds — well within the 120-second ceiling.

**Tradeoff Accepted:** ~90MB Docker image size increase. ECR pull from within the same region is faster and more reliable than downloading from HuggingFace over the public internet at every cold start.

### BM25 Index Lifecycle

**Build Timing:** The BM25 index is built **once after ingestion completes**, not on every container startup. A post-ingestion step serializes the index to a binary file and uploads it to S3 in the same private bucket as source PDFs.

**Container Startup:** At API startup, the container downloads the serialized BM25 index from S3 and loads it into memory. For a corpus of this scale, the serialized index is typically 10–50MB. S3 download within the VPC is well within the 120-second cold start budget.

**Index Staleness:** After re-ingestion, the pipeline must rebuild and re-upload the BM25 index. This is part of the ingestion completion criteria — ingestion is not "done" until Qdrant is updated, BM25 index is uploaded to S3, AND a Qdrant snapshot is triggered and confirmed (see Qdrant Backup & Recovery section). The post-ingestion snapshot ensures the most recent corpus state is always backed up — without it, a Qdrant failure between ingestion completion and the next daily snapshot would lose the entire ingestion run.

**Alternative Rejected:** Building the BM25 index on every container startup was rejected because it adds unpredictable latency that grows with corpus size, violating the scale-ready principle.

## Health Check Specification (FR-020)

**Endpoint:** `GET /health`

**Dependency Checks:**
- PostgreSQL (RDS): execute `SELECT 1`
- Qdrant: execute collection info call
- Redis (ElastiCache): execute `PING`

**Readiness Checks:**
- Re-ranker model loaded in memory
- BM25 index loaded in memory

**Response Format:**
- Healthy: `200 OK` with `{"status": "healthy"}`
- Unhealthy: `503 Service Unavailable` with `{"status": "unhealthy", "failed": ["<dependency_name>"]}`

**ALB Configuration:**
- Health check path: `/health`
- Interval: 30 seconds
- Unhealthy threshold: 2 consecutive failures marks target unhealthy
- Healthy threshold: 2 consecutive successes marks target healthy

**Startup Behavior:** The `/health` endpoint returns `503` until all dependency checks pass AND both the re-ranker model and BM25 index are loaded. FastAPI's lifespan context manager handles the loading sequence. ALB will not route traffic to the container until health passes.

**Note on Redis:** Included as a health check dependency even though FR-020 doesn't list it explicitly, because session storage and response caching are hard dependencies of the query endpoint. A Redis failure means the clarification flow and caching are broken.

## Additional Data Architecture Decisions

### Redis Session TTL

**TTL Value:** 15 minutes. The clarification flow is synchronous — a teacher submits a query, reads the clarification question, and follows up within a single interaction. 15 minutes is generous for this flow and prevents stale sessions from accumulating in Redis.

**Key Structure:** `session:{session_id}` with serialized original query context as the value.

**Expiry Behavior:** When a follow-up arrives with an expired `session_id`, Redis GET returns nil, and the API returns `400 Bad Request` with `{"error": "Session expired or not found. Please resubmit your original query."}` per PRD Section 5.4.

**Distinct from Response Cache TTL:** The 24-hour response cache TTL is a separate concern. Session TTL governs the clarification loop; response cache TTL governs how long identical query results are reused.

### Qdrant Backup & Recovery (NFR-006 Reconciliation)

**Problem:** NFR-006 requires a 4-hour RTO for vector store recovery. The previously implied recovery strategy — re-running ingestion from S3 source PDFs — can take up to 8 hours (NFR-008). An 8-hour recovery process cannot satisfy a 4-hour RTO.

**Solution: Qdrant Native Snapshots**

- **Snapshot Schedule:** Daily automated snapshot via cron on the Qdrant EC2 instance using Qdrant's built-in snapshot API. Additionally, the ingestion pipeline triggers a snapshot immediately after successful completion (see BM25 Index Lifecycle — ingestion completion criteria).
- **Storage:** S3 private bucket (same bucket as source PDFs).
- **Retention:** 7 days (matching RDS automated backup retention).
- **Recovery Procedure:** Restore from latest S3 snapshot. Snapshot restoration takes minutes — well within the 4-hour RTO.
- **Fallback:** If the snapshot is corrupted or missing, fall back to full re-ingestion (8-hour ceiling — exceeds RTO, escalate as incident).

### Dynamic Metadata Extraction (FR-010)

**Approach:** Pre-LLM extraction step using fuzzy string matching against a known vocabulary table. The vocabulary consists of book titles, author names, and content type labels (e.g., "reproducible") stored in PostgreSQL and loaded into memory at API startup. The vocabulary is finite — 25 books, ~50 authors, 2–3 content types — so an LLM call is unnecessary for MVP.

**Module Location:** `services/query_service.py` — extraction happens during query pre-processing, before retrieval is invoked. If complexity grows, extract to a dedicated `services/metadata_extractor.py`.

**Matching Strategy:** Case-insensitive fuzzy matching (e.g., `rapidfuzz` or similar) against the vocabulary. Threshold tuned to meet FR-010's ≥ 0.90 extraction accuracy target on the evaluation dataset.

**Fallback (per PRD):** If fewer than 3 results match the extracted metadata filter, fall back to unfiltered retrieval. The user never sees an empty result set due to overly aggressive filtering.

**Forward Note:** If extraction accuracy falls below 0.90 during evaluation, consider upgrading to an LLM-based extraction step using the existing OpenAI integration. This would add one LLM call per query but handle novel phrasing better than string matching.

### BM25 Library Selection

**Selection:** `rank_bm25` — lightweight pure-Python BM25 implementation. Serialize index with `pickle` to a binary file for S3 storage and container startup loading.

**Rationale:** The BM25 index operates independently from LlamaIndex's retrieval pipeline. Keeping it as a standalone library avoids coupling keyword search to the LlamaIndex framework version. `rank_bm25` has a minimal API surface (fit corpus, get scores) which is all the retrieval abstraction layer needs.

**Alternative Considered:** LlamaIndex `BM25Retriever` — integrates with LlamaIndex's node/document model but introduces framework coupling. Since the retrieval abstraction layer already decouples implementations, framework integration provides no benefit.

**Serialization Note:** Pickle format requires matching Python versions for build and load. The Dockerfile pins the Python version, so this is handled. The `.pkl` file is uploaded to S3 alongside source PDFs and downloaded at container startup (see BM25 Index Lifecycle section).

### Embedding Model Versioning

**Version Pinning:** Use the explicit model ID `text-embedding-3-large` (OpenAI's current stable identifier). If OpenAI introduces versioned variants (e.g., `text-embedding-3-large-2026-01`), pin to the specific version in `core/config.py`.

**Version Recording:** Store the embedding model identifier as metadata in the Qdrant collection configuration (collection metadata field) and in the PostgreSQL `chunks` table (or a dedicated `ingestion_runs` table). This enables detection of version mismatch between stored vectors and the currently configured model.

**Mismatch Detection:** At API startup, compare the embedding model ID in app config against the model ID stored in Qdrant collection metadata. If mismatched, log an `ERROR`-level event and refuse to start — serving queries with incompatible embeddings silently degrades retrieval quality with no error signal.

**Re-Embedding Trigger:** If the embedding model changes, all existing vectors must be re-generated via a full re-ingestion. This uses the existing ingestion pipeline — no new infrastructure needed. The BM25 index is unaffected by embedding model changes.

## Known Risk: Content IP and Copyright

**Risk Statement:** The PLC @ Work books are proprietary Solution Tree IP. The RAG pipeline retrieves verbatim text chunks and the LLM may reproduce substantial portions in generated answers. The `text_excerpt` field in source citations adds an additional 200 characters of quoted text per source.

**MVP Mitigation:** Internal testers only — no output guardrail is required for MVP launch. The legal exposure is minimal with a closed testing group.

**Post-MVP Required Action — Before External User Rollout:**

At least one of the following must be implemented:
1. **Post-generation n-gram overlap check:** If the answer exceeds a threshold (e.g., >40% 5-gram overlap with source chunks), trigger a paraphrase retry before returning the response.
2. **Licensing review with Solution Tree:** Confirm that the intended use case (AI-generated answers citing and drawing from book content) is explicitly covered by the content license agreement.
3. **Both** (recommended for maximum protection).

**Contractual Dependency:** Confirm with Solution Tree whether internal testing use is explicitly covered by the existing content license. This is a business action item, not a technical one.

## Pre-Launch Compliance Checklist

_These are blocking items that must be verified before production deployment. They are business/legal actions, not code — each needs an owner and a completion date._

- [ ] **OpenAI DPA executed** — Data Processing Agreement with zero-retention clause confirmed and on file. Required by PRD Section 7.2 (third-party data processing).
- [ ] **Solution Tree content license reviewed** — Confirm internal testing use of PLC @ Work book content is explicitly covered by the existing license agreement (see Known Risk: Content IP and Copyright above).
- [ ] **NFR-007 vulnerability scan passing** — CI/CD pipeline Trivy scan step is operational and blocking on critical/high CVEs before any production deployment.

## Implementation Patterns & Consistency Rules

_These patterns ensure multiple AI agents write compatible, consistent code that works together seamlessly. Every pattern below is a binding rule — agents must follow these conventions without deviation._

### Pattern Categories Defined

**Critical Conflict Points Identified:** 5 categories where AI agents could make different choices — naming, structure, format, process, and communication. Each is resolved below.

### Naming Patterns

**Database Naming Conventions:**

| Pattern | Convention | Example |
|---|---|---|
| Table names | Lowercase plural `snake_case` | `books`, `chunks`, `audit_logs` |
| Column names | `snake_case` | `book_id`, `chapter_number`, `page_number` |
| Foreign keys | `{referenced_table_singular}_id` | `book_id` references `books.id` |
| Indexes | `ix_{table}_{column(s)}` | `ix_chunks_book_id` |
| Unique constraints | `uq_{table}_{column(s)}` | `uq_books_sku` |
| Alembic migrations | Auto-generated prefix + description | `001_initial_schema.py` |

**API Naming Conventions:**

| Pattern | Convention | Example |
|---|---|---|
| Endpoints | Lowercase `snake_case`, versioned | `/api/v1/query`, `/health` |
| JSON request fields | `snake_case` | `user_id`, `conversation_id`, `session_id` |
| JSON response fields | `snake_case` | `book_title`, `text_excerpt`, `clarification_question` |
| Query parameters (future) | `snake_case` | `?book_id=3` |
| Headers | Standard HTTP conventions | `X-API-Key`, `Content-Type` |

**Code Naming Conventions:**

| Pattern | Convention | Example |
|---|---|---|
| Modules/files | `snake_case` | `query_engine.py`, `retrieval_service.py` |
| Classes | `PascalCase` | `QueryRequest`, `ChunkMetadata` |
| Functions/methods | `snake_case` | `process_query()`, `build_bm25_index()` |
| Variables | `snake_case` | `session_ttl`, `reranker_model` |
| Constants | `UPPER_SNAKE_CASE` | `SESSION_TTL_SECONDS`, `MAX_SOURCES` |
| Pydantic models | `PascalCase` (class), `snake_case` (fields) | `class QueryResponse` with field `conversation_id` |

### Structure Patterns

**Project Organization: Layer-Based**

```
src/plc_copilot/
├── api/            # Route handlers
│   ├── routes/
│   └── middleware/
├── models/         # SQLAlchemy + Pydantic models
├── services/       # Business logic
├── repositories/   # Database access
├── retrieval/      # Qdrant, BM25, re-ranker
└── core/           # Config, logging, exceptions
```

Rationale: One primary endpoint, a separate ingestion pipeline, and a health check — not enough features to justify feature-based grouping. Layer-based structure gives agents zero ambiguity about where to put things. The retrieval layer gets its own folder because it is the most complex subsystem.

**Config & Environment Files:**

| Pattern | Location | Purpose |
|---|---|---|
| App config | `src/plc_copilot/core/config.py` | Pydantic `Settings` class, reads from env vars |
| `.env.example` | Project root | Template with all required env vars (no real values) |
| `.env` | Project root, **gitignored** | Local dev overrides only |
| `alembic.ini` | Project root | Alembic configuration |
| `alembic/` | Project root | Migration scripts directory |
| `pyproject.toml` | Project root | uv/project config, dependencies, tool settings (ruff, mypy, pytest) |

**Test Organization:**

```
tests/
├── unit/              # Mirrors src/ structure
├── integration/       # Tests against real services (RDS, Redis, Qdrant)
├── evaluation/        # RAGAS golden dataset pipeline
│   └── data/          # Golden dataset files (JSON or CSV)
├── load/              # Concurrency verification (NFR-003)
│   └── test_concurrency.py
└── conftest.py        # Shared fixtures
```

**Load Testing (NFR-003):**

NFR-003 requires verification via load test submitting 5 concurrent requests confirming all meet NFR-001's 30-second P95 threshold.

- **Tool:** Python `asyncio` + `httpx` in a standalone script. No need for Locust, k6, or other load testing frameworks for 5 concurrent requests.
- **Location:** `tests/load/test_concurrency.py`
- **Execution:** Run manually against staging before production deployment. Not part of the CI pipeline (requires a running API instance). Can be promoted to a GitHub Actions workflow post-MVP.
- **Pass criteria:** All 5 responses complete with HTTP 200 and wall-clock time under 30 seconds per response.

Rule: Unit tests mirror the source tree. If the source is `src/plc_copilot/services/query_service.py`, the test is `tests/unit/services/test_query_service.py`.

**Static Assets:**

| Pattern | Location | Purpose |
|---|---|---|
| Test client HTML | `src/plc_copilot/static/test_client.html` | FR-021 minimal test client |
| BM25 index (runtime) | Downloaded from S3 at startup | Not in repo |
| Golden dataset | `tests/evaluation/data/` | Test questions + expected answers |

**Files That Never Enter the Repo:**

- `.env` (real credentials)
- `*.pem`, `*.key` (certificates)
- Model weight files (baked into Docker image at build)
- BM25 serialized index (lives in S3)
- `__pycache__/`, `.mypy_cache/`, `.ruff_cache/`

### Format Patterns

**Date/Time Formats:**

| Context | Format | Example |
|---|---|---|
| API responses | ISO 8601 with UTC timezone | `2026-02-27T14:30:00Z` |
| Audit log timestamps | ISO 8601 with UTC timezone | `2026-02-27T14:30:00Z` |
| Database columns | PostgreSQL `TIMESTAMP WITH TIME ZONE` | Stored as UTC, SQLAlchemy handles conversion |
| Python code | `datetime.datetime` with `timezone.utc` | Never use naive datetimes |

Rule: **Everything is UTC, always.** No local timezone conversion anywhere in the backend.

**ID Formats:**

| ID Type | Format | Generator |
|---|---|---|
| `conversation_id` | String (UUID v4 recommended, not enforced) | Client-generated (per PRD). Server accepts as plain string without UUID validation — intentional technical debt per PRD Decision #9. |
| `session_id` | UUID v4 string | Server-generated (per PRD) |
| Database primary keys | Auto-incrementing integer | PostgreSQL `SERIAL` / SQLAlchemy default |
| `qdrant_id` | UUID v4 string | Generated during ingestion |
| `user_id` | Opaque string | Client-provided, not validated for MVP |

**Null Handling:**

| Rule | Example |
|---|---|
| Omit optional fields that are absent — don't send `null` | A `success` response has no `session_id` field at all, not `"session_id": null` |
| Pydantic `model_config` uses `exclude_none=True` for serialization | Enforced at the model level, not per-endpoint |
| Database nullable columns are fine where appropriate | `chunks.chapter_number` might be null for non-chapter content |

**Boolean Representation:** `true`/`false` in JSON (standard). No `1`/`0`, no `"yes"`/`"no"`.

### Process Patterns

**Error Handling:**

| Pattern | Rule |
|---|---|
| Custom exception hierarchy | Single base class `PLCCopilotError` in `core/exceptions.py`. Subclasses: `SessionExpiredError`, `QueryProcessingError`, `RetrievalError`, etc. |
| FastAPI exception handlers | Global handler via `app.exception_handler()` catches `PLCCopilotError` subclasses and maps to PRD error responses |
| Unhandled exceptions | Global catch-all returns `500` with `{"error": "An unexpected error occurred."}` — never leak stack traces |
| Third-party failures (OpenAI, Qdrant) | Catch at service layer, wrap in `PLCCopilotError` subclass, log original exception, return appropriate HTTP status |
| Validation errors | Let FastAPI/Pydantic handle `422` responses natively — don't override their format |

Principle: **Exceptions bubble up, get caught once at the top, and map to PRD error bodies.** No try/except scattered through route handlers.

**Logging:**

| Pattern | Rule |
|---|---|
| Library | Python stdlib `logging` module (no third-party logger) |
| Format | Structured JSON — one JSON object per log line |
| Required fields per log entry | `timestamp` (ISO 8601 UTC), `level`, `event`, `conversation_id` (when available), `user_id` (when in request context — required per PRD Section 7.2) |
| Forbidden fields | Any PII — no query text in production logs, no student names, no student-identifiable content (FERPA). Note: `user_id` is a required audit log field per PRD Section 7.2 — it is an opaque client-supplied string, not validated PII. |
| Log levels | `ERROR`: failures requiring attention. `WARNING`: degraded behavior. `INFO`: request lifecycle events. `DEBUG`: internal details, disabled in production |
| Where logging happens | Service layer and middleware. Not in route handlers. Not in Pydantic models. |
| Audit log events (PRD Section 7.2) | Emitted as `INFO`-level structured JSON with `event` field |

**Validation:**

| Pattern | Rule |
|---|---|
| Request validation | Pydantic models on FastAPI route signatures — automatic |
| Business rule validation | Service layer checks — raise `PLCCopilotError` subclass on failure |
| Database constraints | Enforce at schema level (not-null, foreign keys, unique) — don't duplicate in app code |
| Qdrant payloads | Validate during ingestion. At query time, trust what's in the store |

Rule: **Validate at system boundaries, trust internal data.**

**Retry Behavior:**

| Dependency | Retry? | Rule |
|---|---|---|
| OpenAI API | Yes | Max 2 retries with exponential backoff (1s, 2s). On final failure, return `503`. Use OpenAI SDK built-in retry config. |
| Qdrant | No | Single attempt. Health check handles availability. |
| PostgreSQL | No | Connection pool handles transient issues. Health check catches unreachable. |
| Redis | No | Cache reads degrade gracefully (skip cache). Session reads return `400` session expired. |

Principle: **Retry only external API calls with known transient failure modes.** For infrastructure dependencies, rely on health checks.

### Communication Patterns

**Log Event Naming:**

| Convention | Rule |
|---|---|
| Format | `snake_case` verb-noun |
| Prefix by subsystem | `query_*` for query engine, `ingestion_*` for pipeline, `health_*` for health checks |

**Defined Event Catalog:**

| Event Name | When Emitted | Level | Key Fields |
|---|---|---|---|
| `query_received` | Request hits query endpoint | INFO | `conversation_id`, `user_id`, `has_session_id` |
| `query_completed` | Response sent to client | INFO | `conversation_id`, `user_id`, `status`, `duration_ms` |
| `clarification_issued` | System returns `needs_clarification` | INFO | `conversation_id`, `session_id` |
| `session_resumed` | Follow-up with valid `session_id` | INFO | `conversation_id`, `session_id` |
| `session_expired` | Follow-up with expired/invalid `session_id` | WARNING | `conversation_id`, `session_id` |
| `retrieval_completed` | Hybrid search + re-ranking finished | INFO | `conversation_id`, `vector_count`, `bm25_count`, `reranked_count`, `duration_ms` |
| `llm_request_sent` | Call to OpenAI starts | DEBUG | `conversation_id`, `model` |
| `llm_response_received` | OpenAI response received | DEBUG | `conversation_id`, `token_count`, `duration_ms` |
| `llm_request_failed` | OpenAI call failed after retries | ERROR | `conversation_id`, `error_type`, `retry_count` |
| `cache_hit` | Response served from Redis cache | INFO | `conversation_id` |
| `cache_miss` | No cached response, proceeding to retrieval | DEBUG | `conversation_id` |
| `ingestion_started` | Ingestion pipeline begins | INFO | `book_count` |
| `ingestion_book_completed` | Single book processed | INFO | `book_sku`, `chunk_count`, `duration_ms` |
| `ingestion_book_failed` | Single book processing failed | ERROR | `book_sku`, `error_type` |
| `ingestion_completed` | Full pipeline finished | INFO | `books_succeeded`, `books_failed`, `total_duration_ms` |
| `health_check` | Health endpoint called | DEBUG | `status`, `failed_dependencies` |
| `auth_success` | Valid API key provided | DEBUG | — |
| `auth_failed` | Invalid API key provided | WARNING | `reason` ("invalid_key") |
| `auth_missing` | No API key in request | WARNING | `reason` ("missing_key") |

**Rules for Adding New Events:**
1. Follow the `subsystem_verb` or `subsystem_noun_verb` pattern
2. Never log PII — no query text, no user-identifiable content
3. Always include `conversation_id` when in request context
4. Add the event to this catalog in the architecture doc — don't invent undocumented events

### Enforcement Guidelines

**All AI Agents MUST:**

- Follow `snake_case` for all database, API, JSON, and Python naming (classes and constants excepted per PEP 8)
- Place code in the correct layer folder — no business logic in route handlers, no database calls in services
- Use the defined event catalog for all log emissions — no undocumented events
- Raise `PLCCopilotError` subclasses for all application errors — no raw HTTP exceptions in service code
- Omit `null` fields from JSON responses — use Pydantic `exclude_none=True`
- Use UTC for all timestamps — no naive datetimes, no local timezone conversion

**Pattern Enforcement:**
- Pre-commit hooks (ruff + mypy) catch naming and type violations
- Code review checks for correct layer placement and event catalog usage
- Any new log event must be added to the event catalog in this document before use

### Pattern Examples

**Good Examples:**

```python
# Correct: snake_case table, snake_case columns, proper FK naming
class Chunk(Base):
    __tablename__ = "chunks"
    id = Column(Integer, primary_key=True)
    book_id = Column(Integer, ForeignKey("books.id"), nullable=False)
    chapter_number = Column(Integer, nullable=True)

# Correct: exception raised in service, caught at top level
class SessionExpiredError(PLCCopilotError):
    status_code = 400
    error_message = "Session expired or not found. Please resubmit your original query."

# Correct: structured log event from the catalog
logger.info("query_completed", extra={
    "conversation_id": conversation_id,
    "status": "success",
    "duration_ms": elapsed,
})

# Correct: null fields omitted
# Response for success — no session_id field present
{"status": "success", "conversation_id": "conv-uuid", "answer": "...", "sources": [...]}
```

**Anti-Patterns:**

```python
# WRONG: camelCase column name
bookId = Column(Integer)  # Must be book_id

# WRONG: PascalCase table name
__tablename__ = "Chunks"  # Must be "chunks"

# WRONG: try/except in route handler
@router.post("/api/v1/query")
async def query(request: QueryRequest):
    try:
        result = await query_service.process(request)
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    # Should let exceptions bubble to global handler

# WRONG: null field included in response
{"status": "success", "conversation_id": "conv-uuid", "session_id": null}
# session_id should be omitted entirely

# WRONG: undocumented log event
logger.info("query_done")  # Not in event catalog — use "query_completed"

# WRONG: naive datetime
created_at = datetime.datetime.now()  # Must use datetime.datetime.now(datetime.timezone.utc)
```

## Project Structure & Boundaries

### Complete Project Directory Structure

```
plc-copilot-api/
├── pyproject.toml                  # uv config, dependencies, ruff/mypy/pytest settings
├── uv.lock                         # Lockfile (auto-generated)
├── .python-version                 # Python 3.11+ pin
├── .env.example                    # Template: all required env vars, no real values
├── .gitignore
├── .pre-commit-config.yaml         # ruff + mypy hooks
├── alembic.ini                     # Alembic configuration
├── Dockerfile                      # API service image (includes re-ranker model weights)
├── Dockerfile.ingestion            # Ingestion pipeline image
├── .github/
│   └── workflows/
│       ├── ci.yml                  # PR: ruff → mypy → pytest; merge: build → push ECR → deploy
│       └── ingestion.yml           # Manual/scheduled trigger → SSM Run Command
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/                   # Migration scripts
├── src/
│   └── plc_copilot/
│       ├── __init__.py
│       ├── main.py                 # FastAPI app entry point, lifespan manager
│       ├── api/
│       │   ├── __init__.py
│       │   ├── routes/
│       │   │   ├── __init__.py
│       │   │   ├── query.py        # POST /api/v1/query
│       │   │   └── health.py       # GET /health
│       │   └── middleware/
│       │       ├── __init__.py
│       │       └── auth.py         # API key validation
│       ├── models/
│       │   ├── __init__.py
│       │   ├── database.py         # SQLAlchemy Base, engine, session factory
│       │   ├── book.py             # Book SQLAlchemy model
│       │   ├── chunk.py            # Chunk SQLAlchemy model
│       │   ├── audit_log.py        # AuditLog SQLAlchemy model
│       │   └── schemas.py          # Pydantic request/response models
│       ├── services/
│       │   ├── __init__.py
│       │   ├── query_service.py    # Query orchestration, ambiguity detection
│       │   ├── session_service.py  # Redis session management (clarification loop)
│       │   └── cache_service.py    # Redis response caching
│       ├── repositories/
│       │   ├── __init__.py
│       │   ├── book_repository.py  # Book/chunk PostgreSQL access
│       │   └── audit_repository.py # Audit log PostgreSQL access
│       ├── retrieval/
│       │   ├── __init__.py
│       │   ├── base.py             # Retrieval abstraction interface
│       │   ├── vector.py           # Qdrant semantic search
│       │   ├── keyword.py          # BM25 keyword search
│       │   ├── reranker.py         # Cross-encoder re-ranking
│       │   └── hybrid.py           # Orchestrates vector + keyword + reranker
│       ├── core/
│       │   ├── __init__.py
│       │   ├── config.py           # Pydantic Settings, reads env vars
│       │   ├── logging.py          # Structured JSON log configuration
│       │   └── exceptions.py       # PLCCopilotError hierarchy
│       ├── ingestion/
│       │   ├── __init__.py
│       │   ├── __main__.py         # CLI entry point: python -m plc_copilot.ingestion
│       │   ├── pipeline.py         # Orchestrates full ingestion run
│       │   ├── parsers/
│       │   │   ├── __init__.py
│       │   │   ├── classifier.py   # PyMuPDF page classification
│       │   │   ├── structure.py    # llmsherpa structural parsing
│       │   │   └── vision.py       # GPT-4o Vision for landscape pages
│       │   └── loaders/
│       │       ├── __init__.py
│       │       ├── qdrant_loader.py    # Vector store writer
│       │       ├── postgres_loader.py  # Metadata store writer
│       │       └── bm25_builder.py     # BM25 index serialization + S3 upload
│       └── static/
│           └── test_client.html    # FR-021 minimal test client
├── tests/
│   ├── __init__.py
│   ├── conftest.py                 # Shared fixtures
│   ├── unit/
│   │   ├── __init__.py
│   │   ├── services/
│   │   │   └── test_query_service.py
│   │   ├── retrieval/
│   │   │   ├── test_vector.py
│   │   │   ├── test_keyword.py
│   │   │   └── test_hybrid.py
│   │   └── api/
│   │       └── routes/
│   │           └── test_query.py
│   ├── integration/
│   │   ├── __init__.py
│   │   ├── test_qdrant.py
│   │   ├── test_redis.py
│   │   └── test_postgres.py
│   ├── evaluation/
│   │   ├── __init__.py
│   │   ├── run_evaluation.py       # RAGAS evaluation CLI
│   │   ├── run_preference.py       # FR-017 style preference comparison
│   │   └── data/
│   │       └── golden_dataset.json # Test questions + expected answers
│   └── load/
│       └── test_concurrency.py     # NFR-003 concurrent request verification
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── providers.tf
    ├── backend.tf                  # S3 state + DynamoDB lock
    ├── modules/
    │   ├── vpc/                    # VPC, subnets, NAT gateway
    │   ├── rds/                    # PostgreSQL instance
    │   ├── elasticache/            # Redis cluster
    │   ├── qdrant/                 # EC2 instance + security groups
    │   ├── ecs/                    # Fargate service + ALB + ECR
    │   └── s3/                     # Source PDFs + BM25 index + Qdrant snapshots
    └── environments/
        ├── staging.tfvars
        └── production.tfvars
```

### Architectural Boundaries

**API Boundary:**

The only external-facing surface is the ALB, which routes to two endpoints:
- `POST /api/v1/query` — all query traffic, authenticated via `X-API-Key` header
- `GET /health` — unauthenticated, used by ALB health checks

Everything behind the ALB is in private subnets. No direct access to RDS, Redis, Qdrant, or the Fargate container from outside the VPC.

**Layer Boundaries (Call Direction):**

```
Routes → Services → Repositories (PostgreSQL)
                  → Retrieval (Qdrant, BM25, Re-ranker)
                  → Session/Cache (Redis)
```

Rules:
- Routes call services. Routes never call repositories or retrieval directly.
- Services orchestrate business logic. Services call repositories, retrieval, and Redis services.
- Repositories handle database queries only. They never call services or other repositories.
- Retrieval modules handle search and ranking only. They never call services or repositories.
- Core (config, logging, exceptions) is imported by all layers but never imports from them.

**Data Boundaries:**

| Data Store | Accessed By | Access Pattern |
|---|---|---|
| PostgreSQL (RDS) | `repositories/` only | SQLAlchemy async sessions via `models/database.py` |
| Qdrant | `retrieval/vector.py` (query), `ingestion/loaders/qdrant_loader.py` (write) | Qdrant Python client |
| Redis | `services/session_service.py`, `services/cache_service.py` | Redis async client via connection pool |
| S3 | `ingestion/loaders/bm25_builder.py` (write), `main.py` lifespan (read BM25 index) | boto3 S3 client |

**Ingestion Boundary:**

The ingestion pipeline (`ingestion/`) shares models and core config with the API but runs as a completely separate process. It is never imported by API code at runtime. The two workloads communicate only through shared data stores (PostgreSQL, Qdrant, S3).

### Requirements to Structure Mapping

| Requirement | Primary Location | Supporting Files |
|---|---|---|
| **FR-001–004** (Ingestion) | `ingestion/pipeline.py`, `ingestion/parsers/`, `ingestion/loaders/` | `models/book.py`, `models/chunk.py` |
| **FR-005–006** (Query + Clarification) | `api/routes/query.py`, `services/query_service.py`, `services/session_service.py` | `models/schemas.py` |
| **FR-007** (Ambiguity Detection) | `services/query_service.py` | — |
| **FR-008–009** (Response Modes) | `services/query_service.py` | `models/schemas.py` |
| **FR-010** (Metadata Filtering) | `retrieval/vector.py` | — |
| **FR-011–013** (Hybrid Search + Re-ranking) | `retrieval/hybrid.py`, `retrieval/vector.py`, `retrieval/keyword.py`, `retrieval/reranker.py` | `retrieval/base.py` |
| **FR-014–017** (Evaluation) | `tests/evaluation/` | — |
| **FR-019** (Audit Logging) | `core/logging.py`, `repositories/audit_repository.py` | `models/audit_log.py` |
| **FR-020** (Health Check) | `api/routes/health.py` | `main.py` (lifespan) |
| **FR-021** (Test Client) | `static/test_client.html` | — |

### Cross-Cutting Concerns Mapping

| Concern | Location |
|---|---|
| FERPA compliance | `core/logging.py` (PII filtering), `core/config.py` (secrets from env), `terraform/modules/vpc/` (network isolation) |
| Authentication | `api/middleware/auth.py` |
| Error handling | `core/exceptions.py` (hierarchy), `main.py` (global handler) |
| Configuration | `core/config.py` (single Pydantic `Settings` class) |
| Database access | `models/database.py` (engine/session), `repositories/` (all queries) |

### Integration Points

**Internal Communication:**

All internal communication is synchronous function calls within the same Python process. There is no message queue, event bus, or inter-service RPC. The call graph flows strictly downward through layers: routes → services → repositories/retrieval.

**External Integrations:**

| Integration | Protocol | Location | Error Handling |
|---|---|---|---|
| OpenAI GPT-4o | HTTPS (OpenAI SDK) | `services/query_service.py` | 2 retries with backoff, then `503` |
| OpenAI text-embedding-3-large | HTTPS (OpenAI SDK) | `retrieval/vector.py` (query), `ingestion/loaders/qdrant_loader.py` (ingest) | Same retry policy |
| GPT-4o Vision | HTTPS (OpenAI SDK) | `ingestion/parsers/vision.py` | Per-page retry, per-book failure isolation |

**Data Flow — Query Path:**

```
Client → ALB → auth middleware → query route → query_service
  → cache_service.get (Redis) → cache hit? return cached
  → retrieval/hybrid (Qdrant vector + BM25 keyword + re-ranker)
  → query_service (OpenAI LLM generation)
  → cache_service.set (Redis)
  → audit_repository.log (PostgreSQL)
  → query route → Client
```

**Data Flow — Ingestion Path:**

```
GitHub Actions → SSM Run Command → EC2 → Docker container
  → pipeline.py (orchestrator)
  → parsers/classifier.py (PyMuPDF page classification)
  → parsers/structure.py (llmsherpa structural parsing)
  → parsers/vision.py (GPT-4o Vision for landscape pages)
  → loaders/postgres_loader.py (metadata to RDS)
  → loaders/qdrant_loader.py (vectors to Qdrant)
  → loaders/bm25_builder.py (serialize index to S3)
```

### Development Workflow Integration

**Local Development:**
- `uv run uvicorn plc_copilot.main:app --reload` for the API
- `uv run python -m plc_copilot.ingestion` for ingestion pipeline
- `.env` for local configuration overrides
- `uv run pytest` for test execution
- `pre-commit run --all-files` for linting/type checks

**Build Process:**
- `Dockerfile` builds the API image: install dependencies → bake re-ranker model weights → copy source
- `Dockerfile.ingestion` builds the ingestion image: install dependencies → copy source (no model weights needed)
- Both images pushed to ECR by GitHub Actions CI

**Deployment:**
- Terraform provisions all infrastructure from `terraform/` directory
- `terraform/environments/staging.tfvars` and `production.tfvars` differentiate environments
- GitHub Actions deploys new API images to Fargate on merge to main
- Ingestion runs are triggered manually or by schedule via `ingestion.yml` workflow
