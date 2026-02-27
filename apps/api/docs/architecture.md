---
stepsCompleted: [1, 2, 3, 4]
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
13 FRs across 3 subsystems:
- **Ingestion Pipeline (FR-001–004):** Batch processing of 25 PLC books from S3 into Qdrant + PostgreSQL. Three-stage parsing: PyMuPDF (classification) → llmsherpa (structure) → GPT-4o Vision (landscape pages). Runs inside VPC via SSM, not part of the live API.
- **Query Engine (FR-005–010):** Single API endpoint with 3 response modes: direct answer, conditional clarification (1-question hard limit via Redis session), and out-of-scope refusal. Includes ambiguity detection and dynamic metadata filtering.
- **Hybrid Search & Re-Ranking (FR-011–013):** Dual retrieval (BM25 keyword + vector semantic) with cross-encoder re-ranking before LLM generation. Quality-critical path with ablation test requirements.

**Non-Functional Requirements:**
7 NFRs scoped for internal testing:
- Response time: 30s P95 (1-3 concurrent users)
- Availability: 95% uptime during business hours
- Concurrency: 5 simultaneous queries
- Encryption: TLS 1.2+ in transit, KMS at rest (no exceptions)
- Audit logs: 90-day retention, no PII even in debug mode
- Backup/Recovery: RTO 4h, RPO 24h
- Security scanning: Critical/high CVEs blocked before deployment

**Scale & Complexity:**

- Primary domain: API backend (Python/FastAPI RAG service on AWS)
- Complexity level: Medium
- Estimated architectural components: 8 (API service, Qdrant, RDS, ElastiCache, S3, ALB, NAT Gateway, ingestion pipeline)
- Long-term target: Enterprise-level, millions of users

### Technical Constraints & Dependencies

- **Technology stack pre-decided:** Python 3.11+/FastAPI, LlamaIndex, Qdrant (self-hosted EC2), PostgreSQL (RDS), Redis (ElastiCache), OpenAI GPT-4o + text-embedding-3-large, cross-encoder/ms-marco-MiniLM-L-6-v2 (in-process)
- **Single AZ deployment** for MVP simplicity
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
| Caching Strategy | **Redis: session + response cache** | — | Session storage required by PRD for clarification flow. Response caching (24h TTL) saves OpenAI costs on identical queries — common during QA and demos. | Session-only (misses easy cost savings), semantic cache (overkill for MVP) |
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
| CI/CD Pipeline | **GitHub Actions** | Already used for ingestion pipeline triggers (per PRD). Single automation platform. Pipeline: PR → ruff + mypy + pytest; merge to main → build Docker → push ECR → deploy Fargate. | AWS CodePipeline (clunkier, less community), GitLab CI/CircleCI (extra vendor) |
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
- **Scope boundary:** No auth UI, no session management display, no styling beyond functional layout. This is a test tool, not a product feature.
- **OpenAPI:** Not advertised in the auto-generated `/docs`

## Ingestion Pipeline Analysis

### NFR-008: Ingestion Duration (8-Hour Ceiling)

**Bottleneck Identification:** GPT-4o Vision calls for landscape pages are the primary time risk. Portrait page processing via PyMuPDF and llmsherpa is fast (seconds per book).

**Sizing Approach:** The corpus scan (FR-004) will produce landscape page counts per book. With N landscape pages and an estimated X seconds per Vision API call, total landscape processing time = N × X. This must be compared against the 8-hour ceiling after FR-004 completes. The first ingestion run will establish actual timings.

**Parallelism Decision:** If serial processing exceeds 8 hours, the ingestion container can run concurrent asyncio tasks for Vision API calls within the same SSM-triggered EC2 model. No additional infrastructure required — this is a code-level change, not an architecture change.

**Per-Book Failure Isolation:** NFR-008 specifies that individual book failures must not block remaining books. The ingestion pipeline must implement try/except per book with structured failure logging. A summary report at completion lists successful and failed books.

### NFR-009: Cold Start (120-Second Readiness)

**Model Packaging:** The cross-encoder re-ranker model weights (~90MB) must be **baked into the Docker image at build time**. The Dockerfile runs a pre-cache step during build that downloads the model from HuggingFace and stores it in the image layer. Downloading at runtime was rejected — it adds unpredictable latency and an external dependency failure mode during startup.

**Load Time Estimate:** Re-ranker loads from local disk in ~5–15 seconds on Fargate. Combined with FastAPI startup, dependency initialization, and connection pool warm-up, total startup is estimated at 30–60 seconds — well within the 120-second ceiling.

**Tradeoff Accepted:** ~90MB Docker image size increase. ECR pull from within the same region is faster and more reliable than downloading from HuggingFace over the public internet at every cold start.

### BM25 Index Lifecycle

**Build Timing:** The BM25 index is built **once after ingestion completes**, not on every container startup. A post-ingestion step serializes the index to a binary file and uploads it to S3 in the same private bucket as source PDFs.

**Container Startup:** At API startup, the container downloads the serialized BM25 index from S3 and loads it into memory. For a corpus of this scale, the serialized index is typically 10–50MB. S3 download within the VPC is well within the 120-second cold start budget.

**Index Staleness:** After re-ingestion, the pipeline must rebuild and re-upload the BM25 index. This is part of the ingestion completion criteria — ingestion is not "done" until both Qdrant and the BM25 index are updated.

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

- **Snapshot Schedule:** Daily automated snapshot via cron on the Qdrant EC2 instance using Qdrant's built-in snapshot API.
- **Storage:** S3 private bucket (same bucket as source PDFs).
- **Retention:** 7 days (matching RDS automated backup retention).
- **Recovery Procedure:** Restore from latest S3 snapshot. Snapshot restoration takes minutes — well within the 4-hour RTO.
- **Fallback:** If the snapshot is corrupted or missing, fall back to full re-ingestion (8-hour ceiling — exceeds RTO, escalate as incident).

## Known Risk: Content IP and Copyright

**Risk Statement:** The PLC @ Work books are proprietary Solution Tree IP. The RAG pipeline retrieves verbatim text chunks and the LLM may reproduce substantial portions in generated answers. The `text_excerpt` field in source citations adds an additional 200 characters of quoted text per source.

**MVP Mitigation:** Internal testers only — no output guardrail is required for MVP launch. The legal exposure is minimal with a closed testing group.

**Post-MVP Required Action — Before External User Rollout:**

At least one of the following must be implemented:
1. **Post-generation n-gram overlap check:** If the answer exceeds a threshold (e.g., >40% 5-gram overlap with source chunks), trigger a paraphrase retry before returning the response.
2. **Licensing review with Solution Tree:** Confirm that the intended use case (AI-generated answers citing and drawing from book content) is explicitly covered by the content license agreement.
3. **Both** (recommended for maximum protection).

**Contractual Dependency:** Confirm with Solution Tree whether internal testing use is explicitly covered by the existing content license. This is a business action item, not a technical one.
