---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics]
inputDocuments:
  - apps/api/docs/prd.md
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
| FR-020 | Epic 1 + 4 | Health check (basic DB+Redis in E1, model readiness in E4) |
| FR-021 | Epic 1 | Minimal test client |

### NFR Coverage Map

| NFR | Epic | Description |
|---|---|---|
| NFR-001 | Epic 4 | Response time (30s p95) — verified via request duration logging |
| NFR-002 | Epic 2 | Availability (95% business hours) — ALB health check config |
| NFR-003 | Epic 6 | Concurrent users (5) — load test script |
| NFR-004 | Epic 2 | Data encryption (TLS 1.2+ / KMS) — Terraform config |
| NFR-005 | Epic 2 | Audit log retention (1 year: 90-day CloudWatch + S3 Glacier archival) |
| NFR-006 | Epic 2 + 3 | Backup & recovery (RDS backups in E2, Qdrant snapshots in E3) |
| NFR-007 | Epic 2 | Security scanning (Trivy in CI/CD) |
| NFR-008 | Epic 3 | Ingestion duration (8h ceiling) |
| NFR-009 | Epic 4 | Cold start tolerance (120s) — lifespan model loading |

## Epic List

### Epic 1: Project Scaffold & Core API
The developer can clone the repo, run `docker compose up`, and have a working local API skeleton with auth, health checks, audit logging, error handling, and a test client — ready for feature development.
**FRs covered:** FR-018, FR-019, FR-020 (basic), FR-021

### Epic 2: Infrastructure & CI/CD
The operator can deploy the API to AWS staging and promote to production through an automated, security-scanned pipeline.
**NFRs addressed:** NFR-002, NFR-004, NFR-005, NFR-007

### Epic 3: Content Ingestion Pipeline
The operator can ingest the full 25-book PLC @ Work corpus through a layout-aware parsing pipeline, producing richly-tagged, searchable chunks in the vector store and relational database.
**FRs covered:** FR-001, FR-002, FR-003, FR-004
**NFRs addressed:** NFR-006 (Qdrant snapshots), NFR-008

### Epic 4: RAG Query Engine
The API consumer can submit PLC @ Work questions and receive grounded, cited answers powered by hybrid retrieval, cross-encoder re-ranking, and metadata filtering.
**FRs covered:** FR-005, FR-010, FR-011, FR-012, FR-013
**NFRs addressed:** NFR-001, NFR-009

### Epic 5: Conversational Query Intelligence
The API consumer gets intelligent query handling — ambiguous queries receive exactly one targeted clarifying question via session management, and out-of-scope queries receive a clear boundary signal.
**FRs covered:** FR-006, FR-007, FR-008, FR-009

### Epic 6: Quality Evaluation & Validation
The evaluator can measure RAG pipeline quality using RAGAS metrics, compare against a raw GPT-4o baseline, and collect A/B style preference data for answer tuning.
**FRs covered:** FR-014, FR-015, FR-016, FR-017
**NFRs addressed:** NFR-003

### Dependency Flow

```
Epic 1 → Epic 2 → Epic 3 → Epic 4 → Epic 5
                                    → Epic 6 (parallel with Epic 5)
```
