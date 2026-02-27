---
title: "Architecture Document Errata — Adversarial Review Round 2"
subject: "_bmad-output/planning-artifacts/architecture.md"
date: "2026-02-27"
review-round: 2
status: "PENDING — 15 findings awaiting review"
finding-count: 15
cross-referenced-against:
  - apps/api/docs/prd-v4.md (v4.6)
  - apps/api/docs/research/ferpa-FINAL.md
prior-review: "_bmad-output/planning-artifacts/architecture-errata-2026-02-27.md (Round 1 — 13 findings, all applied)"
---

# Architecture Document Errata — Adversarial Review Round 2

This document records 15 findings from a second adversarial review of the architecture decision document (`_bmad-output/planning-artifacts/architecture.md`), performed after all 13 Round 1 findings were applied. Each finding is cross-referenced against PRD v4.6.

No changes should be applied to architecture.md until this errata is reviewed and approved. Once approved, this document serves as the change specification.

## Summary Table

| Finding | Title | Tier | Impact | Status |
|---|---|---|---|---|
| F2-01 | `user_id` logging contradicts PRD | 1 — Will cause bugs/compliance failures | FR-019 audit logs will be non-compliant | Pending |
| F2-02 | Response caching creates stale `session_id` bug | 1 — Will cause bugs/compliance failures | Ambiguous queries served from cache will always fail on follow-up | Pending |
| F2-03 | Test client cannot authenticate | 1 — Will cause bugs/compliance failures | FR-021 test client cannot call FR-018 protected endpoint | Pending |
| F2-04 | No vulnerability scanning tool or pipeline step | 2 — Missing architecture for required features | NFR-007 has no implementation path | Pending |
| F2-05 | Metadata extraction from queries has no design | 2 — Missing architecture for required features | FR-010 extraction accuracy target (0.90) has no architectural support | Pending |
| F2-06 | BM25 library never named | 2 — Missing architecture for required features | Agents implementing `retrieval/keyword.py` have no tool guidance | Pending |
| F2-07 | No load testing approach | 2 — Missing architecture for required features | NFR-003 has no verification path | Pending |
| F2-08 | Single AZ vs. 95% uptime unanalyzed | 3 — Risk accepted without analysis | NFR-002 may not be achievable | Pending |
| F2-09 | Ingestion competes with Qdrant for resources | 3 — Risk accepted without analysis | API query performance may degrade during ingestion | Pending |
| F2-10 | FR count is wrong in requirements overview | 4 — Gaps that will bite you later | Document says 13 FRs; PRD has 21 | Pending |
| F2-11 | `conversation_id` validation mismatch with PRD | 4 — Gaps that will bite you later | Agent may add UUID validation PRD explicitly excluded | Pending |
| F2-12 | No OpenAI DPA verification step | 4 — Gaps that will bite you later | Compliance dependency has no enforcement mechanism | Pending |
| F2-13 | No embedding model version strategy | 4 — Gaps that will bite you later | Model update silently breaks all existing vectors | Pending |
| F2-14 | Post-ingestion Qdrant snapshot not triggered | 4 — Gaps that will bite you later | Up to 8 hours of ingestion work can be lost | Pending |
| F2-15 | Auth events missing from log event catalog | 4 — Gaps that will bite you later | Agents cannot log auth failures without amending architecture | Pending |

---

## Tier 1 — Will Cause Bugs or Compliance Failures

These will directly break something or produce non-compliant behavior when agents start building. Must be fixed before implementation.

---

### F2-01 — `user_id` Logging Contradicts PRD

**Tier:** 1 — Will cause bugs or compliance failures
**Affected Section:** Implementation Patterns > Logging (line ~489)
**PRD Reference:** Section 7.2, FR-019

**Problem:**

The architecture's logging pattern lists as a forbidden field: "Any PII — no `user_id` content, no query text in production logs, no student names (FERPA)."

The PRD Section 7.2 explicitly requires `user_id` in audit log metadata: "Structured JSON logs capture key events (query received, answer generated) with metadata: Event type, Timestamp, conversation_id, **user_id**." FR-019 repeats this requirement.

The PRD scopes `user_id` as an opaque client-provided string that is "not validated against user store for MVP." It is not PII in the FERPA sense — it is a client-supplied identifier with no link to a real person's identity at this stage.

An agent following the architecture will omit `user_id` from audit logs, causing FR-019's test criteria to fail.

**Proposed Resolution:**

1. In the Logging pattern table, change the "Forbidden fields" row to: "Any PII — no query text in production logs, no student names, no student-identifiable content (FERPA). Note: `user_id` is a required audit log field per PRD Section 7.2 — it is an opaque client-supplied string, not validated PII."
2. In the event catalog, add `user_id` to the "Key Fields" column for `query_received` and `query_completed` events.
3. Add `user_id` to the "Required fields per log entry" row alongside `timestamp`, `level`, `event`, `conversation_id`.

**Verification:** `user_id` appears in required audit log fields and event catalog key fields. Forbidden fields list no longer mentions `user_id`.

---

### F2-02 — Response Caching Creates Stale `session_id` Bug

**Tier:** 1 — Will cause bugs or compliance failures
**Affected Section:** Core Architectural Decisions > Data Architecture > Caching Strategy (line ~148)
**PRD Reference:** Section 5.3 (response schema), FR-006 (clarification flow)

**Problem:**

The architecture defines a 24-hour response cache for identical queries. It does not analyze the interaction with the clarification flow.

If an ambiguous query is submitted and the `needs_clarification` response is cached, a second identical query from a different user (or the same user later) receives the cached response. That cached response contains a `session_id` generated for the *first* request. The corresponding Redis session either:
- Has expired (15-minute TTL), causing the follow-up to return `400 Session expired`
- Belongs to someone else's clarification loop

This means ambiguous queries served from cache will *always* fail on follow-up. The caching strategy has no exclusion rule for non-`success` responses.

**Proposed Resolution:**

Add a caching rule to the Data Architecture section:

1. **Cache scope:** Only cache responses with `status: "success"`. Never cache `needs_clarification` or `out_of_scope` responses.
2. **Rationale:** `needs_clarification` responses contain server-generated `session_id` values bound to a specific session. Caching them would serve stale session references. `out_of_scope` responses are lightweight (no LLM generation cost) and don't benefit from caching.
3. Add this rule to the Process Patterns or Caching Strategy section so agents implementing `cache_service.py` have an explicit contract.

**Verification:** Architecture contains an explicit cache scope rule limiting caching to `success` responses only.

---

### F2-03 — Test Client Cannot Authenticate

**Tier:** 1 — Will cause bugs or compliance failures
**Affected Section:** Minimal Test Client (FR-021) (line ~227)
**PRD Reference:** FR-018 (API key auth), FR-021 (test client)

**Problem:**

The architecture specifies the test client as "single static HTML file with inline CSS and vanilla JavaScript" and explicitly says "No auth UI" (line 236). It also specifies that every API call requires `X-API-Key` in the request header (FR-018).

These two decisions are incompatible. The test client's JavaScript must include the API key in its fetch/XHR calls to `POST /api/v1/query`. The architecture provides no guidance on how the key reaches the client-side code.

**Proposed Resolution:**

Add an authentication approach to the test client specification:

1. **Recommended approach:** The test client HTML page includes a text input field for the API key (pre-populated from a non-sensitive default or left blank). The key is stored in the browser's `sessionStorage` for the duration of the tab and included in the `X-API-Key` header on every request. The key is never persisted to `localStorage` or cookies.
2. **Alternative considered:** Hardcoding the key in the HTML. Rejected — the HTML ships inside the Docker image and the key would be visible in the image layer. Even for internal testing, baking secrets into artifacts is bad practice.
3. **Alternative considered:** Exempting `/api/v1/query` from auth when called from the test client page. Rejected — creates a bypass that could be exploited and complicates the auth middleware.
4. Update the test client scope line to: "No auth *management* UI — API key entry is a simple text field, not a login flow."

**Verification:** Architecture contains a test client authentication approach that is compatible with FR-018.

---

## Tier 2 — Missing Architecture for Required Features

These are PRD requirements where the architecture provides no guidance. Agents will guess (inconsistently) or block. Should be resolved before implementation reaches these features.

---

### F2-04 — No Vulnerability Scanning Tool or Pipeline Step

**Tier:** 2 — Missing architecture for required features
**Affected Section:** Infrastructure & Deployment > CI/CD Pipeline (line ~170)
**PRD Reference:** NFR-007

**Problem:**

NFR-007 requires: "Container images scanned for known vulnerabilities before deployment. Critical and high-severity CVEs must be resolved before production deployment. Verified via automated scan step in CI/CD pipeline that fails build if critical/high-severity CVEs detected."

The architecture's CI/CD pipeline description lists: "PR → ruff + mypy + pytest; merge to main → build Docker → push ECR → deploy Fargate." There is no scanning step. No scanning tool is named. No blocking mechanism is defined.

**Proposed Resolution:**

Add a container scanning decision to the CI/CD pipeline section:

1. **Tool:** Trivy (open source, widely adopted, runs in GitHub Actions natively, scans Docker images for OS and language-level CVEs).
2. **Pipeline placement:** After Docker image build, before ECR push. Scan step runs `trivy image --severity CRITICAL,HIGH --exit-code 1` against the built image. Non-zero exit code fails the pipeline and blocks deployment.
3. **Alternative considered:** ECR native scanning (Basic or Enhanced). Rejected for pipeline integration — ECR scanning is asynchronous and requires polling, adding complexity to the GitHub Actions workflow. Trivy runs synchronously in the same job.
4. **Alternative considered:** Grype (Anchore). Viable but smaller community and fewer GitHub Actions examples than Trivy.
5. Update the CI/CD pipeline description to: "PR → ruff + mypy + pytest; merge to main → build Docker → **Trivy scan (block on critical/high)** → push ECR → deploy Fargate."

**Verification:** CI/CD pipeline description includes a scanning step that blocks on critical/high CVEs. NFR-007 has a named tool and pipeline location.

---

### F2-05 — Metadata Extraction from Queries Has No Design

**Tier:** 2 — Missing architecture for required features
**Affected Section:** Requirements to Structure Mapping (line ~795)
**PRD Reference:** FR-010

**Problem:**

FR-010 requires "dynamic metadata filtering" where users mention book titles, author names, or content types (like "reproducible") in natural language queries. The system must extract these references with ≥ 0.90 accuracy and filter retrieval results accordingly.

The architecture maps FR-010 to `retrieval/vector.py` with no supporting files and no discussion of how extraction works. Metadata extraction from free-text queries is a non-trivial NLP task requiring either:
- An LLM pre-processing step (adds latency and cost)
- A lookup/fuzzy-match against a known vocabulary of book titles, authors, and content types
- Named entity recognition

No architectural decision is recorded.

**Proposed Resolution:**

Add a metadata extraction decision to the Retrieval section or as a subsection of Core Architectural Decisions:

1. **Approach:** Pre-LLM extraction step using fuzzy string matching against a known vocabulary table (book titles, author names, content type labels) stored in PostgreSQL and loaded into memory at startup. No additional LLM call needed for MVP — the vocabulary is finite (25 books, ~50 authors, 2-3 content types).
2. **Module location:** `services/query_service.py` (extraction happens during query pre-processing, before retrieval) or a new `services/metadata_extractor.py` if complexity warrants separation.
3. **Fallback (per PRD):** If fewer than 3 results match the extracted filter, fall back to unfiltered retrieval.
4. **Forward note:** If extraction accuracy falls below 0.90 during evaluation, consider upgrading to an LLM-based extraction step using the existing OpenAI integration.

**Verification:** Architecture contains a metadata extraction approach with module location and fallback behavior.

---

### F2-06 — BM25 Library Never Named

**Tier:** 2 — Missing architecture for required features
**Affected Section:** Ingestion Pipeline Analysis > BM25 Index Lifecycle (line ~259)
**PRD Reference:** FR-012

**Problem:**

The architecture dedicates 20 lines to BM25 index lifecycle (build timing, serialization, S3 upload, container startup download) but never names the library. Different options have different APIs, serialization formats, and performance characteristics:

- `rank_bm25`: Lightweight, pure Python, easy to serialize with pickle, no framework dependency
- LlamaIndex `BM25Retriever`: Integrated with LlamaIndex's node/document model, but pulls in additional dependencies
- Custom implementation: Full control, maintenance burden

An agent implementing `retrieval/keyword.py` has no guidance.

**Proposed Resolution:**

Add a BM25 library decision to the Starter Template Evaluation or Data Architecture section:

1. **Selection:** `rank_bm25` — lightweight pure-Python library. Serialize with `pickle` to a binary file. No framework coupling. The BM25 index operates independently from LlamaIndex's retrieval pipeline — keeping it separate avoids unnecessary framework dependency in the keyword search path.
2. **Alternative considered:** LlamaIndex `BM25Retriever` — would integrate with the LlamaIndex node model but introduces coupling between keyword search and the LlamaIndex framework version. Given that the retrieval abstraction layer already decouples retrieval implementations, framework integration provides no benefit.
3. **Note:** The serialization format (pickle) means the Python version used for building and loading must match. The Dockerfile pins the Python version, so this is handled.

**Verification:** Architecture names a specific BM25 library with rationale.

---

### F2-07 — No Load Testing Approach

**Tier:** 2 — Missing architecture for required features
**Affected Section:** Test Organization (line ~406)
**PRD Reference:** NFR-003

**Problem:**

NFR-003 requires: "Verified via load test submitting 5 concurrent requests confirming all responses meet NFR-001 thresholds." The architecture's test directory structure has `unit/`, `integration/`, and `evaluation/` but no `load/` or `performance/` directory. No load testing tool is named. No pipeline step exists for concurrency testing.

**Proposed Resolution:**

Add a load testing decision to the Process Patterns or Test Organization section:

1. **Scope:** A simple concurrency verification script — not a full load testing framework. Submit 5 concurrent requests to the staging API and verify all responses return within 30 seconds (NFR-001).
2. **Tool:** Python `asyncio` + `httpx` in a standalone script. No need for Locust, k6, or other load testing frameworks for 5 concurrent requests.
3. **Location:** `tests/load/test_concurrency.py` — a new directory alongside the existing test categories.
4. **Execution:** Run manually against staging before production deployment. Not part of the CI pipeline (requires a running API instance). Can be promoted to a GitHub Actions workflow post-MVP.
5. **Pass criteria:** All 5 responses complete with HTTP 200 and wall-clock time under 30 seconds per response.

**Verification:** Architecture contains a load testing approach with tool, location, and pass criteria aligned to NFR-003.

---

## Tier 3 — Risk Accepted Without Analysis

These are tradeoffs where the architecture chose the simple option without checking whether it actually meets the requirements. Should be documented as explicit risk acceptances.

---

### F2-08 — Single AZ vs. 95% Uptime Unanalyzed

**Tier:** 3 — Risk accepted without analysis
**Affected Section:** Technical Constraints & Dependencies (line ~51)
**PRD Reference:** NFR-002

**Problem:**

The architecture states "Single AZ deployment for MVP simplicity." NFR-002 requires "95% uptime during business hours (8 AM – 6 PM ET, weekdays)." AWS AZ-level incidents have historically lasted hours to days. The architecture never:
- Estimates realistic single-AZ availability
- Calculates whether 95% is achievable
- Documents explicit risk acceptance

"MVP simplicity" is not a risk analysis.

**Proposed Resolution:**

Add a risk note adjacent to the single-AZ decision:

1. **Risk statement:** A single-AZ deployment means any AZ-level failure causes 100% service downtime. AWS does not publish per-AZ SLAs. Historical AZ incidents have lasted 1-4 hours.
2. **Analysis:** NFR-002 allows 5% downtime during business hours = ~13 hours/month (50 business hours/week * 4.3 weeks * 5%). A single AZ incident per month of 1-4 hours is within budget. Two incidents or one extended incident could breach the target.
3. **Accepted risk:** For internal testing with 1-3 users, brief AZ outages are tolerable. The 95% target is a soft target during MVP — no SLA penalty exists.
4. **Post-MVP action:** Before external users onboard, migrate to multi-AZ Fargate deployment and multi-AZ RDS. ElastiCache and ALB are already multi-AZ capable.

**Verification:** Architecture contains an explicit risk acceptance for single-AZ with post-MVP migration path.

---

### F2-09 — Ingestion Competes with Qdrant for Resources

**Tier:** 3 — Risk accepted without analysis
**Affected Section:** Technical Constraints & Dependencies (line ~54), Ingestion Pipeline Analysis (line ~239)
**PRD Reference:** NFR-008, NFR-001

**Problem:**

The ingestion pipeline runs via SSM Run Command on the same EC2 instance that hosts Qdrant. During an up-to-8-hour ingestion run, the ingestion container consumes CPU, memory, and disk I/O on the machine that also serves vector search queries for the live API. This creates resource contention that could degrade API response times (NFR-001: 30s P95).

The architecture doesn't discuss this interaction.

**Proposed Resolution:**

Add a resource contention note to the Ingestion Pipeline Analysis section:

1. **Risk statement:** Ingestion and Qdrant share the same EC2 instance. Heavy ingestion workloads (PDF parsing, Vision API calls, bulk Qdrant writes) may degrade query performance.
2. **MVP mitigation:** Schedule ingestion runs during off-hours (evenings/weekends) when no testers are using the API. NFR-002 only requires 95% uptime during business hours (8 AM – 6 PM ET, weekdays).
3. **Instance sizing:** The Qdrant EC2 instance must be sized for peak ingestion load, not just steady-state query serving. This is a Terraform variable decision — instance type should accommodate both workloads.
4. **Post-MVP action:** If the corpus grows or ingestion frequency increases, move ingestion to a separate EC2 instance or Fargate task with network access to Qdrant's private IP.

**Verification:** Architecture contains a resource contention analysis with scheduling mitigation and sizing note.

---

## Tier 4 — Gaps That Will Bite You Later

These won't break the MVP build immediately, but they create hidden risks, inconsistencies, or confusion that compounds over time. Fix when convenient, before these areas are implemented.

---

### F2-10 — FR Count Is Wrong in Requirements Overview

**Tier:** 4 — Gaps that will bite you later
**Affected Section:** Project Context Analysis > Requirements Overview (line ~26)
**PRD Reference:** All FRs

**Problem:**

Line 26 states "13 FRs across 3 subsystems." The PRD defines 21 FRs (FR-001 through FR-021). The overview omits FR-014–017 (evaluation), FR-018 (auth), FR-019 (audit logging), FR-020 (health check), and FR-021 (test client). These are addressed elsewhere in the document, but the incorrect count in the overview suggests incomplete analysis and undermines reader confidence.

**Proposed Resolution:**

1. Change "13 FRs across 3 subsystems" to the correct count and grouping. Example: "21 FRs across 5 subsystems: Ingestion Pipeline (FR-001–004), Query Engine (FR-005–010), Hybrid Search & Re-Ranking (FR-011–013), Evaluation Pipeline (FR-014–017), Operations & Security (FR-018–021)."
2. Add brief one-line descriptions for the two additional subsystems under the existing three.

**Verification:** FR count matches PRD. All 21 FRs are represented in the overview grouping.

---

### F2-11 — `conversation_id` Validation Mismatch with PRD

**Tier:** 4 — Gaps that will bite you later
**Affected Section:** Implementation Patterns > Format Patterns > ID Formats (line ~452)
**PRD Reference:** Section 5.2 (request schema), Decision #9

**Problem:**

The PRD explicitly states `conversation_id` is "accepted as plain string" with "no server-side enforcement." This is documented as intentional technical debt (Decision #9). The architecture (line 452) lists `conversation_id` format as "UUID v4 string."

An agent reading the architecture would reasonably implement UUID validation on the `conversation_id` field, directly contradicting the PRD's deliberate decision to skip validation.

**Proposed Resolution:**

1. In the ID Formats table, change the `conversation_id` row to: Format = "String (UUID v4 recommended, not enforced)", Generator = "Client-generated (per PRD). Server accepts as plain string without UUID validation — intentional technical debt per PRD Decision #9."
2. This preserves the intent (clients should send UUIDs) while preventing agents from adding validation the PRD excluded.

**Verification:** `conversation_id` entry explicitly states no server-side UUID validation.

---

### F2-12 — No OpenAI DPA Verification Step

**Tier:** 4 — Gaps that will bite you later
**Affected Section:** Technical Constraints & Dependencies (line ~53)
**PRD Reference:** Section 7.2 (third-party data processing)

**Problem:**

Line 53 states "must have executed DPA with zero-retention" as a technical constraint. This requirement appears nowhere in:
- The implementation sequence (lines 176–186)
- Any deployment checklist
- Any blocking prerequisite for launch

A compliance requirement tracked only as a sentence in an architecture document with no enforcement mechanism is not a control — it's a wish.

**Proposed Resolution:**

1. Add a "Pre-Launch Compliance Checklist" subsection (after Implementation Sequence or at the end of the document) with blocking items that must be verified before production deployment:
   - OpenAI DPA executed with zero-retention clause confirmed
   - Solution Tree content license reviewed for internal testing use (cross-reference F2-13 from Round 1)
   - NFR-007 vulnerability scan passing
2. Mark these as **blocking** — deployment pipeline should not proceed to production without sign-off.
3. These are business/legal actions, not code — they need an owner and a completion date, not a Terraform module.

**Verification:** Architecture contains a pre-launch checklist with DPA verification as a blocking item.

---

### F2-13 — No Embedding Model Version Strategy

**Tier:** 4 — Gaps that will bite you later
**Affected Section:** Technical Constraints & Dependencies (line ~50), Data Architecture
**PRD Reference:** FR-011 (semantic search)

**Problem:**

The architecture specifies `text-embedding-3-large` for vector embeddings but never discusses:
- Version pinning (OpenAI may update the model)
- What happens to existing Qdrant vectors if the embedding model changes
- Whether the model version used is recorded per vector batch

Embedding model changes produce incompatible vectors. If OpenAI updates `text-embedding-3-large`, new query embeddings will not match existing document embeddings in Qdrant. Retrieval quality silently degrades with no error signal.

**Proposed Resolution:**

Add an embedding model versioning note to the Data Architecture section:

1. **Version pinning:** Use the explicit model ID `text-embedding-3-large` (which is currently OpenAI's stable identifier). If OpenAI introduces a versioned variant (e.g., `text-embedding-3-large-2026-01`), pin to the specific version.
2. **Version recording:** Store the embedding model identifier as metadata in the Qdrant collection configuration and in the PostgreSQL `books` or `chunks` metadata. This enables detection of version mismatch.
3. **Re-embedding trigger:** If the embedding model changes, all existing vectors must be re-generated via a full re-ingestion. This is part of the ingestion pipeline — no new infrastructure needed.
4. **Detection:** At API startup, compare the embedding model ID in config against the model ID stored in Qdrant collection metadata. Log a warning if mismatched. Optionally refuse to start (strict mode for production).

**Verification:** Architecture contains an embedding model versioning strategy with version recording and mismatch detection.

---

### F2-14 — Post-Ingestion Qdrant Snapshot Not Triggered

**Tier:** 4 — Gaps that will bite you later
**Affected Section:** Qdrant Backup & Recovery (line ~308)
**PRD Reference:** NFR-006

**Problem:**

Qdrant snapshots run daily (line 314). Ingestion can take up to 8 hours (NFR-008). If Qdrant fails after a successful ingestion run but before the next daily snapshot, the entire ingestion run is lost. Recovery falls back to re-ingestion (up to 8 hours, exceeding the 4-hour RTO).

The architecture's own ingestion completion criteria (line 265) state "ingestion is not 'done' until both Qdrant and the BM25 index are updated" — but snapshots are not part of this completion criteria.

**Proposed Resolution:**

Add a post-ingestion snapshot trigger to the Qdrant Backup & Recovery section:

1. **Rule:** The ingestion pipeline triggers a Qdrant snapshot immediately after successful completion, before reporting success. This is part of ingestion completion criteria — alongside BM25 index upload to S3.
2. **Implementation:** The ingestion pipeline's final step calls the Qdrant snapshot API and waits for confirmation before exiting.
3. **Rationale:** Ensures the most recent corpus state is always backed up. The daily cron snapshot remains as a safety net for changes outside of ingestion (if any).
4. Update the ingestion completion criteria line to: "ingestion is not 'done' until Qdrant is updated, BM25 index is uploaded to S3, AND a Qdrant snapshot is triggered and confirmed."

**Verification:** Ingestion completion criteria explicitly include Qdrant snapshot trigger.

---

### F2-15 — Auth Events Missing from Log Event Catalog

**Tier:** 4 — Gaps that will bite you later
**Affected Section:** Implementation Patterns > Communication Patterns > Event Catalog (line ~527)
**PRD Reference:** FR-018 (auth), FR-019 (audit logging)

**Problem:**

The event catalog (lines 527–544) contains no authentication events — no `auth_success`, no `auth_failed`, no `auth_missing_key`. The architecture explicitly states: "don't invent undocumented events" (line 566) and "Any new log event must be added to the event catalog in this document before use" (line 566).

Combined, these rules mean an agent implementing `api/middleware/auth.py` **cannot** log authentication failures without first amending the architecture document. Failed authentication attempts are security-relevant events that should be logged per FR-019's requirement to capture "all query and answer events" and per general security best practices.

**Proposed Resolution:**

Add authentication events to the event catalog:

| Event Name | When Emitted | Level | Key Fields |
|---|---|---|---|
| `auth_success` | Valid API key provided | DEBUG | — |
| `auth_failed` | Invalid API key provided | WARNING | `reason` ("invalid_key") |
| `auth_missing` | No API key in request | WARNING | `reason` ("missing_key") |

**Notes:**
- No API key value is logged (that would be a secret leak).
- `auth_success` is DEBUG level to avoid log noise in normal operation.
- `auth_failed` and `auth_missing` are WARNING level — they indicate misuse or misconfiguration.

**Verification:** Event catalog contains auth events. Agent implementing auth middleware has documented events to emit.

---

## Execution Checklist

Apply changes to architecture.md in tier order (Tier 1 first — these block implementation):

### Tier 1 — Fix Before Implementation Starts
- [ ] F2-01: Fix `user_id` logging — add to required audit fields, remove from forbidden list
- [ ] F2-02: Add cache scope rule — only cache `success` responses
- [ ] F2-03: Add test client auth approach — API key input field with `sessionStorage`

### Tier 2 — Fix Before Affected Features Are Implemented
- [ ] F2-04: Add Trivy scanning step to CI/CD pipeline description
- [ ] F2-05: Add metadata extraction approach for FR-010
- [ ] F2-06: Name BM25 library (`rank_bm25`) with rationale
- [ ] F2-07: Add load testing approach for NFR-003

### Tier 3 — Document Risk Acceptance
- [ ] F2-08: Add single-AZ risk analysis with availability math
- [ ] F2-09: Add ingestion resource contention analysis with scheduling mitigation

### Tier 4 — Fix Before These Areas Are Built
- [ ] F2-10: Correct FR count from 13 to 21; add missing subsystem groupings
- [ ] F2-11: Mark `conversation_id` as "not enforced" to match PRD Decision #9
- [ ] F2-12: Add pre-launch compliance checklist with DPA verification
- [ ] F2-13: Add embedding model versioning strategy
- [ ] F2-14: Add post-ingestion Qdrant snapshot to completion criteria
- [ ] F2-15: Add auth events to log event catalog

### Post-Application Verification
- [ ] Search for "user_id" in forbidden fields — should not appear
- [ ] Search for "cache" — confirm scope rule exists limiting to `success` responses
- [ ] Confirm test client section addresses API key handling
- [ ] Confirm CI/CD pipeline includes scanning step between build and push
- [ ] Confirm FR count matches PRD (21 FRs)
- [ ] Confirm `conversation_id` entry says "not enforced"
- [ ] Confirm event catalog includes `auth_success`, `auth_failed`, `auth_missing`
- [ ] Confirm ingestion completion criteria include Qdrant snapshot