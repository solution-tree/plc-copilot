# PRD: PLC Coach Service (MVP)

**Document Purpose:** This Product Requirements Document (PRD) defines **what** the MVP of the PLC Coach Service must do and **why** it matters. It is the source of truth for product decisions. Implementation details — including how components are built, the query pipeline execution order, chunking parameters, and infrastructure configuration — are documented in the companion Technical Specification.

**Author:** Nani | **Version:** 4.1 | **Date:** February 25, 2026

---

## 1. Vision & Strategic Context

The PLC Coach Service is an AI-powered assistant designed to provide educators with immediate, expert guidance grounded in the principles of Professional Learning Communities (PLCs). The core business problem is that educators lack the time to find specific, actionable answers within the dense corpus of Solution Tree's PLC @ Work® series. This service bridges that gap by providing a conversational API to a curated library of PLC books, delivering precise, context-aware answers that help educators improve their practice and are demonstrably superior to advice from general-purpose chatbots.

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

**No Performance Optimization:** The focus is on quality and architectural correctness, not response time or cost-per-query optimization.

### 2.3. Evaluation Strategy

A phased evaluation approach will be used to ensure quality can be measured from the earliest stages of the build without creating a bottleneck on expert availability.

**Phase 0-A — Pre-Build (Questions First):** Before application coding begins, a golden dataset of real-world educator questions will be assembled from an existing scraped question bank and checked into the repository. The questions alone are the prerequisite for the build to start; expert-authored answers are not required at this stage. The dataset will be organized into two explicit categories:

| Category | Description | Expected System Behavior | Scoring Pass Condition |
|---|---|---|---|
| **In-Scope** | Questions answerable from the 25 PLC @ Work® books | Grounded, cited answer | Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70 |
| **Out-of-Scope** | Questions outside the corpus (e.g., state-specific standards, external policy) | Hard refusal: *"I can only answer questions based on the PLC @ Work® book series. This question falls outside that scope."* | System refuses without hallucinating; 100% of out-of-scope test questions must return the hard refusal response |

Out-of-scope questions are intentionally included to stress-test the system's ability to recognize the boundaries of its knowledge and refuse gracefully rather than hallucinate.

**Phase 0-B — During Build (Reference-Free Evaluation):** As the system is built, the RAGAS evaluation pipeline will be run in reference-free mode against the in-scope question set. This measures Faithfulness and Answer Relevancy without requiring a ground truth answer key, giving the team continuous, objective signal throughout development. Out-of-scope questions will be evaluated separately by checking that the system returns the hard refusal response.

**Phase 3 — Final Validation (Full Evaluation):** Before the MVP is considered complete, expert-authored answers will be added to the in-scope questions in the golden dataset. The RAGAS pipeline will then be re-run in full reference-based mode, adding Context Precision and Context Recall scores to produce a complete quality benchmark that formally validates the core hypothesis.


## 3. Core Features & Requirements

### 3.1. High-Quality Ingestion Pipeline

The service's quality is entirely dependent on the quality of the ingestion process. The MVP will implement a sophisticated ingestion pipeline that processes the 25-book corpus into a searchable knowledge base.

**Source Material:** The initial corpus consists of 25 proprietary PLC books from Solution Tree's PLC @ Work® series in PDF format, stored in a private AWS S3 bucket.

**Hybrid Layout-Aware Parsing:** The ingestion pipeline uses three tools in sequence, each chosen for the right job:

| Step | Tool | Role |
|---|---|---|
| 1 | PyMuPDF | Reads every page and classifies it by orientation (portrait vs. landscape) and whether a text layer is present. Acts as a lightweight sorter — no content is sent externally at this stage. |
| 2 | llmsherpa (self-hosted) | Handles all standard portrait pages. Parses the document's hierarchical structure — headings, sections, paragraphs, lists, and tables — without sending proprietary content to any external service. |
| 3 | GPT-4o Vision | Reserved exclusively for landscape-oriented pages identified as reproducibles or worksheets. Renders the page as an image and generates a detailed, structured Markdown description, ensuring the content of these critical visual assets is fully captured. |

**Rich Metadata:** Every chunk of ingested text will be stored with a standardized metadata schema that captures book title, authors, SKU, chapter, section, page number, and content type. See the Technical Specification for the full schema definition.

**Pre-Build Corpus Scan:** Before ingestion begins, a lightweight automated scan of all 25 PDFs must be completed to validate key assumptions about the corpus (page counts, landscape page volumes, text-layer presence). See Section 9 for the full scan requirements.

### 3.2. Query Engine

The query engine delivers high-fidelity, context-aware responses through a multi-stage process. The system must handle four distinct query types:

**Direct Answer (Clear Query):** When a query is unambiguous and in-scope, the system retrieves the most relevant content and generates a grounded, cited answer in a single round trip.

**Conditional Clarification (Ambiguous Query):** The clarification loop is conditional, not mandatory. When the system detects that a query is ambiguous, it returns a `needs_clarification` response with a clarifying question. When a query is clear and unambiguous, the system answers directly without requiring a follow-up.

**Ambiguity Definition:** A query is considered ambiguous if and only if *both* of the following conditions are true: (a) the answer would differ meaningfully depending on which interpretation is correct, AND (b) the system cannot determine the correct interpretation from the query text alone. A query that is broad but has a single clear answer does not qualify as ambiguous. Ambiguity falls into three recognized categories:

| Category | Description | Example |
|---|---|---|
| **Topic Ambiguity** | The question covers a concept addressed in multiple distinct ways across the corpus, and the answer differs meaningfully by interpretation. | *"What does Learning by Doing say about assessment?"* — could mean formative, summative, or common assessment design. |
| **Scope Ambiguity** | The question is so broad that a direct answer would be overwhelming or require the system to guess which of many possible angles to take. | *"Tell me about PLCs."* |
| **Reference Ambiguity** | The question references a term or proper noun that maps to multiple distinct contexts in the corpus. | *"What does DuFour say about teams?"* — DuFour authored multiple books and "teams" appears in dozens of contexts. |

**One-Question Hard Limit:** The system may ask at most **one** clarifying question per session. If the user's follow-up response remains ambiguous, the system must answer using its best interpretation and explicitly state that interpretation at the end of the response (e.g., *"I interpreted your question as being about formative assessment. If you meant something else, please ask again."*). This limit exists to prevent the system from feeling interrogative to busy educators.

**Out-of-Scope Detection:** If the system determines that a query falls outside the scope of the PLC @ Work® corpus, it will return a hard refusal response rather than attempting to answer. The exact refusal message is defined in Section 2.3.

**Dynamic Metadata Filtering:** The system will attempt to extract metadata filters from the query (e.g., a specific book title, author, or a request for a reproducible) to narrow the search to the most relevant content. If a filtered query returns fewer than three results, the system automatically falls back to an unfiltered search to ensure a robust response.

### 3.3. Hybrid Search & Re-Ranking

The retrieval mechanism uses a hybrid search approach that combines both semantic and keyword search to maximize the quality of retrieved context.

**Semantic Search (Vector):** Finds chunks that are conceptually similar to the query using vector embeddings, even when the exact words do not match. This is effective for broad, conceptual questions.

**Keyword Search (BM25):** Finds chunks containing the exact terms from the query. This is critical for PLC-specific jargon and acronyms (e.g., RTI, SMART goals, guaranteed and viable curriculum). BM25 is handled at the application layer, not in the database, to ensure scalability as the corpus grows.

**Re-Ranking:** After both searches run, a cross-encoder re-ranker scores and re-orders the combined candidate set by relevance to the query before the top results are passed to the generation model. This directly addresses the known weakness of simple vector-only search.


## 4. Data Models & Schema

### 4.1. PostgreSQL Schema

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

### 4.2. Qdrant Schema

Qdrant stores the vector embeddings and a lightweight payload for fast filtering during search.

- **Collection name:** `plc_copilot_v1`
- **Vector dimensions:** 3,072 (from `text-embedding-3-large`)
- **Payload fields for filtering:** `book_sku`, `authors`, `book_title`, `chunk_type`, `page_number`

> **Note on filtering:** The payload includes `authors` and `book_title` to support metadata-filtered queries (e.g., "What does DuFour say about teams?"). When an author or title filter is extracted from a query, it is applied directly against the Qdrant payload — no separate PostgreSQL lookup is required.


## 5. API Specification

The service exposes a single endpoint: `POST /api/v1/query`. The endpoint has **no persistent conversational memory between sessions** — each conversation thread is independent. Within a session, the conditional clarification loop uses short-lived Redis state to link a follow-up to its original query.

### 5.1. Authentication

The API is protected by a static API key passed in the `X-API-Key` request header. All requests without a valid key will receive a `401 Unauthorized` response.

### 5.2. Request Schema

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

### 5.3. Response Schema

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

### 5.4. Error Responses

| Scenario | HTTP Status | Response Body |
|---|---|---|
| Missing or invalid API key | `401 Unauthorized` | `{"error": "Unauthorized"}` |
| Malformed request body | `422 Unprocessable Entity` | Standard FastAPI/Pydantic validation error |
| Expired or invalid `session_id` on follow-up | `400 Bad Request` | `{"error": "Session expired or not found. Please resubmit your original query."}` |
| LLM or vector database service failure | `503 Service Unavailable` | `{"error": "The service is temporarily unavailable. Please try again."}` |
| Unexpected internal error | `500 Internal Server Error` | `{"error": "An unexpected error occurred."}` |

### 5.5. Flow A — Direct Answer (Clear Query)

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

### 5.6. Flow B — Conditional Clarification (Ambiguous Query)

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

### 5.7. Flow C — Out-of-Scope Query

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


## 6. Architecture & Technology Stack

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

### 6.1. DevOps & Infrastructure

**Infrastructure as Code:** All AWS resources will be defined using Terraform, ensuring the environment is reproducible and version-controlled.

**CI/CD Pipeline:** A GitHub Actions workflow will trigger on every push to `main` to run linters and unit tests, build and tag a Docker image, push the image to Amazon ECR, and trigger a new Fargate deployment.

**Ingestion:** The ingestion pipeline is triggered via GitHub Actions but **all content processing runs inside the VPC** via AWS Systems Manager (SSM) Run Command on the Qdrant EC2 instance. Proprietary book content never passes through GitHub's public runners. See the Technical Specification for the full SSM workflow.

**Networking:** A dedicated VPC with public and private subnets in a **single availability zone** for MVP. The Application Load Balancer resides in the public subnets. All other services (Fargate, RDS, ElastiCache, EC2/Qdrant) reside in the private subnets. A NAT Gateway provides controlled egress for services that call external APIs.

**Secrets Management:** All secrets stored in AWS Secrets Manager. IAM roles with least-privilege permissions govern all service-to-service access. All data encrypted at rest (AWS KMS) and in transit (TLS 1.2+).

**Observability:** For MVP, observability is limited to basic CloudWatch log groups for the Fargate service. Full dashboards, metric alarms, and distributed tracing are deferred to a future release.


## 7. Security & Compliance: The Tenant Enclave Foundation

The architecture is designed to be **compliant by default**. Even though the MVP only handles proprietary book content with no student data, the security model is designed to be ready for future FERPA-constrained data sources.

The service will operate as a "school official" under FERPA, which is permissible only with strict contractual and technical controls. The system is also designed to meet the requirements of state-level student privacy laws (e.g., NY Ed Law § 2-d, California's SOPIPA) that mandate controls beyond FERPA.

### 7.1. The Three-Zone Tenant Enclave Model

The system's data architecture is built on three logically segregated zones. For MVP, **only the infrastructure for Zone A will be provisioned.** The infrastructure for Zones B and C will be defined as commented-out code in Terraform, ready to be activated in future phases.

| Zone | Name | What Lives Here | MVP Status |
|---|---|---|---|
| **Zone A** | Content Zone | The 25 PLC @ Work® books — PDFs, parsed text, and vector embeddings. Proprietary IP but no PII. | **Infrastructure built and populated at MVP launch** |
| **Zone B** | Meeting / Transcript Zone | De-identified PLC meeting transcripts and notes (future). | **Infrastructure defined in code, but not provisioned** |
| **Zone C** | Identity / Student Directory Zone | The mapping between real student names and anonymized tokens (future). Accessible only by a dedicated, audited tokenization service. | **Infrastructure defined in code, but not provisioned** |

### 7.2. Core Security Controls

**Encryption:** All data is encrypted in transit (TLS 1.2+) and at rest (AWS KMS).

**Access Control:** IAM roles with least-privilege permissions govern all service-to-service access. No service has access beyond what its specific function requires.

**Third-Party Data Processing:** Any vendor or sub-processor that receives data (currently OpenAI) must be governed by an executed Data Processing Agreement (DPA) that contractually enforces zero data retention and prohibits secondary use.

**API Security:** The MVP API is protected by a static API key passed via the `X-API-Key` header. Full user authentication is deferred to a future release.

**Audit Logging:** Structured JSON logs capture key events (query received, answer generated) with metadata. Logs are configured to never capture raw PII or student-identifiable content, even in debug mode.


## 8. Acceptance Criteria

The MVP will be considered complete when all of the following criteria are met:

1. All Zone A infrastructure described in Section 6 is provisioned in an AWS account using Terraform. The infrastructure for Zones B and C is defined as commented-out code with documented intent.

2. A CI/CD pipeline (GitHub Actions) is in place to automatically build, test, and deploy changes to the Fargate service.

3. The pre-build corpus scan (Section 9) has been completed and its findings reviewed and signed off before ingestion begins.

4. The golden dataset (Section 2.3) has been assembled from the scraped question bank, categorized into in-scope and out-of-scope questions, and checked into the repository.

5. The ingestion pipeline successfully processes all 25 source PDFs from the S3 bucket into the Qdrant vector store and the PostgreSQL metadata database.

6. The `POST /api/v1/query` endpoint is live and accessible via the public ALB URL, protected by a static API key in the `X-API-Key` header.

7. The endpoint correctly implements the **conditional** clarification loop: returning a direct `success` response for clear queries and a `needs_clarification` response with a valid `session_id` for ambiguous queries. The clarification loop must trigger only on queries that meet the two-part ambiguity test defined in Section 3.2.

8. When a clarification follow-up is itself ambiguous, the system answers using its best interpretation and appends a statement of that interpretation to the response. The system never asks more than one clarifying question per session.

9. The endpoint correctly returns an `out_of_scope` hard refusal response for all out-of-scope test queries in the golden dataset. The refusal rate must be 100% for this category.

10. The RAGAS evaluation pipeline is functional and produces Faithfulness and Answer Relevancy scores in reference-free mode against the in-scope golden dataset.

11. In-scope queries meet the RAGAS thresholds defined in Section 2.3: Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70.

12. A query for a known in-scope topic returns a coherent, grounded answer with accurate source citations (book title, SKU, page number, and text excerpt).

13. A query for a reproducible correctly uses the `chunk_type` filter and returns relevant results derived from the vision-processed landscape pages.


## 9. Pre-Build Corpus Analysis

Before application coding begins, a lightweight automated scan of the 25-book corpus must be performed and its findings reviewed. This scan de-risks the build by validating key assumptions about the corpus before the ingestion pipeline is written.

### 9.1. Scan Requirements

The pre-build scan must produce the following data for each book:

| Metric | Purpose |
|---|---|
| Total page count | Validates cost and time estimates for ingestion |
| Landscape page count | Determines the volume of GPT-4o Vision calls required |
| Text-layer presence per page | Identifies scanned/image-only pages that cannot be parsed by llmsherpa and may require special handling |
| Estimated chunk count | Provides a basis for Qdrant storage sizing and embedding cost calculation |

### 9.2. Definition of Done

The pre-build corpus scan is considered complete when:

- The scan script has been run against all 25 PDFs in the S3 bucket.
- A summary report has been generated and reviewed by the team.
- Any books with unexpected characteristics (e.g., a high proportion of image-only pages) have been flagged and a handling decision has been documented before ingestion begins.


## 10. Key Decisions Log

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
