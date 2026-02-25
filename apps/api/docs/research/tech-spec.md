# PLC Copilot - Technical Specification v1.0

---

## Part 1: Introduction

### **Front Matter**

- **Author:** Nani

- **Team:** Solution Tree - Senior Software Engineers

- **Status:** Draft

- **Date:** February 20, 2026

### **Background**

#### **The Immediate Problem (MVP Scope)**

Educators implementing Professional Learning Communities need quick, accurate answers to specific PLC questions during their planning and collaboration work. Currently, they must manually search through 25 dense books from Solution Tree's PLC @ Work® series or rely on general-purpose chatbots that aren't grounded in the specific PLC methodology and may provide inaccurate or generic advice.

This creates a practical barrier: teachers don't have time to find the right answer in the right book when they need it, and generic AI tools can't provide the fidelity required for high-quality PLC implementation.

**The MVP Goal:** Validate that a well-designed RAG service, limited to a high-quality corpus of PLC books, can provide more useful, accurate, and properly-cited answers to real-world educator questions than a general-purpose chatbot.

#### **Strategic Context: The Bigger Picture (Future Vision)**

This MVP is Phase 1 of the **PLC Copilot Platform**, which will eventually digitize PLC workflows, incorporate local context (meeting transcripts, student data), and provide team-based coaching to close the knowing-doing gap in PLC implementation. See the BrainLift Platform Strategy document for the full long-term vision.

This strategic context explains certain architectural decisions in the MVP (such as the Tenant Enclave security model and FERPA-ready infrastructure) that may seem over-engineered for a book-only service but are essential preparation for future phases involving sensitive educational data.

### **Current Functionality**

This is a new system being built from scratch. There is no existing technical solution for providing AI-driven, book-grounded answers to PLC implementation questions. Educators currently rely on manual searching, general-purpose AI chatbots, or sporadic access to human consultants.

### **Justification**

The primary justification for this MVP is to validate the core technical hypothesis that a domain-specific RAG service can provide more accurate, trustworthy, and useful answers for PLC educators than a general-purpose LLM. This project serves as the foundational "brain" for the future PLC Copilot platform.

#### **Goals (What We Will Achieve)**

1. **Build a Functioning RAG Pipeline:** Construct an end-to-end RAG system.

1. **Achieve Factual Accuracy and Traceability:** Ensure answers are grounded and cited.

1. **Validate Superiority over General LLMs:** Prove better performance through a quantitative evaluation framework.

1. **Establish Core Infrastructure:** Deploy a scalable and secure backbone for future features.

#### **Non-Goals (What We Will NOT Achieve in this MVP)**

1. **Solve the Entire "Knowing-Doing Gap":** No workflow automation or team collaboration features.

1. **Achieve Perfect, Human-Like Conversation:** The focus is on accuracy and traceability, not personality.

1. **Onboard Live Users:** This MVP is for internal testing and validation only.

1. **Incorporate Multi-Modal Data:** Scope is limited to the 25 PDF books.

### **Scope**

#### **In Scope**

1. **Data Corpus:** The 25 provided PDF books from Solution Tree's PLC @ Work® series.

1. **Ingestion Pipeline:** PDF Parsing, Semantic Chunking, Embedding, and Storage in Qdrant/PostgreSQL.

1. **Core RAG API:** A single, stateless `POST /api/v1/query` endpoint.

1. **Query Processing Logic:** Hybrid Search, Re-ranking, and Generation with GPT-4o.

1. **Infrastructure:** AWS deployment with Redis caching and a basic CI/CD pipeline.

1. **Evaluation Framework:** A test suite of 50-100 questions and an automated evaluation pipeline using RAGAS.

#### **Out of Scope**

1. **User Interface (UI):** No front-end will be developed.

1. **User Authentication:** The API will be for internal use with a static API key.

1. **Multi-turn Conversational Memory:** The API will be stateless.

1. **Workflow Integration:** No integration with external tools.

1. **Additional Data Sources:** No video, audio, or web content.

1. **Model Fine-Tuning:** This is a post-MVP task.

---

## Part 2: System Architecture

### **Ingestion Pipeline (Batch Process)**

```
[25 PDF Books]
      |
      v
[1. PDF Parser (PyMuPDF+llmsherpa+GPT-4o)]
      |
      v
[2. Semantic Chunker]
      |
      v
[3. Embedding Model (OpenAI)]
      |
      +--------------------+--------------------+
      |                    |
      v                    v
[4. Vector DB (Qdrant)]: # "[5. Metadata DB (PostgreSQL)]"
```

### **Query Pipeline (Real-time API Call)**

```
[User Query]
      |
      v
[1. Embedding Model (OpenAI)]
      |
      v
[2. Hybrid Search (Qdrant)]
      |
      v
[3. Re-ranker Model]
      |
      v
[4. Context Builder]
      |
      v
[5. Generation Model (GPT-4o)]
      |
      v
[Final Answer + Citations]
```

---

## Part 3: Detailed Design

### **API Contract: ****`POST /api/v1/query`**

- **Request:** `{"query": "...", "user_id": "..."}`

- **Response:** `{"answer": "...", "sources": [...]}`
  - Each source object will contain `book_title`, `sku`, `page_number`, and `text_excerpt`.

### **PostgreSQL Schema**

- **`books`**** table:** `id`, `sku`, `title`, `authors`.

- **`chunks`**** table:** `id`, `book_id`, `qdrant_id`, `text_content`, `page_number`, `chunk_type`, `chapter`, `section`.

### **Qdrant Schema**

- **Collection:** `plc_copilot_v1`

- **Vector:** 3,072 dimensions from `text-embedding-3-large`.

- **Payload:** `book_sku`, `chunk_type`, `page_number` for fast filtering.

---

## Part 4: Operational Concerns

- **Security:** API protected by a static API key. Data encrypted in transit (TLS 1.2+) and at rest. Architecture will follow the FERPA-ready Tenant Enclave design pattern, deployed as a single instance for the MVP.

- **Logging:** Structured JSON logs for every API request, capturing `user_id`, `query_text`, `retrieved_chunk_ids`, `final_answer_text`, `latency_ms`, and `was_cached`.

- **Monitoring:** Real-time dashboard tracking API Request Rate, Error Rate, P95 Latency, and Cache Hit Rate.

- **Cost Estimation:** Costs are broken down into fixed Cloud Infrastructure (~$200-500/mo) and variable AI Service costs (OpenAI). An action item is to calculate the one-time embedding cost for the corpus.

---

## Part 5: Testing and Validation

- **Software Testing:** Comprehensive unit, integration, and API contract tests.

- **RAG Evaluation Framework:** An automated pipeline using RAGAS to score the system on Faithfulness, Answer Relevancy, and Context Precision against a manually created golden dataset of 50-100 questions.

---

## Part 6: Risks and Mitigation

| Risk ID | Risk Description | Mitigation Strategy |
| --- | --- | --- |
| R-01 | Poor Answer Quality | RAG Evaluation Framework, Prompt Engineering. |
| R-02 | High Operational Costs | Cost Monitoring, Cost Calculation, Model Benchmarking. |
| R-03 | Ineffective Retrieval | Hybrid Search, Re-ranker Model, Semantic Chunking. |
| R-04 | Technical Complexity | Phased Implementation, Managed Services. |

---

## Part 7: Alternatives

| Component | Chosen Approach | Justification for Rejection of Alternatives |
| --- | --- | --- |
| PDF Parsing | Hybrid Model | `unstructured` is less specialized; `PyMuPDF` only requires too much custom code. |
| Chunking | Hybrid Semantic | Fixed-size chunking produces lower-quality context. |
| Embedding | `text-embedding-3-large` | `small` model is cheaper but poses a quality risk for an expert system. |
| Vector DB | `Qdrant` (Self-hosted) | `FAISS` is not production-ready; managed services reduce data control. |
| Architecture | FERPA-Ready Enclave | Simple single-tenant design is prohibitively expensive to refactor later. |
| Retrieval | Hybrid Search + Re-ranker | Simple vector search (used in the original system) provides lower-quality context. |

---

## Part 8: Work Breakdown

- **Total Estimated Effort:** 32 engineer-days.

- **Phases:** 1. Setup & Ingestion, 2. API & Query Pipeline, 3. Testing & Validation, 4. Deployment.

---

## Part 9: Future Considerations

- **F-01:** Workflow Integration (The "Body")

- **F-02:** Multi-Modal Data Ingestion (Videos, Audio)

- **F-03:** Conversational Memory (Stateful API)

- **F-04:** Model Fine-Tuning

- **F-05:** Full Multi-Tenancy Deployment

- **F-06:** User-Facing Analytics Dashboard

---

## Part 10: Appendices

- **Appendix A:** Glossary of Terms

- **Appendix B:** Key Research Documents

- **Appendix C:** Full List of Corpus Books

