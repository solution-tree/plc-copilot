# PLC Coach Service — MVP Task List

**Source:** PRD v3 (`prd-v3.md`) | **Architecture:** `research/MVP_Diagram.mermaid`
**Rules:** `.claude/api-design.md`, `.claude/ingestion.md`, `.claude/security.md`

> Check off each item (`- [x]`) as it is completed.

---

## Stage 1: Foundation (Three Parallel Tracks)

These three tracks have **no dependencies on each other** and can be worked on simultaneously. All three must be complete before moving to Stage 2.

> **One caveat:** Track B (Corpus Scan) requires the S3 bucket to exist with the 25 PDFs uploaded. If the bucket doesn't exist yet, apply the S3 resource from Track A first (`terraform apply -target`), upload the PDFs, then continue both tracks in parallel.

```
Track A — Infrastructure (Terraform)    ──────────────────>  DONE
Track B — Pre-Build (Dataset + Scan)    ── S3 bucket* ────>  DONE
Track C — Project Foundation (Code)     ──────────────────>  DONE
                                               │
                                        Stage 2: CI/CD
                                               │
                                     Stage 3: Ingestion
                                               │
                                    Stage 4: Query Engine
                                               │
                                     Stage 5: Evaluation
                                               │
                                   Stage 6: Final Validation
```

---

### Track A: Infrastructure — Terraform (PRD §6, §6.1, §7)

All AWS resources defined in Infrastructure as Code. No manual console changes.
Reference: `terraform-infra-setup.md` for file-level implementation details.

#### A.1 Bootstrap (Manual, One-Time — before `terraform init`)

- [ ] Create S3 bucket `plc-copilot-terraform-state` (versioning enabled, encryption enabled, block public access)
- [ ] Create DynamoDB table `plc-copilot-terraform-locks` (partition key: `LockID`, type: String)

#### A.2 Terraform Project Setup

- [ ] Create `apps/api/terraform/` directory structure
- [ ] Create `backend.tf` — S3 backend + DynamoDB state lock
- [ ] Create `providers.tf` — AWS provider ~> 5.0, required versions, default tags
- [ ] Create `variables.tf` — all input variables with MVP defaults
- [ ] Create `locals.tf` — naming prefix, common tags
- [ ] Create `data.tf` — AZ lookup, AMI for Qdrant EC2
- [ ] Create `outputs.tf` — key outputs (CloudFront URL, ALB DNS, ECR URIs, RDS endpoint, Redis endpoint, Qdrant IP)
- [ ] Create `terraform.tfvars.example` — example values (no secrets)
- [ ] Add Terraform entries to `.gitignore`

#### A.3 Networking — VPC (PRD §6.1)

- [ ] Create `vpc.tf`:
  - [ ] VPC with CIDR block (`10.0.0.0/16`)
  - [ ] 6 subnets: public (2 AZs), private-app (2 AZs), private-data (2 AZs)
  - [ ] CIDR reservations for Zone B and Zone C as comments
  - [ ] Internet Gateway (for public subnets)
  - [ ] NAT Gateway (single for MVP, `single_nat_gateway` variable to toggle multi-AZ later)
  - [ ] Route tables for public and private subnets (data subnets have no NAT route)
- [ ] Create `vpc-endpoints.tf`:
  - [ ] S3 gateway endpoint (free, avoids NAT costs for S3 access)
  - [ ] Secrets Manager interface endpoint
- [ ] Create `vpc-flow-logs.tf`:
  - [ ] VPC flow logs to CloudWatch

#### A.4 Security Groups

- [ ] Create `security-groups.tf` — 7 security groups:

  | SG | Inbound From | Ports | Notes |
  |---|---|---|---|
  | `alb-sg` | CloudFront prefix list | 80 | ALB is HTTP-only; CloudFront handles HTTPS |
  | `api-sg` | `alb-sg` | 8000 | API containers |
  | `parser-sg` | `api-sg` | 5000 | Internal only |
  | `reranker-sg` | `api-sg` | 8080 | Internal only |
  | `rds-sg` | `api-sg`, `ingestion-sg` | 5432 | PostgreSQL |
  | `redis-sg` | `api-sg` | 6379 | Redis |
  | `qdrant-sg` | `api-sg`, `ingestion-sg` | 6333, 6334 | Qdrant HTTP + gRPC |

#### A.5 Encryption & Secrets (PRD §7.2)

- [ ] Create `kms.tf`:
  - [ ] Single customer-managed KMS key for all encryption (S3, RDS, EBS, ElastiCache, Secrets Manager, CloudWatch Logs)
  - [ ] Key policy with appropriate principal access
- [ ] Create `secrets.tf`:
  - [ ] Secrets Manager shells (no values in code, `ignore_changes` on secret versions):
    - OpenAI API key
    - RDS credentials
    - Redis auth token
    - App static API key
  - [ ] IAM policies granting each service access only to the secrets it needs

#### A.6 IAM Roles (PRD §7.1, §7.2)

- [ ] Create `iam.tf` — 6 IAM roles:
  - [ ] ECS execution role (shared, for pulling images + logging)
  - [ ] API task role (read Qdrant, read/write RDS, read/write ElastiCache, read Secrets Manager)
  - [ ] Ingestion task role (read S3, write Qdrant, write RDS, read Secrets Manager)
  - [ ] Parser task role (minimal — no external access)
  - [ ] Re-ranker task role (minimal — no external access)
  - [ ] Qdrant EC2 instance role (SSM access, CloudWatch logs)

#### A.7 Tenant Enclave Zone Boundaries (PRD §7.1)

- [ ] Define IAM roles and security group boundaries for Zone A (Content — active for MVP)
- [ ] Define IAM roles and security group boundaries for Zone B (Meetings — empty infrastructure)
- [ ] Define IAM roles and security group boundaries for Zone C (Identity — empty infrastructure)
- [ ] Document the zone isolation in Terraform comments for future developers

#### A.8 Storage

- [ ] Create `s3.tf` — 3 buckets:
  - [ ] Books bucket (source PDFs) — encrypted, versioned, block public access, restricted to Ingestion Worker IAM role
  - [ ] Logs bucket — for ALB/CloudFront access logs
  - [ ] Qdrant backups bucket
- [ ] Create `ecr.tf` — 4 ECR repositories:
  - [ ] `plc-copilot/api`
  - [ ] `plc-copilot/parser`
  - [ ] `plc-copilot/reranker`
  - [ ] `plc-copilot/ingestion`

#### A.9 Data Stores (PRD §6)

- [ ] Create `rds.tf`:
  - [ ] PostgreSQL 15+ RDS instance (`db.t3.micro`) in private-data subnets
  - [ ] Single-AZ for MVP (`rds_multi_az` variable for post-MVP toggle)
  - [ ] Encryption at rest with KMS
  - [ ] Automated backups (7-day retention)
- [ ] Create `elasticache.tf`:
  - [ ] Redis 7+ ElastiCache (`cache.t3.micro`) in private-data subnets
  - [ ] Encryption at rest with KMS
  - [ ] Encryption in transit enabled
- [ ] Create `ec2-qdrant.tf`:
  - [ ] EC2 instance (`t4g.medium` ARM) in private-data subnet
  - [ ] Encrypted EBS gp3 volume (50 GB) with KMS
  - [ ] User data script to install and start Qdrant
  - [ ] SSM access only — no SSH

#### A.10 Compute — ECS Fargate (PRD §6)

- [ ] Create `service-discovery.tf`:
  - [ ] Cloud Map private DNS namespace (`plc-copilot.local`)
  - [ ] Service discovery entries for parser and re-ranker
- [ ] Create `ecs.tf` — ECS cluster
- [ ] Create `ecs-api.tf`:
  - [ ] API task definition (FastAPI + Uvicorn)
  - [ ] API ECS service + ALB target group registration
- [ ] Create `ecs-parser.tf`:
  - [ ] Parser task definition (llmsherpa/nlm-ingestor)
  - [ ] Parser ECS service + Cloud Map service discovery (`parser.plc-copilot.local`)
- [ ] Create `ecs-reranker.tf`:
  - [ ] Re-ranker task definition (ms-marco-MiniLM-L-6-v2)
  - [ ] Re-ranker ECS service + Cloud Map service discovery (`reranker.plc-copilot.local`)
- [ ] Create `ecs-ingestion.tf`:
  - [ ] Ingestion worker task definition only (on-demand, not always-on)

#### A.11 Load Balancer & Edge (PRD §6.1)

- [ ] Create `alb.tf`:
  - [ ] Application Load Balancer in public subnets (HTTP-only — CloudFront handles HTTPS)
  - [ ] Target group pointing to API Fargate service
  - [ ] Health check path (`/health`)
- [ ] Create `cloudfront.tf`:
  - [ ] CloudFront distribution for HTTPS termination
  - [ ] Auto-generated `*.cloudfront.net` URL (no custom domain needed for MVP)
  - [ ] Origin = ALB
- [ ] Create `waf.tf`:
  - [ ] WAFv2 web ACL attached to CloudFront
  - [ ] AWS managed rules + rate limiting (`waf_rate_limit` = 1000)

#### A.12 Observability (PRD §6.1)

- [ ] Create `cloudwatch.tf`:
  - [ ] Log groups for each Fargate service
  - [ ] CloudWatch dashboard tracking: API Request Rate, Error Rate, P95 Latency, Cache Hit Rate
  - [ ] Metric alarms + SNS topic for alerts

#### A.13 Terraform Validation

- [ ] Run `terraform init` — succeeds with S3 backend
- [ ] Run `terraform validate` — all files syntactically valid
- [ ] Run `terraform plan` — shows ~60-80 resources, zero errors
- [ ] Review security groups, IAM policies, and encryption settings in plan output
- [ ] Confirm no secrets appear in any `.tf` file or state output
- [ ] Run `terraform apply` — all resources created
- [ ] Verify CloudFront distribution output shows `*.cloudfront.net` HTTPS URL
- [ ] Verify all services are accessible from within the VPC
- [ ] Verify no resources are publicly accessible except ALB/CloudFront

---

### Track B: Pre-Build (PRD §2.3, §9)

Everything in this track must be completed **before application coding begins** (PRD §2.3, §9).

#### B.1 Golden Dataset Assembly (PRD §2.3 — Phase 0-A)

- [x] Source real-world educator questions from the existing scraped question bank
- [x] Categorize each question as **In-Scope** (answerable from the 25 PLC books) or **Out-of-Scope** (outside the corpus)
- [x] Target 50–100 questions total across both categories
- [x] Define the expected behavior for each category:
  - In-Scope: grounded, cited answer
  - Out-of-Scope: hard refusal — *"I can only answer questions based on the PLC @ Work® book series. This question falls outside that scope."*
- [x] Structure the dataset as a JSON file (`tests/fixtures/golden_dataset.json`) with fields: `question`, `category`, `expected_answer` (null for now)
- [ ] Check the golden dataset into the repository

#### B.2 Pre-Build Corpus Scan (PRD §9)

> **Prerequisite:** S3 bucket must exist with the 25 PDFs uploaded (see Track A.8).

- [ ] Write the corpus scan script (`scripts/corpus_scan.py`) using PyMuPDF
- [ ] For each of the 25 PDFs, collect:
  - [ ] Total page count
  - [ ] Landscape page count
  - [ ] Text-layer presence per page (identify scanned/image-only pages)
  - [ ] Estimated chunk count
- [ ] Run the scan against all 25 PDFs in the S3 bucket
- [ ] Generate a summary report (markdown or CSV)
- [ ] Review report — flag any books with unexpected characteristics (e.g., high proportion of image-only pages)
- [ ] Document handling decisions for flagged books before proceeding
- [ ] Sign off: team review of the corpus scan report is complete

---

### Track C: Project Foundation

Set up the Python project, dependencies, Docker configuration, and local development environment.

#### C.1 Python Project Structure

- [ ] Create `apps/api/pyproject.toml` with project metadata and dependency groups
- [ ] Create `apps/api/requirements.txt` (or use pyproject.toml exclusively)
- [ ] Create `.gitignore` at the repo root (Python, Docker, Terraform, IDE, `.env`)
- [ ] Create `apps/api/.env.example` with placeholder keys (no real secrets)
- [ ] Scaffold the source directory structure:
  ```
  apps/api/src/
  ├── __init__.py
  ├── main.py
  ├── config.py
  ├── api/
  │   ├── __init__.py
  │   └── routers/
  │       ├── __init__.py
  │       └── query.py
  ├── core/
  │   └── __init__.py
  ├── ingestion/
  │   └── __init__.py
  ├── schemas/
  │   └── __init__.py
  ├── db/
  │   └── __init__.py
  └── utils/
      └── __init__.py
  ```

#### C.2 Core Dependencies

- [ ] Add FastAPI + Uvicorn
- [ ] Add Pydantic v2
- [ ] Add LlamaIndex (core + qdrant integration + OpenAI integration)
- [ ] Add OpenAI Python SDK
- [ ] Add SQLAlchemy + asyncpg (PostgreSQL async driver)
- [ ] Add redis / aioredis
- [ ] Add qdrant-client
- [ ] Add PyMuPDF (fitz)
- [ ] Add sentence-transformers (for re-ranker)
- [ ] Add boto3 (AWS SDK)
- [ ] Add RAGAS
- [ ] Add development dependencies: pytest, ruff, httpx (for test client), pytest-asyncio

#### C.3 Pydantic Schemas (PRD §5, `.claude/api-design.md`)

- [ ] Create `src/schemas/request.py` — `QueryRequest` model with `query`, `user_id`, `session_id` (optional)
- [ ] Create `src/schemas/response.py`:
  - [ ] `SourceCitation` model: `book_title`, `authors`, `sku`, `page_number`, `text_excerpt`
  - [ ] `SuccessResponse` model: `status="success"`, `answer`, `sources`, `session_id` (optional)
  - [ ] `ClarificationResponse` model: `status="needs_clarification"`, `session_id`, `clarification_question`
  - [ ] `OutOfScopeResponse` model: `status="out_of_scope"`, `message`
  - [ ] `QueryResponse` discriminated union of the above three
- [ ] Create `src/schemas/metadata.py` — `MetadataSchema` TypedDict matching PRD §4.3 exactly:
  - `book_title`, `authors`, `sku`, `chapter`, `section`, `page_number`, `chunk_type`, `reproducible_id`
  - `ChunkType = Literal["title", "body_text", "list", "table", "reproducible"]`

#### C.4 Configuration & Secrets Loading

- [ ] Create `src/config.py` — Pydantic Settings class loading from environment / AWS Secrets Manager
- [ ] Implement AWS Secrets Manager integration (`src/utils/secrets.py`) per `.claude/security.md`
- [ ] Ensure no secrets are hardcoded anywhere — all loaded at runtime

#### C.5 Docker Configuration

- [ ] Create `apps/api/Dockerfile` for the API service (FastAPI + Uvicorn)
- [ ] Create `apps/api/Dockerfile.reranker` for the re-ranker service (sentence-transformers model server)
- [ ] Create `apps/api/docker-compose.yml` for local development:
  - API service
  - PostgreSQL (local)
  - Redis (local)
  - Qdrant (local, using official Docker image)
- [ ] Verify `docker-compose up` starts all services and API responds to health check

#### C.6 FastAPI Application Shell

- [ ] Create `src/main.py` — FastAPI app with CORS, versioned router mount, health check endpoint
- [ ] Create `src/api/routers/query.py` — stub `POST /api/v1/query` that returns a placeholder response
- [ ] Add static API key middleware/dependency for endpoint protection (PRD §7.2)
- [ ] Verify the stub endpoint works: `curl -X POST localhost:8000/api/v1/query`

#### C.7 Database Setup

- [ ] Create `src/db/models.py` — SQLAlchemy ORM models for `books` and `chunks` tables (PRD §4.1)
- [ ] Create `src/db/session.py` — async database session management
- [ ] Set up Alembic for database migrations
- [ ] Write initial migration: create `books` and `chunks` tables
- [ ] Verify migration runs against local PostgreSQL

#### C.8 Structured Logging (PRD §6.1)

- [ ] Create `src/utils/logging.py` — structured JSON logging configuration
- [ ] Log fields: `user_id`, `retrieved_chunk_ids`, `latency_ms`, `was_cached` (per PRD §6.1)
- [ ] Ensure no PII (query text, answer text) is logged (per `.claude/security.md`: "No PII in Logs")
- [ ] Integrate logging into the FastAPI app

---

## Stage 2: CI/CD Pipeline (PRD §6.1)

> **Depends on:** Track A (ECR repos, ECS services) + Track C (Dockerfiles, application code to build)

### 2.1 Linting & Testing Workflow

- [ ] Create `.github/workflows/ci.yml`:
  - [ ] Trigger on push to `main` and on pull requests
  - [ ] Steps: checkout, setup Python 3.11, install dependencies, run `ruff check .`, run `pytest`
  - [ ] Report test results

### 2.2 Build & Deploy Workflow

- [ ] Create `.github/workflows/build-and-deploy.yml`:
  - [ ] Trigger on push to `main`
  - [ ] Steps:
    - [ ] Build Docker images for API, re-ranker, parser, ingestion worker
    - [ ] Tag images with commit SHA
    - [ ] Push images to Amazon ECR
    - [ ] Update ECS Fargate services to use new image
  - [ ] Use OIDC for AWS authentication (no long-lived keys)

### 2.3 Terraform Workflows

- [ ] Create `.github/workflows/terraform-plan.yml`:
  - [ ] Trigger on pull requests that change `apps/api/terraform/**`
  - [ ] Run `terraform plan` and post output as PR comment
- [ ] Create `.github/workflows/terraform-apply.yml`:
  - [ ] Trigger on merge to `main` for changes to `apps/api/terraform/**`
  - [ ] Run `terraform apply -auto-approve` (or require manual approval)

### 2.4 Evaluation Workflow

- [ ] Create `.github/workflows/evaluate.yml`:
  - [ ] Manual trigger (workflow_dispatch)
  - [ ] Run the RAGAS evaluation pipeline against the golden dataset
  - [ ] Output scores as a workflow summary / artifact

---

## Stage 3: Ingestion Pipeline (PRD §3.1, §4)

> **Depends on:** Track A (S3, Qdrant, RDS, Parser Fargate), Track B (corpus scan findings), Track C (application code)

### 3.1 S3 PDF Retrieval

- [ ] Create `src/utils/s3.py` — functions to list and download PDFs from the private S3 bucket
- [ ] Implement IAM-role-based authentication (no hardcoded credentials)

### 3.2 Page Classification with PyMuPDF (PRD §3.1 — Step 1)

- [ ] Create `src/ingestion/page_classifier.py`
- [ ] For each page in a PDF, detect:
  - [ ] Page orientation (portrait vs. landscape)
  - [ ] Whether a text layer is present
- [ ] Output: list of page objects with classification metadata

### 3.3 Portrait Page Parsing with llmsherpa (PRD §3.1 — Step 2)

- [ ] Create `src/ingestion/pdf_parser.py`
- [ ] Implement HTTP client to call the self-hosted llmsherpa/nlm-ingestor service
- [ ] Parse hierarchical structure: headings, sections, paragraphs, lists, tables
- [ ] Extract chapter and section names from document hierarchy
- [ ] Output: list of parsed text chunks with structural metadata

### 3.4 Landscape Page Processing with GPT-4o Vision (PRD §3.1 — Step 3)

- [ ] Create `src/ingestion/vision_processor.py`
- [ ] Render landscape pages as images (using PyMuPDF)
- [ ] Send images to GPT-4o Vision API
- [ ] Generate structured Markdown descriptions of reproducibles/worksheets
- [ ] Assign `chunk_type = "reproducible"` and generate `reproducible_id`
- [ ] Ensure OpenAI client uses zero-retention configuration

### 3.5 Chunking Strategy

- [ ] Create `src/ingestion/chunker.py`
- [ ] Implement chunking logic that respects document hierarchy from llmsherpa output
- [ ] Assign `chunk_type` to each chunk: `title`, `body_text`, `list`, `table`, `reproducible`
- [ ] Ensure each chunk has complete metadata conforming to `MetadataSchema` (PRD §4.3)
- [ ] Validate no required metadata fields are missing (except optional fields set to `None`)

### 3.6 Embedding Generation (PRD §6)

- [ ] Create `src/ingestion/embedder.py`
- [ ] Use `text-embedding-3-large` (3,072 dimensions) via OpenAI API
- [ ] Implement batched embedding calls for efficiency
- [ ] Enforce zero-retention on the OpenAI client

### 3.7 Vector Storage — Qdrant (PRD §4.2)

- [ ] Create `src/vector_store/qdrant_client.py`
- [ ] Create collection `plc_copilot_v1` with 3,072-dimension vectors
- [ ] Configure payload index fields: `book_sku`, `chunk_type`, `page_number`
- [ ] Implement upsert function: store vector + metadata payload per chunk
- [ ] Implement delete-by-book function (for re-ingestion)

### 3.8 Relational Storage — PostgreSQL (PRD §4.1)

- [ ] Implement functions to insert/update `books` table records
- [ ] Implement functions to insert `chunks` table records with `qdrant_id` cross-reference
- [ ] Ensure transactional consistency: if Qdrant upsert succeeds, PostgreSQL must also succeed

### 3.9 Pipeline Orchestration

- [ ] Create `src/ingestion/pipeline.py` — end-to-end orchestration:
  1. Fetch PDF from S3
  2. Classify pages with PyMuPDF
  3. Route portrait pages to llmsherpa, landscape pages to GPT-4o Vision
  4. Chunk parsed output
  5. Generate embeddings
  6. Store vectors in Qdrant
  7. Store metadata in PostgreSQL
- [ ] Implement idempotency: re-running for the same book replaces old data
- [ ] Add structured logging at each step (no PII)
- [ ] Create `scripts/run_ingestion.py` — CLI entry point: `python scripts/run_ingestion.py --book-sku <SKU>`

### 3.10 Ingestion Validation

- [ ] Ingest one test book end-to-end
- [ ] Verify vectors exist in Qdrant with correct metadata payloads
- [ ] Verify `books` and `chunks` records exist in PostgreSQL with correct cross-references
- [ ] Verify landscape pages were processed by Vision and stored as `reproducible` chunks
- [ ] Ingest all 25 books successfully
- [ ] Spot-check metadata quality across multiple books

---

## Stage 4: Query Engine & API (PRD §3.2, §3.3, §5)

> **Depends on:** Stage 3 (ingested data in Qdrant + PostgreSQL), Track A (Redis, Re-ranker, ALB)

### 4.1 Session Cache — Redis (PRD §6)

- [ ] Create `src/cache/session_cache.py`
- [ ] Implement session creation: generate UUID `session_id`, store original query + context
- [ ] Implement session retrieval: look up by `session_id`
- [ ] Set TTL on sessions (e.g., 15 minutes) to auto-expire stale clarification sessions
- [ ] Verify Redis connectivity and operations

### 4.2 Query Analysis — Ambiguity Detection (PRD §3.2)

- [ ] Create `src/core/query_analyzer.py`
- [ ] Implement GPT-4o call to analyze incoming query for:
  - [ ] **Ambiguity detection** using the two-part test (PRD §3.2):
    - (a) Answer would differ meaningfully depending on interpretation
    - (b) System cannot determine the correct interpretation from the query alone
  - [ ] Classify ambiguity type: Topic, Scope, or Reference (PRD §3.2 table)
  - [ ] Generate clarifying question if ambiguous
- [ ] Implement **out-of-scope detection**: determine if query falls outside the PLC @ Work® corpus
- [ ] Return classification: `clear`, `ambiguous`, or `out_of_scope`
- [ ] Enforce zero-retention on the OpenAI client

### 4.3 Dynamic Metadata Filtering (PRD §3.2)

- [ ] Extend query analysis to extract metadata filters from the query:
  - [ ] Book title references
  - [ ] Author references
  - [ ] Chunk type requests (e.g., "find a reproducible about...")
- [ ] Convert extracted filters to Qdrant filter conditions
- [ ] Implement fallback: if filtered search returns < 3 results, retry without filters

### 4.4 Hybrid Search — Semantic + Keyword (PRD §3.3)

- [ ] Create `src/core/retriever.py`
- [ ] **Semantic search**: embed the query with `text-embedding-3-large`, search Qdrant by vector similarity
- [ ] **Keyword search**: full-text search against `chunks.text_content` in PostgreSQL
- [ ] Combine results from both searches into a single candidate set
- [ ] De-duplicate candidates that appear in both result sets
- [ ] Apply dynamic metadata filters (from §4.3) to both searches

### 4.5 Re-Ranking (PRD §3.3)

- [ ] Create `src/core/reranker.py`
- [ ] Implement HTTP client to call the self-hosted `cross-encoder/ms-marco-MiniLM-L-6-v2` service
- [ ] Send (query, chunk_text) pairs to the re-ranker
- [ ] Re-order candidates by re-ranker score
- [ ] Select top-k chunks to pass to the answer generator

### 4.6 Answer Generation (PRD §3.2)

- [ ] Create `src/core/generator.py`
- [ ] Construct prompt with:
  - [ ] System instructions (PLC expert persona, grounding rules, citation requirements)
  - [ ] Retrieved context chunks (top-k from re-ranker)
  - [ ] User query (and clarification context if applicable)
- [ ] Call GPT-4o for answer generation
- [ ] Parse response to extract answer text and source citations
- [ ] Format source citations: `book_title`, `authors`, `sku`, `page_number`, `text_excerpt`
- [ ] Enforce zero-retention on the OpenAI client
- [ ] If second clarification follow-up is still ambiguous: answer with best interpretation and append interpretation statement (PRD §3.2: one-question hard limit)

### 4.7 Query Engine Orchestration

- [ ] Create `src/core/query_engine.py` — full query pipeline:
  1. Receive query + optional `session_id`
  2. If `session_id` present: retrieve session from Redis, combine with follow-up query
  3. Run query analysis (ambiguity + out-of-scope detection + metadata filter extraction)
  4. If out-of-scope → return `out_of_scope` response
  5. If ambiguous (and no prior clarification in this session) → store session in Redis, return `needs_clarification`
  6. If ambiguous (but already clarified once in this session) → proceed with best interpretation
  7. If clear → run hybrid search with metadata filters
  8. Re-rank results
  9. Generate answer
  10. Log audit record to PostgreSQL
  11. Return `success` response

### 4.8 API Endpoint Implementation (PRD §5)

- [ ] Implement `POST /api/v1/query` in `src/api/routers/query.py`:
  - [ ] Validate request body with `QueryRequest` Pydantic model
  - [ ] Call the query engine
  - [ ] Return the appropriate response type (`SuccessResponse`, `ClarificationResponse`, `OutOfScopeResponse`)
- [ ] Add static API key authentication (header-based)
- [ ] Add request/response logging (metadata only, no PII per security rules)
- [ ] Add error handling and appropriate HTTP status codes
- [ ] Add latency tracking

### 4.9 Query Engine Integration Tests

- [ ] Test Flow A — Direct Answer: clear query → `success` response with sources
- [ ] Test Flow B — Clarification: ambiguous query → `needs_clarification` → follow-up → `success`
- [ ] Test Flow C — Out-of-Scope: external question → `out_of_scope` response
- [ ] Test one-question hard limit: ambiguous → clarify → still ambiguous → answers with interpretation statement
- [ ] Test metadata filtering: query mentioning specific book → results from that book
- [ ] Test reproducible filtering: "find reproducibles about X" → `chunk_type=reproducible` results
- [ ] Test fallback: filtered search with < 3 results → automatic unfiltered retry
- [ ] Test session expiry: expired `session_id` → treated as new query

---

## Stage 5: Evaluation (PRD §2.3)

> **Depends on:** Stage 4 (working API), Track B (golden dataset)

### 5.1 RAGAS Pipeline Setup

- [ ] Create `scripts/evaluate.py`
- [ ] Integrate RAGAS library
- [ ] Load the golden dataset from `tests/fixtures/golden_dataset.json`
- [ ] Implement test harness: for each question, call `POST /api/v1/query` and capture response

### 5.2 Reference-Free Evaluation (PRD §2.3 — Phase 0-B)

- [ ] Run RAGAS in reference-free mode against **in-scope** questions:
  - [ ] **Faithfulness**: Is the answer grounded in the retrieved context?
  - [ ] **Answer Relevancy**: Does the answer address the question?
- [ ] Evaluate **out-of-scope** questions separately:
  - [ ] Verify the system returns the hard refusal response
  - [ ] No hallucination — system does not attempt to answer
- [ ] Generate evaluation report with per-question scores and aggregated metrics
- [ ] Establish baseline thresholds for pass/fail

### 5.3 Baseline Comparison

- [ ] Run the same in-scope questions against a general-purpose GPT-4o (no RAG)
- [ ] Compare Faithfulness and Relevancy scores: PLC Coach vs. baseline
- [ ] Document the delta to validate the core hypothesis (PRD §2.1)

### 5.4 Full Reference-Based Evaluation (PRD §2.3 — Phase 3)

- [ ] Obtain expert-authored reference answers for all in-scope questions
- [ ] Add reference answers to the golden dataset
- [ ] Re-run RAGAS in full reference-based mode, adding:
  - [ ] **Context Precision**: Are the retrieved chunks relevant?
  - [ ] **Context Recall**: Are all relevant chunks retrieved?
- [ ] Generate final quality benchmark report
- [ ] Validate that all metrics meet the defined thresholds

---

## Stage 6: Final Validation — Acceptance Criteria (PRD §8)

> **Depends on:** Everything. All stages must be complete.

Each item below maps to a specific acceptance criterion from PRD §8. All must pass.

### AC-1: Infrastructure Provisioned

- [ ] All infrastructure from Section 6 is live in AWS via Terraform
- [ ] Security group boundaries exist for all three Tenant Enclave zones (A, B, C)
- [ ] Zone A is populated; Zones B and C have infrastructure but are empty

### AC-2: CI/CD Pipeline Functional

- [ ] GitHub Actions workflow triggers on push to `main`
- [ ] Pipeline: lint → test → build Docker images → push to ECR → deploy to Fargate
- [ ] End-to-end deploy succeeds

### AC-3: Corpus Scan Complete

- [ ] Pre-build corpus scan has been run against all 25 PDFs
- [ ] Summary report has been reviewed and signed off
- [ ] Flagged books have documented handling decisions

### AC-4: Golden Dataset Assembled

- [ ] 50–100 questions assembled and categorized (in-scope + out-of-scope)
- [ ] Dataset checked into repository at `tests/fixtures/golden_dataset.json`

### AC-5: Ingestion Pipeline Functional

- [ ] Pipeline successfully processes all 25 source PDFs from S3
- [ ] Vectors stored in Qdrant with correct metadata
- [ ] Metadata stored in PostgreSQL with correct cross-references

### AC-6: API Endpoint Live

- [ ] `POST /api/v1/query` is accessible via a public URL (through CloudFront)
- [ ] Endpoint is protected by a static API key
- [ ] Unauthorized requests are rejected

### AC-7: Conditional Clarification Loop Works

- [ ] Clear queries return direct `success` response (no unnecessary clarification)
- [ ] Ambiguous queries return `needs_clarification` with `session_id`
- [ ] Follow-up with `session_id` returns `success` response
- [ ] Ambiguity triggers only on the two-part test (PRD §3.2)
- [ ] Broad queries with a single clear answer do NOT trigger clarification

### AC-7a: One-Question Hard Limit

- [ ] If clarification follow-up is still ambiguous, system answers with best interpretation
- [ ] System appends interpretation statement to the response
- [ ] System never asks more than one clarifying question per session

### AC-8: Out-of-Scope Detection Works

- [ ] Out-of-scope queries return `out_of_scope` status
- [ ] Response includes the exact refusal message from PRD §2.3
- [ ] System does not attempt to answer or hallucinate

### AC-9: RAGAS Evaluation Functional

- [ ] RAGAS pipeline runs against the golden dataset
- [ ] Produces Faithfulness and Answer Relevancy scores (reference-free mode)
- [ ] Scores are above defined thresholds

### AC-10: Source Citations Accurate

- [ ] In-scope query returns coherent, grounded answer
- [ ] Source citations include: `book_title`, `sku`, `page_number`, `text_excerpt`
- [ ] Citations are accurate and verifiable against the source material

### AC-11: Reproducible Filtering Works

- [ ] Query for reproducibles (e.g., "find reproducibles about assessment") uses `chunk_type` filter
- [ ] Results are derived from GPT-4o Vision–processed landscape pages
- [ ] Returned chunks have `chunk_type = "reproducible"`

---

## Quick Reference: Acceptance Criteria → Stage Mapping

| AC # | Description | Covered In |
|------|-------------|------------|
| 1 | Infrastructure provisioned via Terraform | Track A |
| 2 | CI/CD pipeline functional | Stage 2 |
| 3 | Corpus scan complete | Track B.2 |
| 4 | Golden dataset assembled | Track B.1 |
| 5 | Ingestion pipeline processes all 25 PDFs | Stage 3 |
| 6 | API endpoint live and protected | Stage 4.8 |
| 7 | Conditional clarification loop correct | Stage 4.7, 4.9 |
| 7a | One-question hard limit enforced | Stage 4.6, 4.7 |
| 8 | Out-of-scope detection works | Stage 4.2, 4.9 |
| 9 | RAGAS evaluation functional | Stage 5 |
| 10 | Source citations accurate | Stage 4.6, 4.9 |
| 11 | Reproducible filtering works | Stage 3.4, 4.3, 4.9 |
