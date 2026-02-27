---
title: "PRD: PLC Coach Service (MVP)"
version: "4.3"
date: "2026-02-27"
author: "LasChicas.ai"
classification:
  domain: edtech
  projectType: api_backend
workflowType: prd
workflow: edit
stepsCompleted: ['step-e-01-discovery', 'step-e-02-review', 'step-e-03-edit']
lastEdited: '2026-02-27'
editHistory:
  - date: '2026-02-27'
    changes: 'Validation-driven edit: rewrote 5 FRs (006-009, 013) to [Actor] can [capability] format, added FR-014 for evaluation pipeline (closing Journey C traceability gap), added measurement methods to 4 NFRs (003, 005, 006, 007)'
  - date: '2026-02-26'
    changes: 'Validation-driven edit: added User Journeys, NFR section, restructured FRs with IDs and test criteria, removed implementation leakage from requirements, added baseline methodology and AC #14'
---

# PRD: PLC Coach Service (MVP)

**Document Purpose:** This PRD defines **what** the MVP of the PLC Coach Service must do, **why** it matters, and the key architectural decisions that shape the product. It is the source of truth for product decisions. Where implementation details are included (such as technology selections in the Architecture section), they document confirmed decisions essential for understanding the product's constraints. Detailed implementation guidance — including query pipeline execution order, chunking parameters, and infrastructure configuration — is documented in the companion Technical Specification.

**Author:** LasChicas.ai | **Version:** 4.3 | **Date:** February 27, 2026

---

## 1. Vision & Strategic Context

The PLC Coach Service is an AI-powered assistant designed to provide educators with immediate, expert guidance grounded in the principles of Professional Learning Communities (PLCs). The core business problem is that educators lack the time to find specific, actionable answers within the dense corpus of Solution Tree's PLC @ Work® series. This service bridges that gap by providing a conversational API to a curated library of PLC books, delivering precise, context-aware answers that help educators improve their practice and are demonstrably superior to advice from general-purpose chatbots.

The long-term vision is a comprehensive coaching ecosystem that can securely incorporate local context — such as meeting transcripts and student data — to provide personalized, FERPA-compliant guidance. The MVP is the critical first step: proving that a high-quality, book-only RAG service can deliver significant value and — through citation accuracy and faithful grounding — begin building trust with users. This strategic context explains certain architectural decisions in the MVP — such as the Tenant Enclave security model — that may appear over-engineered for a book-only service but are essential preparation for future phases involving sensitive educational data.


## 2. MVP Goals & Scope

The primary goal of the MVP is to validate the core hypothesis: that a well-designed RAG service, limited to a high-quality corpus, can provide more useful and accurate answers to real-world educator questions than a general-purpose chatbot.

### 2.1. Key Goals

**Deploy a Live Service:** Launch a functional API endpoint (`POST /api/v1/query`) for the PLC Coach service, hosted on AWS and accessible to the internal testing team.

**Validate Answer Quality:** Validate system performance quantitatively using an automated evaluation pipeline against a golden dataset of 50–100 questions, proving measurable superiority over a general-purpose LLM baseline.

**Establish Architectural Foundation:** Implement a secure, scalable architecture that is prepared for future enhancements — including the ingestion of sensitive student data — even though these features are not in the MVP.

### 2.2. Non-Goals (Explicitly Out of Scope for MVP)

**No Production UI:** The MVP does not include a production-ready user interface.

**Minimal Test Client (In Scope):** A minimal test client will be provided for internal testing only. It consists of a single question input field and a prominent banner stating: "This is a testing environment only. Responses do not reflect final product output." No other UI elements, styling, or features are in scope for this client.

**No User Authentication:** The API will be protected by a static API key for internal testing. Full user authentication and management are deferred to a future release.

**No Web Search:** The service will only answer questions based on the ingested PLC book corpus.

**No Student Data:** The MVP will not ingest or process any meeting transcripts, notes, or student-identifiable information.

**No Response-Time or Cost Optimization:** The focus is on answer quality and architectural correctness. Response-time tuning, cost-per-query optimization, and load testing are deferred to a future release. Architectural decisions that improve retrieval quality (such as hybrid search and re-ranking) are in scope because they serve the quality goal, not the performance goal.

**No Rate Limiting:** The MVP serves a small internal testing team. Rate limiting and request quotas will be introduced when the API is exposed to external users.

**No Accessibility Compliance:** The MVP is an API-only backend with no user interface. Accessibility requirements (WCAG 2.1 AA, Section 508) will be addressed when a user-facing interface is introduced. Target users work in federally funded institutions where Section 508 compliance is mandatory — this is a critical future requirement.

**No Standalone API Documentation:** The FastAPI framework auto-generates OpenAPI/Swagger documentation at `/docs`. This serves as the API reference for internal testers. A dedicated documentation effort is deferred.

### 2.3. Evaluation Strategy

A phased evaluation approach ensures quality can be measured from the earliest stages of the build. The corpus includes *Concise Answers to Frequently Asked Questions About Professional Learning Communities at Work*, which provides canonical, author-written answers to common PLC questions. This book serves as the built-in ground truth for correctness verification, eliminating the need for separately authored expert answer keys.

**Phase 0-A — Pre-Build (Questions First):** Before application coding begins, a golden dataset of real-world educator questions will be assembled from an existing scraped question bank and checked into the repository. The questions alone are the prerequisite for the build to start. The dataset will be organized into two explicit categories:

| Category | Description | Expected System Behavior | Scoring Pass Condition |
|---|---|---|---|
| **In-Scope** | Questions answerable from the 25 PLC @ Work® books | Grounded, cited answer | Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70 |
| **Out-of-Scope** | Questions outside the corpus (e.g., state-specific standards, external policy) | Hard refusal: *"I can only answer questions based on the PLC @ Work® book series. This question falls outside that scope."* | System refuses without hallucinating; 100% of out-of-scope test questions must return the hard refusal response |
| **Ambiguous** | Questions that are in-scope but meet both conditions of the ambiguity test defined in FR-007 (e.g., "What does DuFour say about teams?") | Returns needs_clarification with a session_id and a single clarifying question; resolves to a grounded answer after one follow-up | Ambiguity detection precision ≥ 0.80, recall ≥ 0.70 per FR-007; system never asks more than one clarifying question per session |

Out-of-scope questions are intentionally included to stress-test the system's ability to recognize the boundaries of its knowledge and refuse gracefully rather than hallucinate. The golden dataset shall contain a minimum of 50 questions (target: 100): at least 35 in-scope, 10 out-of-scope, and 5 ambiguous.

**Phase 0-B — During Build (Reference-Free Evaluation):** As the system is built, the RAGAS evaluation pipeline will be run in reference-free mode against the in-scope question set. This measures Faithfulness and Answer Relevancy without requiring a ground truth answer key, giving the team continuous, objective signal throughout development. Out-of-scope questions will be evaluated separately by checking that the system returns the hard refusal response.

**Phase 3 — Final Validation (Full Evaluation + Style Preference):** Before the MVP is considered complete, Phase 3 runs two parallel evaluation tracks:

**Track A — Correctness Verification:** For in-scope golden dataset questions that map to entries in the *Concise Answers* book, the system's answers are verified for factual consistency against the canonical source. The RAGAS pipeline is run in full reference-based mode using the *Concise Answers* content as the ground truth, producing Context Precision and Context Recall scores alongside the reference-free metrics from Phase 0-B.

**Track B — Answer Style Preference Collection:** Each golden dataset query is run through two answer style prompts to produce two responses:

| Style | Description |
|---|---|
| **Style A — Book-Faithful** | Mirrors the tone of the *Concise Answers* book: direct, canonical, FAQ-style as the authors wrote it. |
| **Style B — Coaching-Oriented** | Synthesized across the corpus with an action-oriented, explanatory tone designed for busy educators seeking practical next steps. |

Internal testers review both responses per query and record their preference in a structured log capturing: query text, query category (simple fact / complex synthesis / ambiguous), whether the query maps to a *Concise Answers* FAQ entry, both responses, preferred style, correctness assessment (both correct / A only / B only / neither), and optional tester notes.

This is a **data collection exercise, not a pass/fail gate** for MVP. The preference data informs the post-MVP decision on default answer style and system prompt tuning. No minimum preference threshold is prescribed — the goal is to collect enough signal (across the full golden dataset) to make an informed style decision.

**Baseline Comparison Methodology:** To validate the core hypothesis that the RAG service delivers "measurably superior" answers, the same golden dataset of in-scope questions will be submitted to raw GPT-4o without RAG context. The RAGAS Faithfulness and Answer Relevancy scores from the RAG pipeline will be compared against the baseline scores. The RAG pipeline must exceed the baseline on both metrics to confirm the hypothesis. The specific margin of superiority is not prescribed — any statistically meaningful improvement validates the approach.

### 2.4. User Journeys

The MVP serves four distinct user journeys corresponding to the goals in Section 2.1.

**Journey A — Internal Tester Queries the API**
An internal tester on the evaluation team obtains the API endpoint URL and static API key. They submit a POST request to `/api/v1/query` with a PLC question. The system returns a grounded answer with source citations. The tester verifies that the answer is relevant and that citations point to real content. If the query was ambiguous, the tester receives a clarifying question and submits a follow-up. If the query was out of scope, the tester receives the hard refusal response.

**Journey B — Operator Runs the Ingestion Pipeline**
A developer or operator triggers the ingestion pipeline via GitHub Actions. The pipeline processes all source PDFs inside the VPC, parsing portrait pages for structure and routing landscape pages through vision processing. The operator monitors progress through CloudWatch logs. Upon completion, the operator verifies that all books appear in the PostgreSQL metadata store and that vector embeddings are present in Qdrant.

**Journey C — Evaluator Runs the Evaluation Pipeline**
A team member responsible for quality assurance runs the RAGAS evaluation pipeline against the golden dataset. In Phase 0-B, they run reference-free evaluation to get Faithfulness and Answer Relevancy scores and review results to identify underperforming queries. In Phase 3 Track A, they run full reference-based evaluation using the *Concise Answers* book as ground truth. In Phase 3 Track B, they generate both answer styles for each query and record style preferences in the structured preference log. They compare RAG pipeline scores against the baseline LLM scores to validate the core hypothesis.

**Journey D — Operator Runs Pre-Build Corpus Scan**
Before ingestion begins, an operator runs the automated corpus scan script against all source PDFs in S3. The script produces a report showing page counts, landscape page volumes, and text-layer presence per book. The operator reviews the report, flags any books with unexpected characteristics, and documents handling decisions before ingestion proceeds.


## 3. Core Features & Requirements

### 3.1. Ingestion Pipeline

The system's answer quality depends directly on ingestion quality. The ingestion pipeline processes the 25-book corpus into a searchable knowledge base.

**FR-001 — Source Material Processing:** The operator can trigger ingestion of all 25 PLC @ Work® books in PDF format from cloud storage into the vector store and relational metadata database. Test criteria: All 25 books present in both stores; row counts match expected totals.

**FR-002 — Layout-Aware Parsing:** The operator can run layout-aware parsing that classifies each page by orientation (portrait vs. landscape) and text-layer presence, routing pages to the appropriate parser:
- **Portrait pages with text layers** are parsed for hierarchical document structure (headings, sections, paragraphs, lists, tables).
- **Landscape pages** (reproducibles and worksheets) are processed by a vision-capable model that generates a structured textual description of the visual content.
- **Pages without text layers** are flagged for manual review.

Test criteria: Portrait pages produce structured chunks with hierarchy preserved; landscape pages produce descriptive text chunks tagged with `chunk_type: reproducible`; flagged pages are logged for review. See Section 6 for the specific tools used in each stage.

**FR-003 — Metadata Capture:** The operator can verify that every chunk of ingested text is stored with a standardized metadata schema capturing: book title, authors, SKU, chapter, section, page number, and content type. Test criteria: 100% of chunks have all required metadata fields populated; spot-check sample confirms accuracy against source PDFs. See the Technical Specification for the full schema definition.

**FR-004 — Pre-Build Corpus Scan:** The operator can run an automated scan of all 25 source PDFs before ingestion to validate key assumptions about the corpus (page counts, landscape page volumes, text-layer presence). Test criteria: Scan report produced for all 25 books; anomalies documented with handling decisions. See Section 10 for full scan requirements.

### 3.2. Query Engine

The query engine handles four distinct query types through a multi-stage process.

**FR-005 — Direct Answer:** The API consumer can submit an unambiguous, in-scope query and receive a grounded, cited answer in a single round trip. Test criteria: The response includes a `success` status with populated `answer` and `sources` fields. Source citations include book title, SKU, page number, and text excerpt.

**FR-006 — Conditional Clarification:** The API consumer can submit any query and receive appropriate routing: a direct `success` answer for clear queries, or a `needs_clarification` response with a single clarifying question for ambiguous queries per FR-007. Test criteria: Ambiguous queries from the labeled test set return `needs_clarification`; clear queries return `success` directly.

**FR-007 — Ambiguity Detection:** The API consumer can rely on a two-part ambiguity test applied to every query: a query is classified as ambiguous if and only if *both* conditions are true: (a) the answer would reference different books, chapters, or concepts depending on interpretation, AND (b) the correct interpretation cannot be determined from the query text alone. A query that is broad but has a single clear answer does not qualify as ambiguous. Ambiguity falls into three categories:

| Category | Description | Example |
|---|---|---|
| **Topic Ambiguity** | The question covers a concept addressed in multiple distinct ways, and the answer differs by interpretation. | *"What does Learning by Doing say about assessment?"* |
| **Scope Ambiguity** | The question is so broad that a direct answer would require guessing which angle to take. | *"Tell me about PLCs."* |
| **Reference Ambiguity** | The question references a term that maps to multiple distinct contexts in the corpus. | *"What does DuFour say about teams?"* |

Test criteria: A labeled subset of the golden dataset with queries tagged as "ambiguous" or "clear" measures ambiguity detection precision and recall. Target: precision >= 0.80, recall >= 0.70.

**FR-008 — One-Question Hard Limit:** The API consumer can complete any query interaction with at most **one** clarifying question per session. If the follow-up remains ambiguous, the system provides the best-interpretation answer with a statement of that interpretation appended (e.g., *"I interpreted your question as being about formative assessment. If you meant something else, please ask again."*). This limit prevents the system from feeling interrogative to busy educators. Test criteria: 100% of multi-turn sessions contain at most one `needs_clarification` response.

**FR-009 — Out-of-Scope Detection:** The API consumer can submit any query and receive a clear boundary signal: a hard refusal for queries outside the PLC @ Work® corpus stating *"I can only answer questions based on the PLC @ Work® book series. This question falls outside that scope."* Test criteria: 100% of out-of-scope golden dataset queries receive the refusal response.

**FR-010 — Dynamic Metadata Filtering:** The API consumer can include metadata references in a query (book title, author name, content type such as "reproducible") and receive results filtered to those criteria. Extractable fields: `book_title`, `authors`, `chunk_type`. If a filtered query returns fewer than three results, the search falls back to unfiltered mode. Test criteria: Metadata-filtered test queries (e.g., "What does Learning by Doing say about..." or "Show me a reproducible for...") return results filtered to the correct book or content type.

### 3.3. Hybrid Search & Re-Ranking

The retrieval mechanism combines semantic and keyword search to maximize the quality of retrieved context.

**FR-011 — Semantic Search:** The API consumer can retrieve content that is conceptually similar to the query via vector embeddings, even when exact words do not match. This is effective for broad, conceptual questions. Test criteria: An ablation test comparing vector-only retrieval RAGAS scores against the full hybrid pipeline shows a minimum average delta of 0.03 on Faithfulness or Answer Relevancy.

**FR-012 — Keyword Search:** The API consumer can retrieve content by exact keyword match, critical for PLC-specific jargon and acronyms (e.g., RTI, SMART goals, guaranteed and viable curriculum). Test criteria: A jargon/acronym test set with expected retrieval results achieves recall >= 0.80 for exact-term queries.

**FR-013 — Re-Ranking:** The API consumer can receive search results that have been scored and re-ordered by a relevance-based re-ranker after both searches complete, with the top results passed to the generation model. Test criteria: An ablation test comparing RAGAS scores with and without re-ranking shows a minimum average improvement of 0.05 on Faithfulness or Answer Relevancy. The number of results surviving re-ranking (top-k) is defined in the Technical Specification.

### 3.4. Evaluation Pipeline

The evaluation pipeline validates system quality against the golden dataset and the baseline comparison defined in Section 2.3.

**FR-014 — Evaluation Pipeline Execution:** The evaluator can run the RAGAS evaluation pipeline against the golden dataset and receive a scored report with Faithfulness, Answer Relevancy, Context Precision, and Context Recall metrics per query. In reference-free mode (Phase 0-B), the pipeline produces Faithfulness and Answer Relevancy scores. In full reference-based mode (Phase 3 Track A), the pipeline additionally produces Context Precision and Context Recall scores using the *Concise Answers* book as ground truth. The evaluator can also run the same golden dataset questions through raw GPT-4o without RAG context and compare the resulting scores against the RAG pipeline scores to validate the core hypothesis. Test criteria: The pipeline produces per-query scores for all golden dataset in-scope questions; aggregate scores meet the thresholds defined in Section 2.3; the baseline comparison report shows RAG pipeline scores alongside raw GPT-4o scores for Faithfulness and Answer Relevancy; the evaluator can identify underperforming queries from the output.


## 4. Data Models & Schema

### 4.1. PostgreSQL Schema

PostgreSQL is the relational metadata store, providing structured lookups and audit logging.

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

> **`conversation_id`:** A UUID v4 generated by the client when a teacher begins a new interaction. Must be sent with every request in the same conversation thread and is echoed back in every response. For MVP, the server logs this field but does not validate it as a UUID — it is accepted as a plain string. This field is the foundation for memory and conversation history in Phase 2 — having it in place from day one ensures clean, threadable data without a future API contract change. **Trade-off acknowledged:** This means the MVP carries a required field that has no server-side enforcement. This is accepted technical debt — the alternative (adding the field later) would require a breaking API contract change for all consumers. See Decision #9 in Section 11.

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


### 5.8. Flow D — Metadata-Filtered Query

When the query references a specific book or content type, the system applies metadata filters to narrow the search.

**Request:** `POST /api/v1/query`
```json
{
  "query": "Show me a reproducible for team norms from Learning by Doing",
  "user_id": "user-abc-123",
  "conversation_id": "conv-uuid-1234"
}
```

**Response:** `200 OK`
```json
{
  "status": "success",
  "conversation_id": "conv-uuid-1234",
  "answer": "Here is a reproducible from 'Learning by Doing' that provides a template for establishing team norms...",
  "sources": [
    {
      "book_title": "Learning by Doing: A Handbook for PLCs at Work",
      "sku": "BKF219",
      "page_number": 142,
      "text_excerpt": "...reproducible: Establishing Team Norms — Directions: Each team member should silently..."
    }
  ]
}
```

This flow exercises the dynamic metadata filtering described in FR-010. The system extracts `book_title: "Learning by Doing"` and `chunk_type: "reproducible"` from the query and applies them as filters before retrieval.


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

### 6.1. Ingestion Pipeline Tools

The ingestion pipeline (FR-001 through FR-004) uses a three-stage approach, with each tool chosen for the right job:

| Step | Tool | Role |
|---|---|---|
| 1 | PyMuPDF | Reads every page and classifies it by orientation (portrait vs. landscape) and whether a text layer is present. No content is sent externally at this stage. |
| 2 | llmsherpa (self-hosted) | Handles standard portrait pages. Parses hierarchical structure (headings, sections, paragraphs, lists, tables) without sending proprietary content to any external service. |
| 3 | GPT-4o Vision | Reserved for landscape-oriented pages (reproducibles/worksheets). Renders the page as an image and generates a structured textual description. |

This three-stage design is documented as Decision #3 in the Key Decisions Log (Section 11).

### 6.2. DevOps & Infrastructure

**Infrastructure as Code:** All AWS resources will be defined using Terraform, ensuring the environment is reproducible and version-controlled.

**CI/CD Pipeline:** A GitHub Actions workflow will trigger on every push to `main` to run linters and unit tests, build and tag a Docker image, push the image to Amazon ECR, and trigger a new Fargate deployment.

**Ingestion:** The ingestion pipeline is triggered via GitHub Actions but **all content processing runs inside the VPC** via AWS Systems Manager (SSM) Run Command on the Qdrant EC2 instance. Proprietary book content never passes through GitHub's public runners. See the Technical Specification for the full SSM workflow.

**Networking:** A dedicated VPC with public and private subnets in a **single availability zone** for MVP. The Application Load Balancer resides in the public subnets. All other services (Fargate, RDS, ElastiCache, EC2/Qdrant) reside in the private subnets. A NAT Gateway provides controlled egress for services that call external APIs.

**Secrets Management:** All secrets stored in AWS Secrets Manager. IAM roles with least-privilege permissions govern all service-to-service access. All data encrypted at rest (AWS KMS) and in transit (TLS 1.2+).

**Observability:** For MVP, observability is limited to basic CloudWatch log groups for the Fargate service. Structured JSON audit logs (Section 7.2) are emitted to the same CloudWatch log stream — there is no separate audit log destination for MVP. Full dashboards, metric alarms, and distributed tracing are deferred to a future release.


## 7. Security & Compliance: The Tenant Enclave Foundation

The architecture is **compliant by default**. Even though the MVP only handles proprietary book content with no student data, the security model is ready for future FERPA-constrained data sources.

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

**Audit Logging:** Structured JSON logs capture key events (query received, answer generated) with metadata. These logs are emitted to the CloudWatch log groups described in Section 6.2. Logs are configured to never capture raw PII or student-identifiable content, even in debug mode.


## 8. Non-Functional Requirements

Baseline targets for the MVP, scoped to an internal testing tool with a small user base. All targets are subject to revision when the service is exposed to external users.

**NFR-001 — Response Time:** The API responds to query requests within 30 seconds for the 95th percentile under normal load (1–3 concurrent users). This includes retrieval, re-ranking, and LLM generation time. Measured via request duration monitoring (see Section 6 for tooling).

**NFR-002 — Availability:** The service maintains 95% uptime during business hours (8 AM – 6 PM ET, weekdays). Downtime for deployments during off-hours is acceptable. Measured via health-check monitoring on the load balancer (see Section 6 for tooling).

**NFR-003 — Concurrent Users:** The system supports at least 5 concurrent query requests without degradation beyond NFR-001 thresholds. This reflects the internal testing team size. Verified via a load test script that submits 5 concurrent requests and confirms all responses meet NFR-001 response time thresholds.

**NFR-004 — Data Encryption:** All data is encrypted in transit (TLS 1.2+) and at rest via a managed encryption key service. No exceptions. Verified via infrastructure audit (see Section 6 for tooling).

**NFR-005 — Audit Log Retention:** Structured JSON audit logs are retained in the centralized log store for a minimum of 90 days. Logs never contain raw PII or student-identifiable content, even in debug mode. Verified via code review of all log emission points confirming no PII fields are logged, and a spot-check of production log samples during acceptance testing. See Section 6 for tooling.

**NFR-006 — Backup & Recovery:** Relational database automated backups are enabled with a 7-day retention period. Vector store data can be reconstructed by re-running the ingestion pipeline from source PDFs in cloud storage. RTO: 4 hours. RPO: 24 hours. Verified via a pre-launch recovery drill: restore the relational database from backup and re-run the ingestion pipeline to reconstruct the vector store, confirming both complete within the RTO window. See Section 6 for tooling.

**NFR-007 — Security Scanning:** Container images are scanned for known vulnerabilities before deployment. Critical and high-severity CVEs must be resolved before production deployment. Verified via an automated scan step in the CI/CD pipeline (Section 6.2) that fails the build if critical or high-severity CVEs are detected.


## 9. Acceptance Criteria


The MVP will be considered complete when all of the following criteria are met:

1. All Zone A infrastructure described in Section 7.1 is provisioned in an AWS account using Terraform. The infrastructure for Zones B and C is defined as commented-out code with documented intent.

2. A CI/CD pipeline (GitHub Actions) is in place to automatically build, test, and deploy changes to the Fargate service.

3. The pre-build corpus scan (Section 10) has been completed and its findings reviewed and signed off before ingestion begins.

4. The golden dataset (Section 2.3) has been assembled from the scraped question bank, categorized into in-scope and out-of-scope questions, and checked into the repository.

5. The ingestion pipeline successfully processes all 25 source PDFs from the S3 bucket into the Qdrant vector store and the PostgreSQL metadata database.

6. The `POST /api/v1/query` endpoint is live and accessible via the public ALB URL, protected by a static API key in the `X-API-Key` header.

7. The endpoint correctly implements the **conditional** clarification loop: returning a direct `success` response for clear queries and a `needs_clarification` response with a valid `session_id` for ambiguous queries. The clarification loop must trigger only on queries that meet the two-part ambiguity test defined in Section 3.2.

8. When a clarification follow-up is itself ambiguous, the system answers using its best interpretation and appends a statement of that interpretation to the response. The system never asks more than one clarifying question per session.

9. The endpoint correctly returns an `out_of_scope` hard refusal response for all out-of-scope test queries in the golden dataset. The refusal rate must be 100% for this category.

10. The RAGAS evaluation pipeline is functional and produces Faithfulness and Answer Relevancy scores in reference-free mode against the in-scope golden dataset.

11. In-scope queries meet the RAGAS thresholds defined in Section 2.3: Faithfulness ≥ 0.80, Answer Relevancy ≥ 0.75, Context Precision ≥ 0.70, Context Recall ≥ 0.70. Phase 3 Track A validates these scores in full reference-based mode using the *Concise Answers to Frequently Asked Questions* book as the built-in ground truth — no separately authored expert answer key is required.

12. A query for a known in-scope topic returns a grounded answer that (a) is factually consistent with the cited source passages, (b) does not introduce claims absent from the retrieved context, and (c) includes accurate source citations (book title, SKU, page number, and text excerpt that can be verified against the source PDF).

13. A query for a reproducible correctly uses the `chunk_type` filter and returns relevant results derived from the vision-processed landscape pages.

14. The RAG pipeline's RAGAS Faithfulness and Answer Relevancy scores on the in-scope golden dataset exceed the baseline scores from raw GPT-4o (without RAG context) on the same questions. Any statistically meaningful improvement validates the core hypothesis (Section 2.3, Baseline Comparison Methodology).

15. Style preference data has been collected across the full golden dataset as described in Phase 3 Track B (Section 2.3). Both answer styles (Book-Faithful and Coaching-Oriented) have been generated for each query, and tester preferences are recorded in the structured preference log.


## 10. Pre-Build Corpus Analysis

Before application coding begins, a lightweight automated scan of the 25-book corpus must be performed and its findings reviewed. This scan de-risks the build by validating key assumptions about the corpus before the ingestion pipeline is written.

### 10.1. Scan Requirements

The pre-build scan must produce the following data for each book:

| Metric | Purpose |
|---|---|
| Total page count | Validates cost and time estimates for ingestion |
| Landscape page count | Determines the volume of GPT-4o Vision calls required |
| Text-layer presence per page | Identifies scanned/image-only pages that cannot be parsed by llmsherpa and may require special handling |
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
| #11 | *Concise Answers to Frequently Asked Questions* book as built-in ground truth | The corpus already includes a book of canonical, author-written answers to common PLC questions. Using it as the ground truth for Phase 3 correctness verification eliminates the need for a separately authored expert answer key, reducing cost and dependency on external subject-matter experts while ensuring answers are validated against the authors' own words. |
