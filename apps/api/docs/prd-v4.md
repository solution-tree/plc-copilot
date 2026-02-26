---
workflowType: 'prd'
workflow: 'edit'
classification:
  domain: 'edtech'
  projectType: 'api_backend'
  complexity: 'high'
inputDocuments:
  - apps/api/docs/research/ferpa-FINAL.md
stepsCompleted: ['step-e-01-discovery', 'step-e-02-review', 'step-e-03-edit']
lastEdited: '2026-02-26'
editHistory:
  - date: '2026-02-26'
    changes: 'General improvements based on validation report findings — FR reformatting, NFR section creation, implementation leakage cleanup, traceability gap closure'
---

# PRD: PLC Coach Service (MVP)

**Document Purpose:** This Product Requirements Document (PRD) defines **what** the MVP of the PLC Coach Service must do and **why** it matters. It is the source of truth for product decisions. Implementation details — including how components are built, the query pipeline execution order, chunking parameters, and infrastructure configuration — are documented in the companion Technical Specification.

**Author:** Nani | **Version:** 4.2 | **Date:** February 26, 2026

---

## Table of Contents

- [1. Vision & Strategic Context](#1-vision--strategic-context)
- [2. MVP Goals & Scope](#2-mvp-goals--scope)
  - [2.1. Key Goals](#21-key-goals)
  - [2.2. Non-Goals (Explicitly Out of Scope for MVP)](#22-non-goals-explicitly-out-of-scope-for-mvp)
  - [2.3. Evaluation Strategy](#23-evaluation-strategy)
- [3. Functional Requirements](#3-functional-requirements)
  - [3.1. Ingestion Pipeline](#31-ingestion-pipeline)
  - [3.2. Query Engine](#32-query-engine)
  - [3.3. Hybrid Search & Re-Ranking](#33-hybrid-search--re-ranking)
- [4. Non-Functional Requirements](#4-non-functional-requirements)
  - [4.1. Quality & Performance NFRs](#41-quality--performance-nfrs)
  - [4.2. Security & Operational NFRs](#42-security--operational-nfrs)
- [5. Data Models & Schema](#5-data-models--schema)
  - [5.1. PostgreSQL Schema](#51-postgresql-schema)
  - [5.2. Qdrant Schema](#52-qdrant-schema)
- [6. API Specification](#6-api-specification)
  - [6.1. Authentication](#61-authentication)
  - [6.2. Request Schema](#62-request-schema)
  - [6.3. Response Schema](#63-response-schema)
  - [6.4. Error Responses](#64-error-responses)
  - [6.5. Rate Limiting](#65-rate-limiting)
  - [6.6. API Documentation](#66-api-documentation)
  - [6.7. Flow A — Direct Answer](#67-flow-a--direct-answer)
  - [6.8. Flow B — Conditional Clarification](#68-flow-b--conditional-clarification)
  - [6.9. Flow C — Out-of-Scope Query](#69-flow-c--out-of-scope-query)
  - [6.10. Flow D — Metadata-Filtered Query](#610-flow-d--metadata-filtered-query)
- [7. Architecture & Technology Stack](#7-architecture--technology-stack)
  - [7.1. DevOps & Infrastructure](#71-devops--infrastructure)
- [8. Security & Compliance: The Tenant Enclave Foundation](#8-security--compliance-the-tenant-enclave-foundation)
  - [8.1. The Three-Zone Tenant Enclave Model](#81-the-three-zone-tenant-enclave-model)
  - [8.2. Core Security Controls](#82-core-security-controls)
- [9. Acceptance Criteria](#9-acceptance-criteria)
- [10. Pre-Build Corpus Analysis](#10-pre-build-corpus-analysis)
  - [10.1. Scan Requirements](#101-scan-requirements)
  - [10.2. Definition of Done](#102-definition-of-done)
- [11. Key Decisions Log](#11-key-decisions-log)

---

## 1. Vision & Strategic Context

The PLC Coach Service is an AI-powered assistant designed to provide educators with immediate, expert guidance grounded in the principles of Professional Learning Communities (PLCs). The core business problem is that educators lack convenient access to specific, actionable answers within the dense corpus of Solution Tree's PLC @ Work® series. This service bridges that gap by providing a conversational API to a curated library of PLC books, delivering precise answers that help educators improve their practice and are demonstrably superior to advice from general-purpose chatbots.

The long-term vision is a comprehensive coaching ecosystem that can securely incorporate local context — such as meeting transcripts and student data — to provide personalized, FERPA-compliant guidance. The MVP is the critical first step: proving that a high-quality, book-only RAG service can deliver significant value and build a foundation of trust with users. This strategic context explains certain architectural decisions in the MVP — such as the Tenant Enclave security model — that may appear over-engineered for a book-only service but are essential preparation for future phases involving sensitive educational data.


## 2. MVP Goals & Scope

The primary goal of the MVP is to validate the core hypothesis: that a well-designed RAG service, limited to a high-quality corpus, can provide more useful and accurate answers to real-world educator questions than a general-purpose chatbot.

### 2.1. Key Goals

**Deploy a Live Service:** Launch a functional API endpoint (`POST /api/v1/query`) for the PLC Coach service, hosted on AWS and accessible to the internal testing team.

**Validate Answer Quality:** Validate system performance quantitatively using an automated evaluation pipeline against a golden dataset of 50–100 questions, proving measurable superiority over a general-purpose LLM baseline.

**Establish Architectural Foundation:** Implement a secure, scalable architecture that is prepared for future enhancements — including the ingestion of sensitive student data — even though these features are not in the MVP.

### 2.2. Non-Goals (Explicitly Out of Scope for MVP)

**No User Interface (UI):** The MVP is a backend service only, accessed via its API.

**No User Authentication:** The API will be protected by a static API key for internal testing. Full user authentication and management are deferred to a future release.

**No Web Search:** The service will only answer questions based on the ingested PLC book corpus.

**No Student Data:** The MVP will not ingest or process any meeting transcripts, notes, or student-identifiable information.

**No Performance Optimization:** The focus is on quality and architectural correctness, not response time or cost-per-query optimization. A maximum acceptable response time is defined in the Non-Functional Requirements section (Section 4).

### 2.3. Evaluation Strategy

A phased evaluation approach will be used to ensure quality can be measured from the earliest stages of the build without creating a bottleneck on expert availability.

**Phase 0-A — Pre-Build (Questions First):** Before application coding begins, a golden dataset of real-world educator questions will be assembled from an existing scraped question bank and checked into the repository. The questions alone are the prerequisite for the build to start; expert-authored answers are not required at this stage. The dataset will be organized into three explicit categories:

| Category | Description | Expected System Behavior | Scoring Pass Condition |
|---|---|---|---|
| **In-Scope** | Questions answerable from the 25 PLC @ Work® books | Grounded, cited answer | Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70 |
| **Out-of-Scope** | Questions outside the corpus (e.g., state-specific standards, external policy) | Hard refusal: *"I can only answer questions based on the PLC @ Work® book series. This question falls outside that scope."* | System refuses without hallucinating; 100% of out-of-scope test questions must return the hard refusal response |
| **Ambiguous** | Questions that are in-scope but ambiguous per the three-category definition in Section 3.2 | Clarification question: Returns `needs_clarification` with a session_id and a single clarifying question | System correctly identifies ambiguity and asks exactly one relevant clarifying question; resolves to a grounded answer after follow-up |

The golden dataset shall contain a minimum of 50 questions (target: 100).

Out-of-scope questions are intentionally included to stress-test the system's ability to recognize the boundaries of its knowledge and refuse gracefully rather than hallucinate.

**Phase 0-B — During Build (Reference-Free Evaluation):** As the system is built, the RAGAS evaluation pipeline will be run in reference-free mode against the in-scope question set. This measures Faithfulness and Answer Relevancy without requiring a ground truth answer key, giving the team continuous, objective signal throughout development. Out-of-scope questions will be evaluated separately by checking that the system returns the hard refusal response.

**Phase 3 — Final Validation (Full Evaluation):** Before the MVP is considered complete, expert-authored answers will be added to the in-scope questions in the golden dataset. The RAGAS pipeline will then be re-run in full reference-based mode, adding Context Precision and Context Recall scores to produce a complete quality benchmark that formally validates the core hypothesis.


## 3. Functional Requirements

This section defines *what* the system must do as testable capabilities. Technology selections for each capability are documented in the Architecture section (Section 7).

### 3.1. Ingestion Pipeline

The ingestion pipeline processes the 25-book PLC @ Work® corpus into a searchable knowledge base. The quality of every downstream answer depends on the quality of this process.

**Source Material:** The initial corpus consists of 25 proprietary PLC books from Solution Tree's PLC @ Work® series in PDF format, stored in secure, versioned cloud storage.

**Layout-Aware Parsing:** The ingestion pipeline uses a three-step process, each step chosen for the right job:

| Step | Capability | Scope | Constraint |
|---|---|---|---|
| 1 | Page classification | Every page of every source PDF | No content sent externally |
| 2 | Hierarchical structure parsing | All portrait text-based pages | Self-hosted; no external transmission |
| 3 | Visual content extraction | All landscape pages (reproducibles/worksheets) | Zero-retention external API only |

**Enumerated Functional Requirements:**

- **FR-1:** The ingestion pipeline shall classify every page of each source PDF by orientation (portrait vs. landscape) and text-layer presence, without sending content to external services.
- **FR-2:** The ingestion pipeline shall parse hierarchical document structure (headings, sections, paragraphs, lists, tables) from all text-based portrait pages using a self-hosted parser that does not transmit proprietary content externally.
- **FR-3:** The ingestion pipeline shall extract structured Markdown content from all landscape-oriented pages (reproducibles, worksheets) using a zero-retention external vision model.
- **FR-4:** Every ingested chunk shall carry the complete metadata schema: book_title, authors, sku, chapter, section, page_number, and chunk_type. Missing required metadata is a pipeline error.
- **FR-5:** Before ingestion begins, an automated corpus scan shall produce per-book metrics (total pages, landscape pages, text-layer presence, estimated chunks). See Section 10 for full scan requirements.

**Rich Metadata (FR-4):** Every chunk of ingested text will be stored with a standardized metadata schema that captures book title, authors, SKU, chapter, section, page number, and content type. Missing required metadata is a pipeline error — partial records are not ingested. See the Technical Specification for the full schema definition.

**Pre-Build Corpus Scan (FR-5):** Before ingestion begins, an automated scan of all 25 PDFs must be completed to validate key assumptions about the corpus (page counts, landscape page volumes, text-layer presence). See Section 10 for the full scan requirements.

### 3.2. Query Engine

The query engine processes user questions and returns grounded, cited answers drawn from the PLC @ Work® corpus. The system must handle four distinct query types: direct answers, conditional clarification, out-of-scope detection, and metadata-filtered queries.

**Enumerated Functional Requirements:**

- **FR-6:** The system shall return a `success` response with a grounded, cited answer for unambiguous, in-scope queries in a single round trip.
- **FR-7:** The system shall return a `needs_clarification` response when a query meets both conditions of the ambiguity test defined below.
- **FR-8:** The system shall ask at most one clarifying question per session. If the follow-up remains ambiguous, the system shall answer using its best interpretation and explicitly state that interpretation in the response.
- **FR-9:** The system shall return an `out_of_scope` hard refusal for queries outside the PLC @ Work® corpus, using the fixed refusal string defined in Section 2.3.
- **FR-10:** The system shall extract metadata filters from the query when the query contains a recognized book title, author name, or content-type keyword, and apply those filters to narrow the retrieval scope.
- **FR-11:** When a metadata-filtered query returns fewer than 3 results, the system shall automatically fall back to an unfiltered search.

**Ambiguity Definition:** A query is considered ambiguous if and only if *both* of the following conditions are true: (a) the answer would differ meaningfully depending on which interpretation is correct, AND (b) the system cannot determine the correct interpretation from the query text alone. A query that is broad but has a single clear answer does not qualify as ambiguous. Ambiguity falls into three recognized categories:

| Category | Description | Example |
|---|---|---|
| **Topic Ambiguity** | The question covers a concept addressed in multiple distinct ways across the corpus, and the answer differs meaningfully by interpretation. | *"What does Learning by Doing say about assessment?"* — could mean formative, summative, or common assessment design. |
| **Scope Ambiguity** | The question is so broad that a direct answer would be overwhelming or require the system to guess which of many possible angles to take. | *"Tell me about PLCs."* |
| **Reference Ambiguity** | The question references a term or proper noun that maps to multiple distinct contexts in the corpus. | *"What does DuFour say about teams?"* — DuFour authored multiple books and "teams" appears in dozens of contexts. |

**One-Question Hard Limit:** The system may ask at most **one** clarifying question per session. If the user's follow-up response remains ambiguous, the system must answer using its best interpretation and explicitly state that interpretation at the end of the response (e.g., *"I interpreted your question as being about formative assessment. If you meant something else, please ask again."*). This limit exists to prevent the system from feeling interrogative to busy educators.

**Out-of-Scope Detection:** If the system determines that a query falls outside the scope of the PLC @ Work® corpus, it will return a hard refusal response rather than attempting to answer. The exact refusal message is defined in Section 2.3.

### 3.3. Hybrid Search & Re-Ranking

The retrieval mechanism combines semantic and keyword search to maximize the quality of retrieved context. The two search strategies compensate for each other's weaknesses: semantic search captures conceptual matches where exact terms are absent, and keyword search ensures domain-specific terminology is matched precisely.

**Enumerated Functional Requirements:**

- **FR-12:** The semantic search component shall retrieve the top-N candidate chunks by vector similarity, capturing conceptual matches even when exact query terms are absent. Initial N: 20 (tunable).
- **FR-13:** The keyword search component shall retrieve the top-N candidate chunks by exact keyword relevance, ensuring PLC-specific jargon and acronyms (e.g., RTI, SMART goals) are matched precisely. Initial N: 20 (tunable).
- **FR-14:** The system shall merge semantic and keyword results into a combined candidate set and re-rank the top-M candidates using a neural re-ranking model, passing the top-K highest-scoring results to the generation model. Initial values: M=40, K=5 (tunable).

> **Note:** The specific values for N, M, and K are capability parameters that will be tuned during development. The initial values above represent starting points based on RAG best practices.


## 4. Non-Functional Requirements

This section consolidates all quality attributes and operational constraints for the MVP into a single, measurable reference. Each NFR follows the template: "The system shall [metric] [condition] [measurement method]."

### 4.1. Quality & Performance NFRs

| NFR ID | Category | Requirement | Measurement Method |
|---|---|---|---|
| NFR-1 | Answer Quality | Faithfulness ≥ 0.80 | RAGAS evaluation pipeline against golden dataset |
| NFR-2 | Answer Quality | Answer Relevancy ≥ 0.75 | RAGAS evaluation pipeline against golden dataset |
| NFR-3 | Answer Quality | Context Precision ≥ 0.70 | RAGAS evaluation pipeline against golden dataset (Phase 3 only) |
| NFR-4 | Answer Quality | Context Recall ≥ 0.70 | RAGAS evaluation pipeline against golden dataset (Phase 3 only) |
| NFR-5 | Scope Enforcement | 100% out-of-scope query refusal rate | Automated test against out-of-scope golden dataset queries |
| NFR-6 | Interaction | Maximum 1 clarifying question per session | Automated test with ambiguous golden dataset queries |
| NFR-7 | Response Time | 95th percentile end-to-end response time ≤ 30 seconds for direct-answer queries | Application performance monitoring (CloudWatch) |
| NFR-8 | Availability | Service available 95% of business hours (Mon–Fri) during internal testing | CloudWatch uptime monitoring |
| NFR-9 | Throughput | Support at least 5 concurrent users without degradation | Load testing before MVP sign-off |
| NFR-10 | Golden Dataset | Minimum 50 questions: at least 35 in-scope, 10 out-of-scope, 5 ambiguous | Golden dataset file in repository |

### 4.2. Security & Operational NFRs

| NFR ID | Category | Requirement | Measurement Method |
|---|---|---|---|
| NFR-11 | Encryption | TLS 1.2+ enforced on all connections (ALB, RDS, ElastiCache, OpenAI) | Automated certificate/protocol checks in CI/CD |
| NFR-12 | Encryption | AWS KMS encryption at rest for all storage (RDS, S3, EBS) | Terraform plan output verification |
| NFR-13 | Data Privacy | Zero data retention on OpenAI API | Executed DPA documentation and API configuration audit |
| NFR-14 | Data Privacy | No PII in logs — metadata only, even in debug mode | Log sampling audit before MVP launch |
| NFR-15 | Session Management | Clarification session state expires after 15 minutes of inactivity | Automated test confirming expired session returns 400 |
| NFR-16 | Data Retention | Query audit logs retained for 90 days. Redis session data per NFR-15. PostgreSQL book/chunk data retained indefinitely. | Infrastructure configuration review |
| NFR-17 | Observability | Structured JSON logs for key events (query_received, answer_generated) with CloudWatch log groups. 30-day log retention. | CloudWatch log group configuration |
| NFR-18 | Recovery | RTO: 4 hours. RPO: 1 hour. | Disaster recovery runbook and RDS backup configuration |
| NFR-19 | Corpus Updates | Re-ingestion triggered manually on-demand. No automated schedule for MVP. | Documented in operations runbook |


## 5. Data Models & Schema

### 5.1. PostgreSQL Schema

PostgreSQL serves as the relational metadata store, providing structured lookups and audit logging.

**`books` table** — one row per book in the corpus:

| Column | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `sku` | string | Solution Tree SKU (e.g., `BKF219`) |
| `title` | string | Full book title |
| `authors` | string[] | List of author names |
| `created_at` | timestamp | Row creation timestamp |
| `updated_at` | timestamp | Row last-updated timestamp |

**`chunks` table** — one row per ingested text chunk:

| Column | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `book_id` | integer | Foreign key to `books.id` |
| `qdrant_id` | string | The corresponding vector ID in Qdrant |
| `text_content` | text | The raw text of the chunk (for citation excerpts and audit only — not indexed for search) |
| `page_number` | integer | Source page number |
| `chunk_type` | string | Content type: `title`, `body_text`, `list`, `table`, or `reproducible` |
| `chapter` | string | Chapter name (nullable) |
| `section` | string | Section name (nullable) |
| `created_at` | timestamp | Row creation timestamp |

> **Note on search:** The `text_content` column carries no full-text search index. Keyword search is handled entirely at the application layer. See the Technical Specification for the BM25 index build and maintenance strategy.

### 5.2. Qdrant Schema

Qdrant stores the vector embeddings and a payload for fast filtering during search.

- **Collection name:** `plc_copilot_v1`
- **Vector dimensions:** 3,072 (from `text-embedding-3-large`)
- **Payload fields for filtering:** `book_sku`, `authors`, `book_title`, `chunk_type`, `page_number`

> **Note on filtering:** The payload includes `authors` and `book_title` to support metadata-filtered queries (e.g., "What does DuFour say about teams?"). When an author or title filter is extracted from a query, it is applied directly against the Qdrant payload — no separate PostgreSQL lookup is required.


## 6. API Specification

The service exposes a single endpoint: `POST /api/v1/query`. The endpoint has **no persistent conversational memory between sessions** — each conversation thread is independent. Within a session, the conditional clarification loop uses short-lived Redis state to link a follow-up to its original query.

### 6.1. Authentication

The API is protected by a static API key passed in the `X-API-Key` request header. All requests without a valid key will receive a `401 Unauthorized` response.

### 6.2. Request Schema

```json
{
  "query": "string (required)",
  "user_id": "string (required)",
  "conversation_id": "string (required — UUID generated by the client)",
  "session_id": "string (optional — only included on a clarification follow-up)"
}
```

> **`user_id`:** A client-provided string used for logging and tracing only. Not validated against a user store for MVP.

> **`conversation_id`:** A UUID v4 generated by the client when a teacher begins a new interaction. Must be sent with every request in the same conversation thread and is echoed back in every response. For MVP, the server logs this field but does not validate it as a UUID — it is accepted as a plain string. This field is the foundation for memory and conversation history in Phase 2 — having it in place from day one ensures clean, threadable data without a future API contract change.

### 6.3. Response Schema

Every response includes a `status` field and echoes back the `conversation_id` from the request. The `status` field determines which additional fields are present.

| Status | Meaning | Additional Fields |
|---|---|---|
| `success` | A full answer was generated. | `answer` (string), `sources` (array) |
| `needs_clarification` | The query was ambiguous. | `clarification_question` (string), `session_id` (string) |
| `out_of_scope` | The query falls outside the PLC @ Work® corpus. | `message` (string — fixed refusal text) |

The two identifier fields serve distinct purposes and must not be confused:

| Field | Scope | Lifecycle | Purpose |
|---|---|---|---|
| `conversation_id` | The entire conversation thread | Client-generated; sent with every request; echoed in every response | Groups all exchanges together. Foundation for Phase 2 memory. |
| `session_id` | One clarification loop only | Server-generated on `needs_clarification`; present in the resolved `success` response; discarded thereafter | Links an ambiguous query to its one follow-up. |

Each object in the `sources` array contains: `book_title`, `sku`, `page_number`, and `text_excerpt`. The `text_excerpt` is the first 200 characters of the source chunk, used to give the reader a direct reference point.

### 6.4. Error Responses

| Scenario | HTTP Status | Response Body |
|---|---|---|
| Missing or invalid API key | `401 Unauthorized` | `{"error": "Unauthorized"}` |
| Malformed request body | `422 Unprocessable Entity` | Standard FastAPI/Pydantic validation error |
| Expired or invalid `session_id` on follow-up | `400 Bad Request` | `{"error": "Session expired or not found. Please resubmit your original query."}` |
| LLM or vector database service failure | `503 Service Unavailable` | `{"error": "The service is temporarily unavailable. Please try again."}` |
| Unexpected internal error | `500 Internal Server Error` | `{"error": "An unexpected error occurred."}` |

### 6.5. Rate Limiting

Rate limiting is deferred to post-MVP. The internal testing phase assumes single-digit concurrent user load. A rate limiting strategy will be defined before any external-facing deployment.

### 6.6. API Documentation

The FastAPI service shall auto-generate OpenAPI 3.0 documentation, accessible at the standard `/docs` endpoint. This serves as the live API reference during internal testing.

### 6.7. Flow A — Direct Answer (Clear Query)

When the query is unambiguous and in-scope, the system answers in a single round trip.

**Request:** `POST /api/v1/query`
```json
{
  "query": "What are the four critical questions of a PLC?",
  "user_id": "user-abc-123",
  "conversation_id": "conv-uuid-1234"
}
```

**Response:** `200 OK`
```json
{
  "status": "success",
  "conversation_id": "conv-uuid-1234",
  "answer": "According to 'Learning by Doing', the four critical questions that drive the work of a PLC are: (1) What do we want students to know and be able to do? (2) How will we know when each student has learned it? (3) How will we respond when some students do not learn? (4) How will we extend the learning for students who are already proficient?",
  "sources": [
    {
      "book_title": "Learning by Doing: A Handbook for PLCs at Work",
      "sku": "BKF219",
      "page_number": 36,
      "text_excerpt": "...the four critical questions that drive the work of collaborative teams in a PLC..."
    }
  ]
}
```

### 6.8. Flow B — Conditional Clarification (Ambiguous Query)

When the query is ambiguous, the system asks one clarifying question before answering.

**Step 1 — Initial Request:** `POST /api/v1/query`
```json
{
  "query": "What does Learning by Doing say about assessment?",
  "user_id": "user-abc-123",
  "conversation_id": "conv-uuid-1234"
}
```

**Step 1 — Response:** `200 OK`
```json
{
  "status": "needs_clarification",
  "conversation_id": "conv-uuid-1234",
  "session_id": "uuid-goes-here-1234",
  "clarification_question": "Are you asking about formative or summative assessment, or the role of assessment in a guaranteed and viable curriculum?"
}
```

**Step 2 — Follow-up Request:** `POST /api/v1/query`
```json
{
  "query": "formative assessment",
  "user_id": "user-abc-123",
  "conversation_id": "conv-uuid-1234",
  "session_id": "uuid-goes-here-1234"
}
```

**Step 2 — Response:** `200 OK`
```json
{
  "status": "success",
  "conversation_id": "conv-uuid-1234",
  "session_id": "uuid-goes-here-1234",
  "answer": "In 'Learning by Doing', the authors emphasize that formative assessment is a continuous process used by teams to monitor student learning on an ongoing basis...",
  "sources": [
    {
      "book_title": "Learning by Doing: A Handbook for PLCs at Work",
      "sku": "BKF219",
      "page_number": 87,
      "text_excerpt": "...the team uses common formative assessments to gather evidence of student learning..."
    }
  ]
}
```

### 6.9. Flow C — Out-of-Scope Query

When the query falls outside the corpus, the system returns a hard refusal without attempting to answer.

**Request:** `POST /api/v1/query`
```json
{
  "query": "What are the reading standards for third grade in Texas?",
  "user_id": "user-abc-123",
  "conversation_id": "conv-uuid-1234"
}
```

**Response:** `200 OK`
```json
{
  "status": "out_of_scope",
  "conversation_id": "conv-uuid-1234",
  "message": "I can only answer questions based on the PLC @ Work® book series. This question falls outside that scope."
}
```

### 6.10. Flow D — Metadata-Filtered Query

When the query contains a recognized author name, book title, or content-type keyword, the system applies metadata filters to narrow the search scope.

**Request:** `POST /api/v1/query`
```json
{
  "query": "What does DuFour say about collaborative teams?",
  "user_id": "user-abc-123",
  "conversation_id": "conv-uuid-5678"
}
```

**Response:** `200 OK`
```json
{
  "status": "success",
  "conversation_id": "conv-uuid-5678",
  "answer": "In 'Learning by Doing', DuFour and colleagues describe collaborative teams as the fundamental building blocks of a PLC. They emphasize that the purpose of collaboration is not simply to meet — it is to collectively answer the four critical questions of a PLC...",
  "sources": [
    {
      "book_title": "Learning by Doing: A Handbook for PLCs at Work",
      "sku": "BKF219",
      "page_number": 119,
      "text_excerpt": "...the team is the engine that drives the PLC process. Collaboration is a means to an end..."
    }
  ]
}
```

> **Note:** If the author-filtered search returns fewer than 3 results, the system automatically falls back to an unfiltered search to ensure a robust response. The client is not aware of the fallback — the response format is identical.


## 7. Architecture & Technology Stack

The MVP will be built on AWS, using a hybrid of managed and self-hosted services to balance security, cost, and operational simplicity. The guiding principle is: **self-host anything that touches proprietary or sensitive content; use managed services for everything else.**

| Component | Technology | Hosting Model | Rationale |
|---|---|---|---|
| **Application Framework** | Python 3.11+ with FastAPI & Pydantic | N/A | Modern, high-performance async framework with strong data validation. |
| **RAG Orchestration** | LlamaIndex | N/A | Provides the hybrid search, re-ranking, and generation pipeline. Runs within the API service. |
| **Compute (API)** | Docker Container on AWS Fargate | Managed (HIPAA-eligible) | Abstracts server management while remaining on a HIPAA-eligible service required for FERPA compliance. The API and Re-ranker run as a single container for MVP simplicity. |
| **Vector Database** | Qdrant | Self-Hosted on EC2 | The most critical data store from a compliance perspective. A single `t4g.medium` instance in a private VPC ensures vector embeddings of proprietary content never leave direct control. |
| **PDF Parser (nlm-ingestor)** | llmsherpa / `nlm-ingestor` | Docker container, ingestion-only | Runs as a Docker container exclusively during the ingestion script. Not part of the live API container and not running in production. |
| **Re-ranker** | `cross-encoder/ms-marco-MiniLM-L-6-v2` | In-Process Python Module | Loaded directly inside the API container at startup. No separate server or network hop required. |
| **Relational Database** | PostgreSQL 15+ | Amazon RDS (Managed) | Reliable, low-maintenance storage for book metadata, chunk records, and audit logs. |
| **Session Cache** | Redis 7+ | Amazon ElastiCache (Managed) | Manages the state of the conditional clarification loop sessions. A `cache.t3.micro` instance is sufficient for MVP. |
| **File Storage (Corpus)** | — | Amazon S3 (Managed) | Source PDFs stored in a private bucket with versioning enabled and access restricted to the ingestion service IAM role. |
| **LLM & Embeddings** | GPT-4o, `text-embedding-3-large` | OpenAI API (External) | All usage through enterprise-grade, zero-retention endpoints governed by an executed DPA. |

**Search Algorithm Choices:** The keyword search component uses BM25 scoring via LlamaIndex's `BM25Retriever`, operating at the application layer rather than the database layer. This avoids PostgreSQL's `ts_rank` scaling limitations under concurrent load. The re-ranking step uses the `cross-encoder/ms-marco-MiniLM-L-6-v2` model, loaded in-process at API startup.

### 7.1. DevOps & Infrastructure

**Infrastructure as Code:** All AWS resources will be defined using Terraform, ensuring the environment is reproducible and version-controlled.

**CI/CD Pipeline:** A GitHub Actions workflow will trigger on every push to `main` to run linters and unit tests, build and tag a Docker image, push the image to Amazon ECR, and trigger a new Fargate deployment.

**Ingestion:** The ingestion pipeline is triggered via GitHub Actions but **all content processing runs inside the VPC** via AWS Systems Manager (SSM) Run Command on the Qdrant EC2 instance. Proprietary book content never passes through GitHub's public runners. See the Technical Specification for the full SSM workflow.

**Networking:** A dedicated VPC with public and private subnets in a **single availability zone** for MVP. The Application Load Balancer resides in the public subnets. All other services (Fargate, RDS, ElastiCache, EC2/Qdrant) reside in the private subnets. A NAT Gateway provides controlled egress for services that call external APIs.

**Secrets Management:** All secrets stored in AWS Secrets Manager. IAM roles with least-privilege permissions govern all service-to-service access. All data encrypted at rest (AWS KMS) and in transit (TLS 1.2+).

**Observability:** For MVP, observability requirements are defined in the Non-Functional Requirements section (Section 4). Full dashboards, metric alarms, and distributed tracing are deferred to a future release.


## 8. Security & Compliance: The Tenant Enclave Foundation

The architecture is designed to be **compliant by default**. Even though the MVP only handles proprietary book content with no student data, the security model is designed to be ready for future FERPA-constrained data sources.

The service will operate as a "school official" under FERPA, which is permissible only with strict contractual and technical controls. The system is also designed to meet the requirements of state-level student privacy laws (e.g., NY Ed Law § 2-d, California's SOPIPA) that mandate controls beyond FERPA.

**COPPA:** The MVP is designed exclusively for adult educators. No direct student access is supported. If future features enable student-facing interactions, COPPA compliance will be assessed before launch.

**Accessibility:** The MVP is an API-only service with no user interface. API responses use structured JSON to support accessible client implementations. WCAG 2.1 AA compliance will be required for the teachers-portal and admins-portal when those UIs are built.

### 8.1. The Three-Zone Tenant Enclave Model

The system's data architecture is built on three logically segregated zones. For MVP, **only the infrastructure for Zone A will be provisioned.** The infrastructure for Zones B and C will be defined as commented-out code in Terraform, ready to be activated in future phases.

| Zone | Name | What Lives Here | MVP Status |
|---|---|---|---|
| **Zone A** | Content Zone | The 25 PLC @ Work® books — PDFs, parsed text, and vector embeddings. Proprietary IP but no PII. | **Infrastructure built and populated at MVP launch** |
| **Zone B** | Meeting / Transcript Zone | De-identified PLC meeting transcripts and notes (future). | **Infrastructure defined in code, but not provisioned** |
| **Zone C** | Identity / Student Directory Zone | The mapping between real student names and anonymized tokens (future). Accessible only by a dedicated, audited tokenization service. | **Infrastructure defined in code, but not provisioned** |

### 8.2. Core Security Controls

**Encryption:** All data is encrypted in transit (TLS 1.2+) and at rest (AWS KMS).

**Access Control:** IAM roles with least-privilege permissions govern all service-to-service access. No service has access beyond what its specific function requires.

**Third-Party Data Processing:** Any vendor or sub-processor that receives data (currently OpenAI) must be governed by an executed Data Processing Agreement (DPA) that contractually enforces zero data retention and prohibits secondary use.

**API Security:** The MVP API is protected by a static API key passed via the `X-API-Key` header. Full user authentication is deferred to a future release.

**Audit Logging:** Structured JSON logs capture key events (query received, answer generated) with metadata. Logs are configured to never capture raw PII or student-identifiable content, even in debug mode.


## 9. Acceptance Criteria

The MVP will be considered complete when all of the following criteria are met:

1. All Zone A infrastructure described in Section 7 is provisioned in an AWS account using Terraform. The infrastructure for Zones B and C is defined as commented-out code with documented intent.

2. A CI/CD pipeline (GitHub Actions) is in place to automatically build, test, and deploy changes to the Fargate service.

3. The pre-build corpus scan (Section 10) has been completed and its findings reviewed and signed off before ingestion begins.

4. The golden dataset (Section 2.3) has been assembled from the scraped question bank, categorized into in-scope, out-of-scope, and ambiguous questions, and checked into the repository.

5. The ingestion pipeline successfully processes all 25 source PDFs from the S3 bucket into the Qdrant vector store and the PostgreSQL metadata database.

6. The `POST /api/v1/query` endpoint is live and accessible via the public ALB URL, protected by a static API key in the `X-API-Key` header.

7. The endpoint correctly implements the **conditional** clarification loop: returning a direct `success` response for clear queries and a `needs_clarification` response with a valid `session_id` for ambiguous queries. The clarification loop must trigger only on queries that meet the two-part ambiguity test defined in Section 3.2.

8. When a clarification follow-up is itself ambiguous, the system answers using its best interpretation and appends a statement of that interpretation to the response. The system never asks more than one clarifying question per session.

9. The endpoint correctly returns an `out_of_scope` hard refusal response for all out-of-scope test queries in the golden dataset. The refusal rate must be 100% for this category.

10. The RAGAS evaluation pipeline is functional and produces Faithfulness and Answer Relevancy scores in reference-free mode against the in-scope golden dataset.

11. In-scope queries meet the RAGAS thresholds defined in Section 2.3: Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70.

12. A query for a known in-scope topic returns a coherent, grounded answer with accurate source citations (book title, SKU, page number, and text excerpt).

13. A query for a reproducible correctly uses the `chunk_type` filter and returns relevant results derived from the vision-processed landscape pages.

14. A query containing a recognized author name or book title triggers metadata-filtered retrieval. When the filtered query returns fewer than 3 results, the system falls back to an unfiltered search and returns a grounded answer with accurate source citations.

15. The golden dataset includes at least 5 ambiguous queries. The system returns `needs_clarification` for these queries and resolves to a grounded answer after a single follow-up.


## 10. Pre-Build Corpus Analysis

Before application coding begins, an automated scan of the 25-book corpus must be performed and its findings reviewed. This scan de-risks the build by validating key assumptions about the corpus before the ingestion pipeline is written.

### 10.1. Scan Requirements

The pre-build scan must produce the following data for each book:

| Metric | Purpose |
|---|---|
| Total page count | Validates cost and time estimates for ingestion |
| Landscape page count | Determines the volume of vision model calls required |
| Text-layer presence per page | Identifies scanned/image-only pages that cannot be parsed by the structure-aware parser and may require special handling |
| Estimated chunk count | Provides a basis for Qdrant storage sizing and embedding cost calculation |

### 10.2. Definition of Done

The pre-build corpus scan is considered complete when:

- The scan script has been run against all 25 PDFs in the S3 bucket.
- A summary report has been generated and reviewed by the team.
- Any books with unexpected characteristics (e.g., a high proportion of image-only pages) have been flagged and a handling decision has been documented before ingestion begins.


## 11. Key Decisions Log

| Decision # | Decision | Rationale |
|---|---|---|
| #1 | Use hybrid search (BM25 + vector) | PLC jargon requires exact keyword matching; vector-only search misses acronyms like RTI and SMART goals. |
| #2 | Conditional clarification loop (not mandatory) | Mandatory clarification on every query would frustrate busy educators. The system should answer directly when the query is clear. |
| #3 | Three-stage hybrid parser (PyMuPDF + llmsherpa + GPT-4o Vision) | Each tool is chosen for the right job. PyMuPDF classifies pages cheaply; llmsherpa handles structured text hierarchically; GPT-4o Vision handles visual reproducibles that text parsers cannot capture. |
| #4 | Self-host Qdrant on EC2 | Proprietary book content and future student data must not leave direct organizational control. Managed vector DB services would send embeddings to third-party infrastructure. |
| #5 | BM25 at the application layer (LlamaIndex `BM25Retriever`) | PostgreSQL's native `ts_rank` does not scale — it must score every matching document before ranking, creating a bottleneck under concurrent load. Application-layer BM25 avoids this while remaining on managed RDS. |
| #6 | Simplified single-AZ Fargate (not multi-service microservices) | The MVP is an internal testing tool, not a public product. Full microservices architecture is over-engineered for this stage and slows the team down. |
| #7 | Pre-build corpus scan before ingestion | Validates assumptions about the corpus before the ingestion pipeline is built, preventing costly rework if the PDFs contain unexpected characteristics. |
| #8 | Use Fargate (not App Runner) for compute | App Runner is not on AWS's HIPAA-eligible services list. FERPA compliance requires compute on a HIPAA-eligible service. Fargate is HIPAA-eligible. |
| #9 | `conversation_id` in every request/response | Adding this field now costs nothing and ensures all conversation data is threadable from day one, enabling Phase 2 memory without a breaking API change. |
| #10 | Ingestion runs inside VPC via SSM, not on GitHub Actions public runners | Upholds the security principle of never processing proprietary content on external infrastructure. Sets the correct pattern for future FERPA-regulated data ingestion in Zones B and C. |
| #11 | Define retrieval parameters (top-k, re-ranking batch size) as tunable capability parameters in the PRD | Search pipeline parameters directly determine answer quality — the PRD's primary success criterion — and must be testable against acceptance criteria. |
| #12 | Defer rate limiting to post-MVP | Internal testing assumes single-digit concurrent user load. Rate limiting adds complexity with no MVP benefit. |
| #13 | Defer accessibility (WCAG) to portal phase | MVP is API-only with no UI. Structured JSON responses support accessible client implementations. |
