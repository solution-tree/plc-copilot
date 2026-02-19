# One-Shot PRD: PLC Coach Service (MVP)

**Document Purpose:** This Product Requirements Document (PRD) provides a complete, self-contained specification for building the Minimum Viable Product (MVP) of the PLC Coach Service. It is designed to be handed to an engineering team to implement from a new, empty repository without requiring additional context.

**Author:** Manus AI
**Version:** 2.0 (Implementation-Ready)
**Date:** February 19, 2026

---

## 1. Vision & Strategic Context

The **PLC Coach Service** is an AI-powered assistant designed to provide educators with immediate, expert guidance grounded in the principles of Professional Learning Communities (PLCs). The core business problem is that educators lack the time to find specific, actionable answers within the dense corpus of PLC literature. This service will bridge that gap by providing a conversational API to a curated library of PLC books, delivering precise, context-aware answers that help educators improve their practice.

The **long-term vision** is a comprehensive coaching ecosystem that can securely incorporate local context, such as meeting transcripts and student data, to provide personalized, FERPA-compliant guidance. The MVP is the critical first step: proving that a high-quality, book-only RAG service can deliver significant value and build a foundation of trust with users.

## 2. MVP Goals & Scope

The primary goal of the MVP is to **validate the core hypothesis**: that a well-designed RAG service, limited to a high-quality corpus, can provide more useful and accurate answers to real-world educator questions than a general-purpose chatbot.

### 2.1. Key Goals

*   **Deploy a Live Service:** Launch a functional, publicly accessible API endpoint (`/query`) for the PLC Coach service, hosted on AWS.
*   **Validate Answer Quality:** Enable testing of the service with a small group of 5-10 internal users to confirm that the answers are accurate, relevant, and grounded in the source material.
*   **Establish Architectural Foundation:** Implement a secure, scalable architecture that is prepared for future enhancements, including the ingestion of sensitive student data, even though these features are not in the MVP.

### 2.2. Non-Goals (Explicitly Out of Scope for MVP)

*   **No User Interface (UI):** The MVP is a backend service only. It will be accessed via its API.
*   **No User Authentication:** The API endpoint will be open for internal testing. Authentication and user management are deferred to a future release.
*   **No Web Search:** The service will only answer questions based on the ingested PLC book corpus.
*   **No Student Data:** The MVP will not ingest or process any meeting transcripts, notes, or student-identifiable information.
*   **No Performance Optimization:** The focus is on quality and architectural correctness, not response time or cost-per-query optimization.
*   **No Formal Evaluation Framework:** The 50-100 question benchmark and automated RAG evaluation are deferred. MVP success will be judged qualitatively by the internal testing group.

## 3. Core Features & Requirements

### 3.1. High-Quality Ingestion Pipeline

The service's quality is entirely dependent on the quality of the ingestion process. The MVP will implement a sophisticated, asynchronous ingestion pipeline.

*   **Source Material:** The initial corpus consists of approximately 25 proprietary PLC books in PDF format. These will be stored in a private **AWS S3 bucket**.
*   **Layout-Aware Parsing:** The ingestion service will use a **self-hosted `llmsherpa` service** running within the VPC to parse PDFs. This preserves the document's hierarchical structure (headings, sections, lists, tables) without sending proprietary content to an external service.
*   **Vision-Enabled Reproducibles:** For landscape-oriented pages identified as "reproducibles" or worksheets, the service will render the page as an image and use **GPT-4o Vision** to generate a detailed, structured Markdown description. This ensures the content of these critical visual assets is fully captured.
*   **Rich Metadata:** Every chunk of ingested text will be stored as a `TextNode` with a standardized metadata schema. See Section 4.1 for the full schema.

### 3.2. Conversational Query Engine

The query engine is designed to be interactive and context-aware, ensuring it fully understands the user's intent before providing an answer.

*   **Dynamic Metadata Filtering:** Before performing a vector search, the service will use a GPT-4o call to analyze the user's query and extract potential metadata filters (e.g., a specific book title, author, or a request for a `reproducible`). These filters will be used to narrow the search to the most relevant chunks.
*   **Smart Fallback:** If a filtered query returns fewer than three results, the service will automatically fall back to an unfiltered search to ensure a robust response.
*   **Mandatory Clarification Loop:** To enhance context and improve answer quality, every initial query will trigger a follow-up question. The API will manage this via a session-based, two-step interaction. See Section 5 for the API contract.

## 4. Data Models & Schema

### 4.1. Vector Node Metadata Schema

Every `TextNode` stored in the Qdrant vector database must include the following metadata fields. This will be implemented using Python's `TypedDict` for strong typing.

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
```

## 5. API Specification

The service will expose a single `POST /query` endpoint.

### 5.1. Session-Based Clarification Flow

**Step 1: Initial Query**

The client sends the user's initial question.

*   **Request:** `POST /query`

    ```json
    {
      "query": "What does Learning by Doing say about assessment?"
    }
    ```

*   **Response:** `200 OK`

    The service returns a clarifying question and a `session_id`.

    ```json
    {
      "status": "needs_clarification",
      "session_id": "uuid-goes-here-1234",
      "clarification_question": "Are you asking about formative or summative assessment, or the role of assessment in a guaranteed and viable curriculum?"
    }
    ```

**Step 2: Follow-up with Clarification**

The client sends the user's answer to the clarification question, including the `session_id`.

*   **Request:** `POST /query`

    ```json
    {
      "session_id": "uuid-goes-here-1234",
      "query": "formative assessment"
    }
    ```

*   **Response:** `200 OK`

    The service returns the final, synthesized answer and source citations.

    ```json
    {
      "status": "success",
      "session_id": "uuid-goes-here-1234",
      "answer": "In 'Learning by Doing', the authors emphasize that formative assessment is a continuous process used by teams to monitor student learning on an ongoing basis...",
      "sources": [
        {
          "book_title": "Learning by Doing: A Handbook for PLCs at Work",
          "authors": ["Richard DuFour", "Rebecca DuFour", "Robert Eaker", "Thomas W. Many"],
          "sku": "BKF219",
          "page_number": 87,
          "excerpt": "...the team uses common formative assessments to gather evidence of student learning..."
        }
      ]
    }
    ```

## 6. Architecture & Technology Stack

The MVP will be built on AWS, using a hybrid of managed and self-hosted services to balance security, cost, and operational simplicity.

| Component | Technology | Hosting Model | Rationale & MVP Scope |
| :--- | :--- | :--- | :--- |
| **Application Framework** | Python 3.11+ with FastAPI & Pydantic | N/A | Modern, high-performance async framework with strong data validation. |
| **Compute (API & Services)** | Docker Containers on **AWS Fargate** | Managed | For MVP, the API, PDF Parser, and Ingestion Worker will run as separate, **single-task** services for isolation and cost-effectiveness. |
| **Vector Database** | Qdrant | **Self-Hosted on EC2** | A single `t4g.medium` instance in a private VPC to ensure vector embeddings of proprietary content never leave our direct control. |
| **PDF Parsing Service** | `llmsherpa/nlm-ingestor` | **Self-Hosted on Fargate** | A containerized service within our VPC to prevent sending raw PDF content to any third party. |
| **Relational Database** | PostgreSQL 15+ | **Amazon RDS** (Managed) | Reliable, low-maintenance storage for session state and audit logs. |
| **Session Cache** | Redis 7+ | **Amazon ElastiCache** (Managed) | Manages the state of the two-step conversational clarification loop. |
| **File Storage (Corpus)** | N/A | **Amazon S3** (Managed) | Source PDFs will be stored in a private S3 bucket with versioning enabled. |
| **LLM & Embeddings** | GPT-4o, `text-embedding-3-large` | **OpenAI API** (External) | All usage will be through enterprise-grade, zero-retention endpoints, governed by an executed DPA. |

## 7. Security & Compliance: The Tenant Enclave Foundation

While the MVP does not handle student data, its architecture will be built upon a **Tenant Enclave** model to ensure it is ready for future, FERPA-constrained requirements. This involves logically separating data into three distinct zones with strict access controls.

*   **Zone A: Content Zone (MVP Scope):** Contains the PLC book corpus. This is the only zone implemented in the MVP.
*   **Zone B: Meeting/Transcript Zone (Future):** Will contain sensitive but de-identified meeting and transcript data.
*   **Zone C: Identity/Student Directory Zone (Future):** Will contain the highly restricted mapping between student names and anonymized tokens.

This architectural principle must be reflected in the infrastructure setup (e.g., IAM roles, security groups) from day one.

## 8. Acceptance Criteria

The MVP will be considered complete when the following criteria are met:

1.  All infrastructure described in Section 6 is provisioned in an AWS account using Terraform.
2.  A CI/CD pipeline (GitHub Actions) is in place to automatically build, test, and deploy changes to the Fargate services.
3.  The ingestion pipeline can be triggered to successfully process all 25 source PDFs from the S3 bucket into the Qdrant vector store.
4.  The `/query` endpoint is live and accessible via a public URL.
5.  The endpoint correctly implements the two-step clarification loop, returning a `needs_clarification` status on the first call and a `success` status on the second call with a valid `session_id`.
6.  A query for a known topic returns a coherent, grounded answer with accurate source citations.
7.  A query for a reproducible (e.g., "find reproducibles about assessment") correctly uses the `chunk_type` filter and returns relevant results derived from the vision-processed landscape pages.
