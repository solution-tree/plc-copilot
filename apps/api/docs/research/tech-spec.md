# PLC Copilot — Technical Specification

**Document Purpose:** This Technical Specification defines **how** the MVP of the PLC Coach Service will be built. It is the engineering team's implementation guide. Product requirements — including what the system must do, acceptance criteria, and the decisions log — are documented in the companion PRD (v4.0).

**Author:** Nani | **Version:** 2.1 | **Date:** February 25, 2026

---

## Part 1: Background & Context

### The Problem

Educators implementing Professional Learning Communities need quick, accurate answers to specific PLC questions during their planning and collaboration work. They currently must manually search through 25 dense books from Solution Tree's PLC @ Work® series or rely on general-purpose chatbots that are not grounded in the specific PLC methodology.

### The MVP Goal

Build and validate a domain-specific RAG API that answers educator questions grounded in the 25-book PLC @ Work® corpus, with demonstrably better accuracy and citation quality than a general-purpose LLM.

### Scope

This document covers the ingestion pipeline, query pipeline, API contract, data schemas, infrastructure, and operational concerns for the MVP. It does not cover the UI, user authentication, conversational memory, or any Phase 2+ features.

---

## Part 2: System Architecture

### 2.1. Ingestion Pipeline (Batch Process — SSM-Triggered, VPC-Contained)

The ingestion pipeline is a one-time script, not a continuously running service. It is triggered manually via GitHub Actions, but **all content processing runs inside the VPC** via AWS Systems Manager (SSM) Run Command — not on GitHub's public runners. This upholds the project's security principle of never processing proprietary content on infrastructure outside direct organizational control, and establishes the correct pattern for future phases when FERPA-regulated data enters the pipeline.

**Why SSM and not GitHub Actions runners directly:** GitHub Actions public runners are shared, external infrastructure. Running the ingestion script there would mean proprietary book content (PDFs, parsed text, chunk text) passes through servers that are not audited by the team and not covered by any DPA. Even though the MVP corpus contains no student PII, this would contradict the stated security posture and set a dangerous precedent for Zone B/C data ingestion in future phases.

```
[25 PDF Books in S3]
        |
        v
[Stage 1: PyMuPDF — Page Classifier]
        |
        +---------------------------+
        |                           |
        v                           v
[Portrait pages               [Landscape pages]
 with text layer]                   |
        |                           v
        v                  [Stage 3: GPT-4o Vision
[Stage 2: llmsherpa            — Reproducible Describer]
 — Hierarchical Parser]             |
        |                           |
        +---------------------------+
                    |
                    v
        [Semantic Chunker + Metadata Tagger]
                    |
                    v
        [Embedding Model: text-embedding-3-large]
                    |
          +---------+---------+
          |                   |
          v                   v
  [Qdrant Vector DB]   [PostgreSQL Metadata DB]
```

### 2.2. Query Pipeline (Real-Time API Call)

```
[Incoming Request: query + user_id + conversation_id + optional session_id]
        |
        v
[Step 1: Pre-Retrieval LLM Router (GPT-4o)]
  — Classifies query as: go_to_rag | needs_clarification | out_of_scope
  — Extracts metadata filters: book_title, author, chunk_type
        |
        +-------------------+-------------------+
        |                   |                   |
        v                   v                   v
[out_of_scope]    [needs_clarification]    [go_to_rag]
        |                   |                   |
        v                   v                   v
[Return 200       [Create Redis session,  [Step 2: Hybrid Search]
 out_of_scope      return session_id]      (BM25 + Qdrant in parallel,
 response]                                  with metadata filters applied)
                                                |
                                                v
                                       [Step 3: Combine & Deduplicate]
                                                |
                                                v
                                       [Step 4: Re-ranker
                                        (top 20 → top 5)]
                                                |
                                                v
                                       [Step 5: Context Builder]
                                                |
                                                v
                                       [Step 6: Generation (GPT-4o)]
                                                |
                                                v
                                       [Return 200 success response]
```

---

## Part 3: Detailed Design

### 3.1. Query Pipeline — Step-by-Step Execution Order

The pipeline executes in the following strict order. This order is designed to avoid performing expensive retrieval work on queries that are out-of-scope or ambiguous.

**Step 1 — Pre-Retrieval LLM Router**

A single GPT-4o call is made before any retrieval. The prompt is engineered to act as a traffic cop, returning a structured JSON object with the following fields:

```python
class RouterOutput(TypedDict):
    route: Literal["go_to_rag", "needs_clarification", "out_of_scope"]
    clarification_question: Optional[str]   # Only present when route = needs_clarification
    metadata_filters: RouterFilters

class RouterFilters(TypedDict):
    book_title: Optional[str]
    author: Optional[str]
    chunk_type: Optional[Literal["reproducible"]]
```

The router prompt includes:
- A clear definition of the three routes
- The three ambiguity categories (topic, scope, reference) with examples
- Examples of in-scope and out-of-scope questions
- Instruction to extract metadata filters when present in the query

If `route = out_of_scope`: return the hard refusal response immediately. No retrieval is performed.

If `route = needs_clarification`: create a Redis session (see §3.5) and return the `needs_clarification` response. No retrieval is performed.

If `route = go_to_rag`: proceed to Step 2.

**Clarification Follow-Up Handling:** When a request arrives with a `session_id`, the pipeline skips the router. It loads the original query and metadata filters from Redis, combines the original query with the follow-up text into a single reconstructed query, and proceeds to Step 2.

If the `session_id` is not found in Redis (expired or invalid), return a `400 Bad Request` error.

**Handling a still-ambiguous follow-up:** The generation prompt (Step 6) is always informed whether the current request is a follow-up. When it is, the prompt instructs the model to assess whether the reconstructed query is still ambiguous. If so, the model must answer using its best interpretation and append the following statement to the end of the response: *"I interpreted your question as [interpretation]. If you meant something else, please ask again."* The system never asks a second clarifying question — this is enforced at the prompt level.

**Step 2 — Hybrid Search**

Run BM25 and Qdrant vector searches in parallel using `asyncio`. Apply any `metadata_filters` extracted in Step 1 to both searches.

- BM25: retrieve top 10 candidates from the in-memory BM25 index
- Qdrant: retrieve top 10 candidates using vector similarity, with payload filters applied

If a filtered search returns fewer than 3 results, automatically re-run without filters (fallback behavior).

**Step 3 — Combine & Deduplicate**

Merge the BM25 and Qdrant result sets. Deduplicate by `qdrant_id`. The combined candidate set should contain up to 20 unique chunks.

**Step 4 — Re-Rank**

Pass the combined candidate set to the `cross-encoder/ms-marco-MiniLM-L-6-v2` re-ranker. The re-ranker scores each candidate against the query and returns the top 5 by score.

**Step 5 — Context Builder**

Assemble the final prompt context from the top 5 re-ranked chunks. Each chunk is formatted with its source metadata (book title, page number) prepended, so the generation model can produce accurate citations.

**Step 6 — Generation**

Call GPT-4o with the assembled context and the user's query. The generation system prompt must include all of the following instructions:

1. **Answer only from context:** Base your answer solely on the provided context passages. Do not use knowledge outside the provided context.
2. **Cite sources with full detail:** Every factual claim must be cited. Citation format: `(Book Title, SKU: BKFXXX, p. XX)`. Include the exact SKU and page number from the source metadata.
3. **Admit insufficient context:** If the provided context does not contain enough information to answer the question confidently, respond with: *"The provided sources do not contain enough information to answer this question fully."* Do not hallucinate or speculate.
4. **Follow-up interpretation statement (follow-up requests only):** When the request is a clarification follow-up (indicated by a `is_followup: true` flag in the prompt), assess whether the reconstructed query is still ambiguous. If it is, append to the end of your answer: *"I interpreted your question as [your interpretation]. If you meant something else, please ask again."*

The `is_followup` flag is injected into the generation prompt by the pipeline when processing a request that arrived with a `session_id`.

Return the `success` response with the generated answer and the source citations.

---

### 3.2. Ingestion Pipeline — Detailed Steps

**Stage 1 — PyMuPDF Page Classifier**

For each PDF in S3:
1. Open the PDF with PyMuPDF
2. For each page, detect: orientation (portrait vs. landscape) and whether a text layer is present
3. Route each page to Stage 2 (portrait with text) or Stage 3 (landscape)
4. Flag pages that are portrait but have no text layer — these are scanned images and require manual review

**Stage 2 — llmsherpa Hierarchical Parser (Portrait Pages)**

`nlm-ingestor` runs as a local Docker container during the ingestion script:

```bash
docker run -p 5010:5010 ghcr.io/nlmatics/nlm-ingestor:latest
```

The llmsherpa Python client calls `nlm-ingestor` at `localhost:5010` to parse each portrait page. The parser returns a hierarchical document structure (sections, subsections, paragraphs, lists, tables).

**Chunking parameters for Stage 2:**
- Target chunk size: **512 tokens**
- Chunk overlap: **64 tokens**
- Parent context: Chapter and section names are stored in chunk **metadata** (not prepended to chunk text). This keeps embeddings clean and focused while preserving hierarchy for the re-ranker.

Each parsed chunk is mapped to a LlamaIndex `TextNode` with the full `MetadataSchema` (see §3.4).

**Stage 3 — GPT-4o Vision Reproducible Describer (Landscape Pages)**

For each landscape page:
1. Render the page as a PNG image using PyMuPDF
2. Call GPT-4o Vision with the image and a structured prompt requesting a detailed Markdown description of the reproducible's content, purpose, and any text present
3. The generated description becomes a single `TextNode` with `chunk_type = "reproducible"` — no splitting or overlap is applied

**Embedding & Storage**

After all pages are parsed and chunked:
1. Call `text-embedding-3-large` to generate a 3,072-dimension embedding for each `TextNode`
2. Store the embedding and payload in Qdrant (`plc_copilot_v1` collection)
3. Store the chunk metadata in PostgreSQL (`chunks` table)
4. Rebuild and serialize the BM25 index to disk (see §3.3)

---

### 3.3. BM25 Index — Build and Maintenance

The BM25 keyword search is handled by LlamaIndex's `BM25Retriever` running in the application layer. This avoids the scalability bottleneck of PostgreSQL's `ts_rank`, which must score every matching document before ranking.

**Index Build (at ingestion time):**
1. After all chunks are stored in PostgreSQL, the ingestion script loads all chunk records from the `chunks` table — including `id`, `qdrant_id`, and `text_content`
2. Each record is used to construct a LlamaIndex `TextNode` with the full `MetadataSchema` attached (including `qdrant_id` and `postgres_chunk_id`). **The index is built from `TextNode` objects, not raw text strings.** This ensures every BM25 result carries its `qdrant_id` and `postgres_chunk_id` for deduplication in Step 3 of the query pipeline.
3. A `BM25Retriever` index is built from these `TextNode` objects
4. The index is serialized to disk at a defined path (e.g., `/app/bm25_index/index.pkl`)
5. The serialized index file is stored in S3 alongside the PDFs for durability

**Index Load (at API container startup):**
1. The Fargate container downloads the serialized BM25 index from S3 on startup
2. The index is loaded into memory and held for the lifetime of the container
3. Estimated memory footprint for 25 books (~50,000–100,000 chunks): approximately 50–100 MB — well within the `1 vCPU / 2 GB` Fargate task size

**Index Refresh (when new books are added):**
1. Run the ingestion script for the new books
2. The script rebuilds the full BM25 index (all existing + new chunks) and uploads the new serialized file to S3
3. Trigger a new Fargate deployment to reload the updated index
4. Downtime during the deployment is acceptable for MVP (internal tool only)

---

### 3.4. Data Schemas

#### PostgreSQL Schema

**`books` table:**

```sql
CREATE TABLE books (
    id          SERIAL PRIMARY KEY,
    sku         VARCHAR(20) NOT NULL UNIQUE,
    title       TEXT NOT NULL,
    authors     TEXT[] NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**`chunks` table:**

```sql
CREATE TABLE chunks (
    id           SERIAL PRIMARY KEY,
    book_id      INTEGER NOT NULL REFERENCES books(id),
    qdrant_id    UUID NOT NULL UNIQUE,
    text_content TEXT NOT NULL,
    page_number  INTEGER NOT NULL,
    chunk_type   VARCHAR(20) NOT NULL
                   CHECK (chunk_type IN ('title','body_text','list','table','reproducible')),
    chapter      TEXT,
    section      TEXT,
    created_at   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_chunks_book_id ON chunks(book_id);
CREATE INDEX idx_chunks_qdrant_id ON chunks(qdrant_id);
```

> **Note:** No full-text search index is created on `text_content`. Keyword search is handled entirely by the application-layer BM25 index.

#### Qdrant Schema

- **Collection name:** `plc_copilot_v1`
- **Vector dimensions:** 3,072 (from `text-embedding-3-large`)
- **Distance metric:** Cosine

**Payload fields (stored with each vector for filtering):**

| Field | Type | Purpose |
|---|---|---|
| `book_sku` | string | Filter by specific book |
| `book_title` | string | Filter by book title (supports title-based queries) |
| `authors` | string[] | Filter by author name (supports author-based queries) |
| `chunk_type` | string | Filter for reproducibles specifically |
| `page_number` | integer | Returned in citations |
| `postgres_chunk_id` | integer | Foreign key back to PostgreSQL `chunks.id` |

#### Vector Node Metadata Schema (Python TypedDict)

```python
from typing import List, Literal, Optional, TypedDict

ChunkType = Literal["title", "body_text", "list", "table", "reproducible"]

class MetadataSchema(TypedDict):
    book_title: str
    authors: List[str]
    sku: str
    chapter: Optional[str]
    section: Optional[str]
    page_number: int
    chunk_type: ChunkType
    reproducible_id: Optional[str]
    postgres_chunk_id: int
```

---

### 3.5. Redis Session Schema

When the router returns `needs_clarification`, a Redis session is created to preserve the context needed for the follow-up.

**Key format:** `session:{session_id}` (where `session_id` is a server-generated UUID v4)

**Value (JSON-serialized):**

```json
{
  "original_query": "What does Learning by Doing say about assessment?",
  "clarification_question": "Are you asking about formative or summative assessment?",
  "metadata_filters": {
    "book_title": "Learning by Doing",
    "author": null,
    "chunk_type": null
  },
  "created_at": "2026-02-25T10:00:00Z"
}
```

**TTL (Time-to-Live):** 15 minutes. If the user does not submit a follow-up within 15 minutes, the session expires. A follow-up request with an expired `session_id` receives a `400 Bad Request` response with the message: *"Session expired or not found. Please resubmit your original query."*

**Why store the original query:** The follow-up message ("formative assessment") is not a standalone query. The pipeline must reconstruct the full context by combining the original query with the follow-up before performing retrieval.

**Why store the metadata filters:** Any filters extracted from the original query (e.g., the book title "Learning by Doing") should be preserved and applied to the follow-up retrieval, so the user does not need to repeat context they already provided.

---

### 3.6. API Contract

**Endpoint:** `POST /api/v1/query`

**Authentication:** Static API key passed in the `X-API-Key` request header. All requests without a valid key return `401 Unauthorized`.

**Request Schema (Pydantic model):**

```python
from pydantic import BaseModel, Field
from typing import Optional
import uuid

class QueryRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=2000)
    user_id: str = Field(..., min_length=1)
    conversation_id: str = Field(...)   # Expected to be a UUID v4 (client-generated). Logged as-is; not validated server-side for MVP.
    session_id: Optional[str] = None   # Only on clarification follow-ups
```

**Response Schema (Pydantic discriminated union):**

```python
from pydantic import BaseModel
from typing import List, Literal, Optional

class SourceCitation(BaseModel):
    book_title: str
    sku: str
    page_number: int
    text_excerpt: str   # First 200 characters of the source chunk

class SuccessResponse(BaseModel):
    status: Literal["success"]
    conversation_id: str
    session_id: Optional[str] = None   # Present only when resolving a clarification
    answer: str
    sources: List[SourceCitation]

class NeedsClarificationResponse(BaseModel):
    status: Literal["needs_clarification"]
    conversation_id: str
    session_id: str
    clarification_question: str

class OutOfScopeResponse(BaseModel):
    status: Literal["out_of_scope"]
    conversation_id: str
    message: str = "I can only answer questions based on the PLC @ Work® book series. This question falls outside that scope."

class ErrorResponse(BaseModel):
    error: str
```

**Error Response Table:**

| Scenario | HTTP Status | `error` value |
|---|---|---|
| Missing or invalid `X-API-Key` | `401` | `"Unauthorized"` |
| Malformed request body | `422` | FastAPI/Pydantic validation detail |
| Expired or invalid `session_id` | `400` | `"Session expired or not found. Please resubmit your original query."` |
| LLM or Qdrant service failure | `503` | `"The service is temporarily unavailable. Please try again."` |
| Unexpected internal error | `500` | `"An unexpected error occurred."` |

---

### 3.7. Audit Logging

All structured logs are written to CloudWatch as JSON. The following fields are captured for every API request:

```json
{
  "timestamp": "2026-02-25T10:00:00Z",
  "level": "INFO",
  "event": "query_processed",
  "user_id": "user-abc-123",
  "conversation_id": "conv-uuid-1234",
  "session_id": null,
  "route": "go_to_rag",
  "metadata_filters_applied": {"book_title": null, "author": null, "chunk_type": null},
  "retrieved_chunk_ids": ["uuid-1", "uuid-2", "uuid-3", "uuid-4", "uuid-5"],
  "status": "success",
  "latency_ms": 1240
}
```

**Log retention:** CloudWatch log group retention set to **90 days** for MVP.

**PII policy:** Logs must never capture the raw `query` text, `answer` text, or any student-identifiable content. The `user_id` field is a client-provided opaque string — it is logged as-is but must not be a real name or email address for MVP.

---

## Part 4: Infrastructure

### 4.1. AWS Architecture

**VPC Layout (single AZ for MVP):**

```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24)
│   ├── Application Load Balancer
│   └── NAT Gateway  ← required for private subnet egress to OpenAI API and AWS services
└── Private Subnet (10.0.2.0/24)
    ├── ECS Fargate (API container)
    ├── RDS PostgreSQL
    ├── ElastiCache Redis
    └── EC2 t4g.medium (Qdrant)
```

**NAT Gateway:** The NAT Gateway in the public subnet provides controlled outbound internet access for all resources in the private subnet. Without it, the Fargate task cannot reach the OpenAI API, and the EC2 Qdrant instance cannot reach AWS services. One NAT Gateway is sufficient for single-AZ MVP.

**Fargate Task Definition (MVP):**

- CPU: 1 vCPU
- Memory: 2 GB
- Containers: 1 (API + Re-ranker in-process)
- The `nlm-ingestor` container is **not** part of this task definition

**EC2 Qdrant Instance:**

- Instance type: `t4g.medium` (2 vCPU, 4 GB RAM)
- Storage: 30 GB gp3 EBS volume
- No public IP — accessible only from within the VPC private subnet
- **Protocol:** REST on port `6333`
- **Authentication:** Qdrant API key, loaded from `plc/qdrant-api-key` in Secrets Manager
- **Security group rule:** Inbound TCP port `6333` allowed from the Fargate task security group only. No other inbound rules.
- **Backup:** Daily EBS snapshots via AWS Data Lifecycle Manager, 7-day retention. If the instance fails, the volume can be restored from the latest snapshot. Re-ingestion is the fallback if no snapshot is available, but is expensive (all GPT-4o Vision + embedding calls).

**RDS PostgreSQL:**

- Instance class: `db.t3.micro` for MVP
- PostgreSQL version: 15+
- Multi-AZ: disabled for MVP (single AZ)
- Automated backups: enabled (7-day retention)

**ElastiCache Redis:**

- Node type: `cache.t3.micro`
- Redis version: 7+
- Cluster mode: disabled (single node for MVP)

### 4.2. IAM Roles

| Role | Attached To | Permissions |
|---|---|---|
| `plc-fargate-task-role` | Fargate task | Read from S3 (BM25 index), read from Secrets Manager, write to CloudWatch Logs |
| `plc-ingestion-role` | GitHub Actions OIDC | Read/write S3 (PDFs + BM25 index), `ssm:SendCommand` and `ssm:GetCommandInvocation` scoped to Qdrant EC2 instance, read from Secrets Manager |
| `plc-qdrant-ec2-role` | EC2 instance | `AmazonSSMManagedInstanceCore` (required for SSM Run Command), read/write S3 (PDFs + BM25 index), read from Secrets Manager (RDS credentials, Qdrant API key, OpenAI API key), write to CloudWatch Logs |

### 4.3. Secrets Manager

| Secret Name | Contents |
|---|---|
| `plc/openai-api-key` | OpenAI API key |
| `plc/static-api-key` | The static API key for `X-API-Key` authentication |
| `plc/rds-credentials` | PostgreSQL username and password |
| `plc/qdrant-api-key` | Qdrant collection API key |

### 4.4. CI/CD Pipeline (GitHub Actions)

**On push to `main`:**
1. Run `ruff` linter and `pytest` unit tests
2. Build Docker image for the API service
3. Tag and push image to Amazon ECR
4. Trigger a new ECS/Fargate service deployment

**Ingestion workflow (manual trigger — VPC-contained via SSM):**

The ingestion script runs entirely inside the VPC on the Qdrant EC2 instance using AWS Systems Manager (SSM) Run Command. GitHub Actions never touches the proprietary book content — it only sends a trigger.

1. GitHub Actions authenticates to AWS via OIDC
2. GitHub Actions uses the AWS CLI to issue an SSM Run Command targeting the Qdrant EC2 instance
3. SSM executes the ingestion script on the EC2 instance inside the private subnet:
   a. Start `nlm-ingestor` Docker container locally on the EC2 instance
   b. Pull PDFs from S3 into the EC2 instance
   c. Run the ingestion script — parse, chunk, embed, and write to Qdrant (localhost) and RDS (private subnet)
   d. Rebuild and upload the BM25 index to S3
   e. Stop the `nlm-ingestor` container
4. GitHub Actions polls SSM for command completion status
5. On success, GitHub Actions triggers a new Fargate deployment to reload the updated BM25 index

**Why SSM Run Command:** SSM requires no open inbound ports, no bastion host, and no VPN. The EC2 instance communicates outbound to the SSM endpoint via the NAT Gateway. GitHub Actions authenticates via OIDC and IAM — no long-lived credentials are stored. This is the AWS-native, zero-attack-surface approach to VPC access.

**IAM permissions required for SSM:**
- The `plc-qdrant-ec2-role` must include the `AmazonSSMManagedInstanceCore` managed policy
- The `plc-ingestion-role` (GitHub Actions OIDC) must include `ssm:SendCommand` and `ssm:GetCommandInvocation` permissions scoped to the Qdrant EC2 instance

---

### 4.5. Health Check Endpoint

The API must expose a `GET /health` endpoint that the ALB uses to determine whether the Fargate container is ready to receive traffic. The endpoint must not return `200 OK` until **both** of the following startup tasks are complete:

1. The BM25 index has been downloaded from S3 and loaded into memory
2. The re-ranker model weights (`cross-encoder/ms-marco-MiniLM-L-6-v2`) have been loaded into memory

During startup (before both are loaded), the endpoint returns `503 Service Unavailable`. Once both are loaded, it returns:

```json
{
  "status": "healthy",
  "bm25_index_loaded": true,
  "reranker_loaded": true
}
```

The ALB health check is configured with:
- **Path:** `GET /health`
- **Healthy threshold:** 2 consecutive successes
- **Unhealthy threshold:** 3 consecutive failures
- **Interval:** 30 seconds
- **Timeout:** 10 seconds

### 4.6. Database Migration Strategy

All PostgreSQL schema changes are managed using **Alembic**, the standard migration tool for SQLAlchemy/FastAPI projects.

- The initial migration creates the `books` and `chunks` tables as defined in §3.4
- All future schema changes must be implemented as Alembic migration scripts — never as manual SQL
- Migrations are run automatically as part of the Fargate container startup sequence, before the application begins serving traffic
- Migration scripts are version-controlled in the repository at `apps/api/alembic/versions/`

---

## Part 5: Testing & Validation

### 5.1. Software Testing

| Test Type | Scope | Tooling |
|---|---|---|
| Unit tests | Router logic, chunking logic, metadata extraction | `pytest` |
| Integration tests | Full pipeline end-to-end against a test corpus (3–5 books) | `pytest` + local Docker Compose |
| API contract tests | All three flows (success, clarification, out-of-scope) + all error responses | `pytest` + `httpx` |

### 5.2. RAG Evaluation Framework

**Tooling:** RAGAS

**Golden dataset:** 50–100 questions assembled from the scraped question bank, split into in-scope and out-of-scope categories.

**Passing thresholds (in-scope questions):**

| Metric | Threshold | Mode |
|---|---|---|
| Faithfulness | ≥ 0.80 | Reference-free (Phase 0-B) and reference-based (Phase 3) |
| Answer Relevancy | ≥ 0.75 | Reference-free (Phase 0-B) and reference-based (Phase 3) |
| Context Precision | ≥ 0.70 | Reference-based only (Phase 3) |
| Context Recall | ≥ 0.70 | Reference-based only (Phase 3) |

**Out-of-scope evaluation:** 100% of out-of-scope test questions must return the hard refusal response. Any hallucinated answer is an automatic failure.

---

## Part 6: Risks & Mitigation

| Risk ID | Risk | Mitigation |
|---|---|---|
| R-01 | Poor answer quality | RAGAS evaluation framework with defined thresholds; prompt engineering iteration |
| R-02 | High operational costs | Simplified single-AZ architecture; cost monitoring via AWS Cost Explorer |
| R-03 | Ineffective retrieval | Hybrid search + re-ranker; fallback to unfiltered search when filtered results are sparse |
| R-04 | BM25 index memory pressure | Monitor container memory; upgrade Fargate task size if index grows beyond 500 MB |
| R-05 | Redis session state loss on container restart | Acceptable for MVP (internal tool); sessions are short-lived (15 min TTL) |
| R-06 | llmsherpa parsing failures on unusual PDFs | Pre-build corpus scan flags problematic PDFs before ingestion begins |
| R-07 | Qdrant data loss (EBS volume failure) | Daily EBS snapshots with 7-day retention via AWS Data Lifecycle Manager. Re-ingestion is the fallback but is expensive. |

---

## Part 7: Alternatives Considered

| Component | Chosen Approach | Rejected Alternatives |
|---|---|---|
| Keyword search | LlamaIndex `BM25Retriever` (application layer) | PostgreSQL `ts_rank` — does not scale under concurrent load; must score all matching documents before ranking |
| PDF parsing | Hybrid: PyMuPDF + llmsherpa + GPT-4o Vision | `unstructured` — less specialized for hierarchical documents; `PyMuPDF` alone — requires too much custom code for structure extraction |
| Out-of-scope detection | Pre-retrieval LLM router | Post-retrieval similarity threshold — wastes retrieval compute on out-of-scope queries; generation-stage detection — even more expensive |
| Compute | ECS Fargate | AWS App Runner — not on AWS HIPAA-eligible services list; required for FERPA compliance posture |
| Architecture | Simplified single-service Fargate | Full microservices (4 separate Fargate services) — over-engineered for an internal MVP testing tool |
| Chunking | 512-token chunks with 64-token overlap | Fixed 256-token chunks — too small for PLC concepts that span paragraphs; 1024-token chunks — too large, reduces retrieval precision |

---

## Part 8: Future Considerations

| ID | Feature | Notes |
|---|---|---|
| F-01 | Conversational memory | Use `conversation_id` (already in every request/response) to retrieve prior exchanges from PostgreSQL and prepend to context |
| F-02 | Meeting transcript ingestion | Activate Zone B Terraform infrastructure; add de-identification pipeline |
| F-03 | Student data & tokenization | Activate Zone C Terraform infrastructure; implement tokenization service |
| F-04 | Multi-tenancy | Separate Qdrant collections and RDS schemas per school district |
| F-05 | Model fine-tuning | Fine-tune embedding model on PLC-specific vocabulary after sufficient usage data is collected |
| F-06 | User-facing analytics dashboard | Query volume, topic distribution, clarification rate, RAGAS score trends |
| F-07 | BM25 index hot-reload | Replace restart-based index refresh with a live reload mechanism to eliminate downtime when new books are added |

---

## Part 9: Appendices

### Appendix A: Glossary

| Term | Definition |
|---|---|
| **RAG** | Retrieval-Augmented Generation — a technique that grounds LLM responses in retrieved documents rather than relying solely on model weights |
| **BM25** | Best Match 25 — a probabilistic keyword ranking algorithm that scores documents by term frequency and inverse document frequency |
| **Hybrid Search** | A retrieval strategy that combines BM25 keyword search and vector semantic search, then merges and re-ranks the results |
| **Re-ranker** | A cross-encoder model that scores query-document pairs for relevance, used to re-order retrieval results before generation |
| **Chunk** | A segment of text extracted from a source document, stored as a unit for retrieval |
| **TextNode** | LlamaIndex's data structure for storing a chunk of text with its associated metadata |
| **Tenant Enclave** | The three-zone data segregation model (Content, Meeting, Identity) that provides FERPA-ready data isolation |
| **FERPA** | Family Educational Rights and Privacy Act — US federal law governing the privacy of student education records |
| **RAGAS** | Retrieval-Augmented Generation Assessment — an evaluation framework for measuring RAG system quality |
| **TTL** | Time-to-Live — the duration after which a cached value (e.g., a Redis session) automatically expires |

### Appendix B: Key Research Documents

The following documents in the `apps/api/docs/research/` directory informed the decisions in this specification. Note: several earlier research documents were deleted from the repository after their findings were incorporated into the PRD and this Tech Spec.

- `ferpa-FINAL.md` — FERPA compliance analysis (active)
- `tech-spec.md` — Original technical specification (superseded by this document v2.1)
- `MVP_Diagram.mermaid` — Architecture diagram (active)

### Appendix C: Corpus Books

The full list of 25 PLC @ Work® books is maintained in the repository at `apps/api/docs/corpus-books.md`.
