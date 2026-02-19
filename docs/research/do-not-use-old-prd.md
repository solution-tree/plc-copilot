# Product Requirements Document: PLC Coach

**Version**: 3.0
**Date**: February 11, 2026 12:50 PM MST
**Owner**: vanes

---

## 1. Project Scope & Rollout Strategy

This document outlines the product and technical requirements for PLC Coach, an intelligent Retrieval-Augmented Generation (RAG) service designed to provide accurate, context-aware answers to questions based on a proprietary corpus of 25 educational books. The service will be used by teachers and school administrators within Professional Learning Community (PLC) schools and must adhere to strict data privacy and security requirements, including FERPA compliance.

**Key Innovation**: PLC Coach will implement a **validation-first approach** to determine the optimal architecture for handling questions that require reasoning beyond direct retrieval. The MVP will test the LLM's ability to reason from the existing corpus, and the results will inform whether to adopt a **Three-Tier Routing Model** or a **Knowledge Base Expansion Model**.

### 1.1. Rollout Phases

The project will be delivered in four phases, aligned with Solution Tree's official release stages:

| Phase | Description | User Base | Success Criteria |  
|---|---|---|---|  
| **MVP (Baseline Release)** | Internal testing with core RAG functionality. **Primary goal is to validate the feasibility of the Reasoned Answer tier.** | Internal team (5-10 testers) | **Validate Tier 2 (Reasoned Answer) feasibility.** Create benchmark of 50-100 real-world teacher questions requiring reasoning. **Success = >70% of benchmark questions receive helpful, grounded answers from corpus alone.** |  
| **Alpha** | Internal testing at Solution Tree with added authentication and a defined architectural path based on MVP results. | Solution Tree internal users | Implement full routing logic based on MVP results. If MVP reasoning succeeds: build confidence-based routing and **implement web search fallback**. Google SSO implemented and validated. |  
| **Beta** | Pilot rollout to selected schools. Evaluate and optimize based on real usage. | 6-18 pilot schools (~120-360 teachers) | Positive user feedback, system stability under real load, fallback rate < 20% (if implemented). |  
| **Production** | Full rollout to Model Schools with potential expansion. | ~600 Model Schools (~12,000 teachers) | High user adoption, cost-effective operations, meets all compliance requirements. |

### 1.2. Feature Rollout by Phase

| Feature/Capability | MVP | Alpha | Beta | Production |  
|---|---|---|---|---|  
| **Core RAG Pipeline** | Implemented | Implemented | Implemented | Implemented |  
| **Reasoning Layer** | Optimized | Production-optimized | Production-optimized | Production-optimized |  
| **Web Search Fallback** | **Conditional** | Optimized |  
| **User Authentication** | None | Google SSO | Full SSO |
| **Role-Based Access Control** | Basic RBAC | Full RBAC + Audit |  
| **Simple Frontend** | Basic UI |  |  
| **Answer Caching** | 30-day cache | Optimized |  
| **Vector Database** | Qdrant | Managed Service |  
| **Infrastructure** | Single EC2 | Auto-scaling |

---

## 2. Functional Requirements

This section defines the core functionality of PLC Coach.

### 2.1. Query Pre-processing

Before retrieval, all incoming user queries will undergo a pre-processing step to improve accuracy and robustness. This step will include:

- **Spelling Correction**: Automatically correct common spelling errors.
- **Query Expansion**: Expand abbreviations and synonyms to improve retrieval recall. For example, "PLC" will be expanded to also search for "Professional Learning Community", and domain-specific abbreviations will be similarly expanded to improve retrieval accuracy.

### 2.2. Retrieval Strategy

The system will retrieve the top 10 most semantically similar text chunks from the vector database to use as context for answer generation. There will be no diversity constraint, meaning all 10 chunks can come from the same book if that book is the most relevant.

### 2.3. Answer Generation: A Validation-First Approach

The MVP will test the hypothesis: *Is the existing 25-book corpus sufficient for the LLM to generate useful, reasoned answers?* The results determine the architectural path for the Alpha phase and beyond.

#### Path A: Three-Tier Routing Model (If MVP Validation Succeeds)

| Tier | Name | Description | Trigger / Confidence |  
|---|---|---|---|  
| 1 | **Direct Answer** | Explicitly answered in source texts. | High Confidence (> 0.8) |  
| 2 | **Reasoned Answer** | Synthesizing principles from source texts. | Medium Confidence (0.5 - 0.8) |  
| 3 | **Supplemented Answer** | Outside the scope of the corpus. | Low Confidence (< 0.5) |

#### Path B: Knowledge Base Expansion Model (If MVP Validation Fails)

1.  **Analyze Failures**: Identify the types of questions where reasoning fails.  
2.  **Enrich the Corpus**: Source and add new content with explicit examples of principles being applied.  
3.  **Re-Validate**: Re-run the benchmark against the enriched corpus.  
4.  **Implement Simple Fallback**: Once the corpus is robust, implement a simpler confidence-based fallback to web search.

**Hybrid Mode Prompt (Alpha):**
```
You are an expert PLC coach. Answer the question using BOTH sources below.
Prioritize information from the books, but use web sources for additional context.

Books (PRIMARY):
{book_chunks}

Web (SUPPLEMENTARY):
{web_results}

Question: {query}

Instructions:
- Prioritize book sources
- Cite book sources as [Book Title: "Title", Product #XXXXX, Page XX]
- Cite web sources as [Source: URL]
- Clearly indicate when using web sources
```

### 2.4. Source Attribution

All generated answers will include source attribution to ensure transparency and allow users to verify the information.

**Book Sources (Corpus-First Mode):**
`[Book Title: "Title", Product #XXXXX, Page XX]`

**Web Sources (Hybrid Mode - Alpha and beyond):**
`[Source: URL]` or `[Source: Website Name - URL]`

**Answer Mode Indicator:**
- `corpus_first`: Answer generated from books only (primary mode)
- `hybrid`: Answer includes external web sources (fallback mode)

### 2.5. Corpus-First Strategy and Error Handling

**MVP (Corpus-Only Mode):**
If an answer cannot be found within the 25-book corpus, the API will return a helpful message.

**Alpha and beyond (Hybrid Mode with Fallback):**
- **High Confidence (>0.7)**: Answer from books only (corpus-first mode)
- **Low Confidence (<0.7)**: Automatic fallback to web search (hybrid mode)

### 2.6. Audit Logging

Comprehensive audit logging will be implemented for observability, debugging, and compliance. The following events will be logged for each query:

- Query received (timestamp, user_id, query_text_redacted)
- Query pre-processing results (original vs. processed)
- Chunks retrieved (chunk_ids, similarity_scores, source_books)
- Answer generated (response_text, sources_used, word_count)
- LLM token usage (prompt_tokens, completion_tokens, total_cost)
- Response time metrics (retrieval_time_ms, generation_time_ms, total_time_ms)
- Errors/failures (error_type, error_message, stack_trace)

**PII Protection (Alpha and beyond):**
- Student names and other PII detected in queries will be redacted before logging.
- The original query is sent to OpenAI for processing but not retained per zero-retention configuration.
- A SHA-256 hash of the original query will be stored for debugging and traceability.

---

## 3. Non-Functional Requirements

| Requirement | MVP (Baseline) | Alpha | Beta | Production |
|---|---|---|---|---|
| **P95 Latency** | < 3 seconds | < 3 seconds | < 3 seconds | < 2 seconds |
| **P99 Latency** | < 5 seconds | < 5 seconds | < 5 seconds | < 3 seconds |
| **Query Volume** | ~1 QPS (internal) | ~1 QPS (internal) | ~1-2 QPS peak | 10x Beta load |
| **Uptime** | Best effort | 99.5% | 99.9% | 99.95% |

---

## 4. Data Requirements

- **Corpus**: 25 digitally-native PDFs
- **Language**: English only
- **Page Count**: Average 228, max 432
- **Page Numbers**: PDF page numbers DO NOT match printed page numbers
- **Identifier**: Unique product number per book (from external spreadsheet)

---

## 5. API Design & Versioning

### 5.1. Semantic Versioning

 - **MVP**: 0.1.0   
 - **Alpha**: 0.2.0-alpha   
 - **Beta**: 0.3.0-beta   
 - **Production**: 1.0.0 

### 5.2. Request/Response Schema

 **Request:** POST /api/v1/query   
 ```json
{
 "query": "What are best practices for PLC implementation?"
}
```  

**Success Response:**  
 ```json
{
 "answer": "The best practices for...",
 "mode": "reasoned_answer",
 "sources": [ { "citation": "[Book Title: ..., Page 47]" } ]
}
```

---

## 6. Infrastructure

| Component | MVP | Alpha | Beta | Production |  
|---|---|---|---|---|  
| **Compute** | Single EC2 | Single EC2 | Multi-EC2 + LB | Auto-scaling ECS/Fargate |  
| **Vector Database** | Qdrant (self-hosted) | Qdrant (self-hosted) | Qdrant (self-hosted, HA) | Qdrant (self-hosted, HA) |  
| **LLM** | OpenAI GPT-4 (SDPA) | OpenAI GPT-4 (SDPA) | OpenAI GPT-4 (SDPA) | OpenAI GPT-4 (SDPA) |  
| **Web Search API** | Perplexity (**Conditional**) | Perplexity |  
| **Caching** | Redis | Redis Cluster |  
| **Database** | PostgreSQL (RDS) | PostgreSQL (RDS Multi-AZ) |

---

### 6.1. Infrastructure Rationale and Scaling

**Vector Database Choice: Self-Hosted Qdrant**

The decision to use self-hosted Qdrant indefinitely is based on three factors:
1.  **FERPA Compliance**: Self-hosting keeps all data within the project's AWS environment, simplifying compliance by avoiding the need for additional third-party Data Processing Agreements (DPAs).
2.  **Cost-Effectiveness**: At the projected scale, self-hosting on EC2 is significantly more cost-effective than a managed service.
3.  **Control**: Provides full control over the environment for rapid iteration and customization.

**Scaling to High Availability (HA)**

-   **MVP & Alpha**: A single Qdrant instance is sufficient for internal testing.
-   **Beta & Production**: The system will move to a High Availability (HA) architecture with 2-3 Qdrant instances behind a load balancer. This is necessary to meet the 99.9%+ uptime requirements for a production environment serving a large user base and to eliminate single points of failure. The transition to HA should be triggered when preparing for the Beta pilot rollout.

---

## 12. Appendix

### 12.1. Explanation of the Validation-First Hybrid Approach

- **Phase 1: MVP (Validation)**: We will test the LLM's ability to synthesize and infer from the existing 25-book corpus. This determines if our problem is *architectural* or a *knowledge base* problem.  
- **Phase 2: Alpha (Conditional Implementation)**: Based on MVP results, we will commit to one of two paths:  
   - **If Validation Succeeds**: Build the **Three-Tier Routing Model** and implement web search fallback.  
   - **If Validation Fails**: Adopt the **Knowledge Base Expansion Model**, enriching our corpus before implementing a simpler web fallback.