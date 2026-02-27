---
title: "Architecture Document Errata — Adversarial Review Findings"
subject: "_bmad-output/planning-artifacts/architecture.md"
date: "2026-02-27"
review-round: 1
status: "COMPLETE — all 13 findings applied"
finding-count: 13
---

# Architecture Document Errata — Adversarial Review Findings

This document records 13 findings from an adversarial review of the architecture decision document (`_bmad-output/planning-artifacts/architecture.md`). No changes should be applied to architecture.md until this errata is reviewed and approved. Once approved, this document serves as the change specification — the implementer marks each finding complete as changes are applied.

## Summary Table

| Finding | Title | Category | Affects | Status |
|---|---|---|---|---|
| F-01 | Rate Limiting — Remove from MVP | A | Architecture | **Complete** |
| F-02 | Error Response Format — Align with PRD | A | Architecture | **Complete** |
| F-03 | Response Envelope Pattern — Align with PRD | A | Architecture | **Complete** |
| F-04 | Observability Scope — Remove Dashboards and Alerts | A | Architecture | **Complete** |
| F-05 | Evaluation Pipeline (FR-014–017) — No Architectural Coverage | B | Architecture | **Complete** |
| F-06 | Minimal Test Client (FR-021) — No Architectural Home | B | Architecture | **Complete** |
| F-07 | NFR-008 Ingestion Duration — No Sizing Analysis | B | Architecture | **Complete** |
| F-08 | NFR-009 Cold Start — No Model Loading Analysis | B | Architecture | **Complete** |
| F-09 | BM25 Index Persistence — Lifecycle Undefined | B | Architecture | **Complete** |
| F-10 | Health Check Scope — Ambiguous | B | Architecture | **Complete** |
| F-11 | Redis Session TTL — Never Specified | C | Architecture | **Complete** |
| F-12 | Qdrant Backup vs. RTO — Contradiction | C | Architecture | **Complete** |
| F-13 | Content IP / Copyright — No Output Guardrails | D | Architecture | **Complete** |

---

## Category A — Architecture Contradicts PRD

### F-01 — Rate Limiting — Remove from MVP

**Category:** A — Architecture contradicts PRD (architecture must change)
**Affected Document:** architecture.md

**Problem:**
The architecture includes Redis-based rate limiting (10 req/min per API key) as a confirmed decision in the Authentication & Security table, the Decision Priority Analysis, and the Cross-Component Dependencies. The PRD v4.6 explicitly states: "No rate limiting in MVP (small internal testing team)." The architecture is building something the PRD has explicitly excluded.

**Proposed Resolution:**

1. In the "Authentication & Security" decision table, remove the "Rate Limiting" row entirely.
2. In "Decision Priority Analysis" → "Important Decisions", remove "Redis-based rate limiting (10 req/min default)."
3. In "Decision Priority Analysis" → "Deferred Decisions (Post-MVP)", add: "Rate limiting — Redis-based, configurable threshold per API key (add when external users onboard; Redis infrastructure is already present)."
4. In "Cross-Component Dependencies", remove: "API key auth and rate limiting both run as middleware — order matters (auth first, then rate limit)."
5. Remove any other references to rate limiting as an MVP deliverable.

**Verification:** Search architecture.md for "rate limit" — zero occurrences should remain except the single post-MVP deferral entry.

---

### F-02 — Error Response Format — Align with PRD

**Category:** A — Architecture contradicts PRD
**Affected Document:** architecture.md

**Problem:**
The architecture specifies RFC 7807 Problem Details as the error response standard. The PRD Section 5.4 specifies flat JSON error bodies with a single `"error"` string key (e.g., `{"error": "Unauthorized"}`, `{"error": "Session expired or not found. Please resubmit your original query."}`). These are incompatible shapes — RFC 7807 requires `type`, `title`, `status`, `detail`, and `instance` fields that the PRD contract does not include.

**Proposed Resolution:**

1. In the "API & Communication Patterns" decision table, replace the "Error Handling" row selection from "RFC 7807 Problem Details" with "PRD-specified flat JSON error bodies."
2. Rewrite the rationale: "The PRD specifies flat JSON error bodies with a single `error` string key for all error conditions (Section 5.4). This format is simple, consistent with the MVP's internal-tool scope, and defines an unambiguous contract. RFC 7807 is deferred to a future release when external consumers and API gateway integrations benefit from the richer standard."
3. Update Alternatives Considered: "RFC 7807 Problem Details (deferred — appropriate when external consumers onboard)."
4. Remove all references to "Instance ID connects errors to audit logs for tracing" (RFC 7807-specific language).
5. Add a note listing the PRD's specified error bodies:
   - `401`: `{"error": "Unauthorized"}`
   - `400`: `{"error": "Session expired or not found. Please resubmit your original query."}`
   - `503`: `{"error": "The service is temporarily unavailable. Please try again."}`
   - `500`: `{"error": "An unexpected error occurred."}`
   - `422`: FastAPI/Pydantic default validation error format

**Verification:** Zero occurrences of "RFC 7807" in architecture.md after edit.

---

### F-03 — Response Envelope Pattern — Align with PRD

**Category:** A — Architecture contradicts PRD
**Affected Document:** architecture.md

**Problem:**
The architecture proposes `{status, data, meta}` envelope with a `mode` discriminator inside `data` and a `meta` block carrying `request_id` and `response_time`. The PRD Section 5.3 specifies a flat response schema: `{status, conversation_id, answer, sources}` for success, `{status, conversation_id, clarification_question, session_id}` for needs_clarification, `{status, conversation_id, message}` for out_of_scope. There is no `data` wrapper, no `meta` block, no `mode` field. The shapes are incompatible.

**Proposed Resolution:**

1. In the "API & Communication Patterns" table, replace "Envelope pattern with mode discriminator" with "PRD-specified flat response schema with status discriminator."
2. Rewrite the rationale: "The PRD specifies a flat response schema where `status` is the discriminator (`success`, `needs_clarification`, `out_of_scope`). Each status has defined additional fields per Section 5.3. This is simpler, requires no envelope unwrapping, and is documented with examples in the PRD. A nested envelope with `data` and `meta` wrappers is deferred to a future release when cross-cutting metadata warrants a standardized outer structure."
3. Remove the `meta` block description (`request_id`, `response_time`).
4. Remove all references to "mode discriminator" or the `{status, data, meta}` shape.
5. In Cross-Component Dependencies, replace "Envelope response pattern and RFC 7807 errors are complementary — successes use envelope, failures use Problem Details" with: "Response schema follows PRD Section 5.3 (flat structure, status discriminator). Error bodies follow PRD Section 5.4 (flat `{"error": "..."}` format)."

**Note:** The `conversation_id` field survives — it is part of the PRD's flat schema, not an invention of the envelope pattern.

**Verification:** Zero occurrences of "envelope" or "mode discriminator" as MVP decisions in architecture.md.

---

### F-04 — Observability Scope — Remove Dashboards and Alerts

**Category:** A — Architecture contradicts PRD
**Affected Document:** architecture.md

**Problem:**
The architecture specifies "basic dashboard shows request count, error rate, response time, OpenAI latency" and "Email/Slack alert on error spikes or service-down." The PRD Section 6.2 explicitly descopes this: "For MVP, observability is limited to basic CloudWatch log groups for the Fargate service... Full dashboards, metric alarms, and distributed tracing are deferred." The architecture is committing to work the PRD has removed from scope.

**Proposed Resolution:**

1. In the "Infrastructure & Deployment" table, replace Observability selection with "CloudWatch log groups (Fargate service) + ALB health check."
2. Rewrite the rationale: "CloudWatch log groups are built into Fargate — zero setup. ALB health check at `/health` provides availability signaling. Structured JSON audit logs are emitted to the same CloudWatch log stream (PRD Section 7.2). Dashboards, metric alarms, and distributed tracing are explicitly deferred per PRD Section 6.2."
3. In "Decision Priority Analysis" → "Important Decisions", replace with "CloudWatch logs + ALB health checks (basic, per PRD Section 6.2)."
4. In "Deferred Decisions (Post-MVP)", add: "Full observability — CloudWatch dashboards, metric alarms, email/Slack alerting (add when external users onboard)."
5. In "Implementation Sequence" step 9, change to: "Observability — CloudWatch log group configuration and structured log format verification."

**Verification:** Zero occurrences of "dashboard" or "alert" as MVP deliverables in architecture.md.

---

## Category B — Missing Architectural Coverage

### F-05 — Evaluation Pipeline (FR-014–017) — No Architectural Coverage

**Category:** B — Missing coverage for existing PRD requirements
**Affected Document:** architecture.md

**Problem:**
The PRD defines four evaluation pipeline requirements (FR-014 through FR-017): RAGAS reference-free evaluation, reference-based evaluation, baseline comparison, and style preference data collection. The architecture document has no section, subsystem, or decision covering any of these. An implementer has no guidance on where the evaluation pipeline lives, what it runs on, or what tools it uses.

**Proposed Resolution:**

Add a new section titled "Evaluation Pipeline Architecture" after the existing "Core Architectural Decisions" section. Contents:

1. **Subsystem description:** The evaluation pipeline is a separate offline workload — not part of the live API container. It runs as a standalone Python CLI script invocable locally or via GitHub Actions.
2. **Execution model:** Evaluator runs the pipeline locally with access to the staging/production API endpoint. The pipeline submits golden dataset questions to `POST /api/v1/query`, collects responses, and passes them to RAGAS for scoring. No dedicated compute service needed for MVP.
3. **Tool decision:** RAGAS library for metric computation. Python script lives in `tests/evaluation/` (matching the test directory structure already defined in the architecture).
4. **Data inputs:** Golden dataset stored in the repository (JSON or CSV). For FR-015, Concise Answers book content is already part of the ingested corpus — its chunks exist in Qdrant and PostgreSQL.
5. **Outputs:** Per-query scored report (JSON or CSV) written to a local directory. Not persisted to any data store for MVP.
6. **FR-017 style preference:** A separate evaluation pass submitting each query twice with different system prompts (Book-Faithful and Coaching-Oriented). Both responses written to a preference log CSV for manual review.
7. **Forward note:** When evaluation grows beyond manual invocation (nightly runs, CI quality gates), it becomes a scheduled GitHub Actions workflow.

**Verification:** New section explicitly references FR-014, FR-015, FR-016, and FR-017 by ID.

---

### F-06 — Minimal Test Client (FR-021) — No Architectural Home

**Category:** B — Missing coverage for existing PRD requirement
**Affected Document:** architecture.md

**Problem:**
FR-021 requires a minimal web-based test client — single question input field plus a disclaimer banner. The architecture has no decision covering where this lives, how it is served, or what technology implements it.

**Proposed Resolution:**

Add a decision entry to the "Infrastructure & Deployment" section covering FR-021:

1. **Technology:** Single static HTML file with inline CSS and vanilla JavaScript. No framework, no build step.
2. **Serving:** Served directly by the FastAPI application via `StaticFiles` mount or a dedicated GET route. Ships inside the same Docker container as the API. Zero additional infrastructure.
3. **Route:** Accessible at `/test-client`. Not advertised in OpenAPI docs.
4. **Disclaimer:** Banner text from FR-021 is hardcoded in the HTML.
5. **Scope boundary:** No auth UI, no session management display, no styling beyond functional layout. This is a test tool, not a product feature.

**Verification:** architecture.md contains an explicit decision referencing FR-021.

---

### F-07 — NFR-008 Ingestion Duration — No Sizing Analysis

**Category:** B — Missing coverage for existing PRD requirement
**Affected Document:** architecture.md

**Problem:**
NFR-008 requires ingestion of all 25 books within 8 hours. The architecture accepts this without analysis. GPT-4o Vision calls for landscape pages are the primary time risk, and there is no sizing estimate, parallelism strategy, or per-book failure isolation design.

**Proposed Resolution:**

Add a sizing analysis note to the architecture (in the ingestion pipeline area or as a new subsection):

1. **Bottleneck identification:** GPT-4o Vision calls for landscape pages are the primary time risk. Portrait/llmsherpa processing is fast (seconds per book).
2. **Sizing approach:** The corpus scan (FR-004) will produce landscape page counts. With N landscape pages and an estimated X seconds per Vision call, total landscape processing time = N * X. This must be compared against the 8-hour ceiling after FR-004 completes.
3. **Parallelism decision:** If serial processing exceeds 8 hours, the ingestion container can run concurrent asyncio tasks for Vision API calls within the same SSM-triggered EC2 model. No additional infrastructure required.
4. **Per-book failure isolation:** NFR-008 specifies individual book failures must not block remaining books. The ingestion pipeline must implement try/except per book with failure logging.

**Verification:** architecture.md contains an explicit acknowledgment of NFR-008 with a sizing approach and per-book failure isolation.

---

### F-08 — NFR-009 Cold Start — No Model Loading Analysis

**Category:** B — Missing coverage for existing PRD requirement
**Affected Document:** architecture.md

**Problem:**
NFR-009 requires the API container to serve requests within 120 seconds of task start, including model loading. The cross-encoder re-ranker runs in-process. The architecture never specifies whether the model is bundled in the Docker image or downloaded at runtime, and never analyzes whether 120 seconds is achievable.

**Proposed Resolution:**

Add a cold start analysis note adjacent to the re-ranker decision:

1. **Model packaging:** The re-ranker model weights must be baked into the Docker image at build time. Downloading ~90MB at cold start adds unpredictable latency and an external dependency failure mode. The Dockerfile runs a pre-cache step during build.
2. **Load time estimate:** Re-ranker loads from local disk in ~5–15 seconds on Fargate. Combined with FastAPI startup, dependency init, and connection pool warm-up, total startup is estimated at 30–60 seconds — within the 120-second ceiling.
3. **Health check readiness:** The `/health` endpoint must return non-200 until the re-ranker model is loaded and all downstream connections (RDS, Redis, Qdrant) are verified. FastAPI's lifespan context manager handles the loading sequence.
4. **Tradeoff:** ~90MB image size increase is accepted — ECR pull is faster than HuggingFace download over public internet.

**Verification:** architecture.md specifies model weights baked into Docker image and health check reflects model readiness.

---

### F-09 — BM25 Index Persistence — Lifecycle Undefined

**Category:** B — Missing coverage
**Affected Document:** architecture.md

**Problem:**
LlamaIndex's `BM25Retriever` builds an in-memory index from the text corpus at runtime. The architecture never addresses when the index is built, whether it is persisted, or what happens to cold start time when it must be rebuilt from hundreds of thousands of chunks.

**Proposed Resolution:**

Add a BM25 index lifecycle decision:

1. **Build timing:** The BM25 index is built once after ingestion completes (not on every container startup). A post-ingestion script serializes the index to a binary file and uploads it to S3 in the same private bucket as source PDFs.
2. **Container startup:** At API startup, the container downloads the serialized BM25 index from S3 and loads it into memory. The `/health` endpoint returns non-200 until the index is loaded.
3. **Size estimate:** For a corpus of this scale, the serialized BM25 index is typically 10–50MB. S3 download is well within the 120-second cold start budget.
4. **Index staleness:** After re-ingestion, the pipeline must rebuild and re-upload the BM25 index. This is part of ingestion completion criteria.
5. **Alternative rejected:** Building on every container startup was rejected because it adds unpredictable latency that grows with corpus size, violating the scale-ready principle.

**Verification:** architecture.md contains a BM25 index lifecycle decision with build timing, S3 storage, and startup loading.

---

### F-10 — Health Check Scope — Ambiguous

**Category:** B — Missing coverage
**Affected Document:** architecture.md

**Problem:**
The architecture mentions `/health` in multiple places but never precisely defines what it checks. The PRD (FR-020) lists vector database and relational database — not Redis. The architecture's cross-component dependencies say "database and Redis." A developer has conflicting signals about what constitutes a passing health check.

**Proposed Resolution:**

Add a precise `/health` endpoint specification:

1. **Endpoint:** `GET /health`
2. **Dependency checks (per FR-020 + architecture additions):**
   - PostgreSQL (RDS): execute `SELECT 1`
   - Qdrant: execute collection info call
   - Redis: execute PING
3. **Readiness checks (per F-08 and F-09):**
   - Re-ranker model loaded in memory
   - BM25 index loaded in memory
4. **Response:** `200 OK` with `{"status": "healthy", "dependencies": {"postgres": "ok", "qdrant": "ok", "redis": "ok"}}` when all pass. `503 Service Unavailable` with failing dependency identified when any check fails.
5. **ALB config:** Health check polls `/health` every 30 seconds. Two consecutive failures mark target unhealthy.
6. **Note on Redis:** Included even though FR-020 doesn't list it explicitly, because session/cache is a hard dependency of the query endpoint.

**Verification:** architecture.md contains a precise `/health` definition with dependency list and response format.

---

## Category C — Open Design Questions

### F-11 — Redis Session TTL — Never Specified

**Category:** C — Open design question needing a decision
**Affected Document:** architecture.md

**Problem:**
Redis stores session state for the clarification loop (FR-006, FR-008). The PRD defines a `400 Bad Request` response for expired sessions. But neither document specifies the TTL. Without it, sessions either never expire or use an arbitrary implementation default.

**Proposed Resolution:**

Add a Redis session TTL decision to the Data Architecture section:

1. **TTL value:** 15 minutes. The clarification flow is synchronous — a teacher submits a query, reads the clarification, and follows up within a single interaction. 15 minutes is generous for this flow and prevents stale sessions from accumulating.
2. **Key structure:** `session:{session_id}` with serialized original query context as the value.
3. **Expiry behavior:** When a follow-up arrives with an expired `session_id`, Redis GET returns nil, and the API returns `400 Bad Request` per PRD Section 5.4.
4. **Distinct from response cache TTL:** The 24-hour response cache TTL is a separate concern and is unchanged.

**Verification:** architecture.md contains a Redis session TTL value with rationale.

---

### F-12 — Qdrant Backup vs. RTO — Contradiction

**Category:** C — Open design question needing a decision
**Affected Document:** architecture.md

**Problem:**
NFR-006 requires a 4-hour RTO for vector store recovery. The stated recovery strategy is re-running ingestion from S3 source PDFs. NFR-008 allows ingestion to take up to 8 hours. A recovery strategy that takes 8 hours cannot satisfy a 4-hour RTO. This is a direct contradiction.

**Proposed Resolution:**

**Recommended: Option 1 — Qdrant Snapshot Backup**

Configure Qdrant's native snapshot API to take daily snapshots and upload to S3. Restoration from snapshot takes minutes — well within the 4-hour RTO. Re-ingestion remains the fallback for catastrophic failure where snapshots are also lost.

Add to architecture:
1. **Snapshot schedule:** Daily automated snapshot via cron on the Qdrant EC2 instance.
2. **Storage:** S3 private bucket, same as source PDFs.
3. **Retention:** 7 days (matching RDS backup retention).
4. **Recovery procedure:** Restore from latest S3 snapshot. If snapshot is corrupted or missing, fall back to full re-ingestion (8-hour ceiling, exceeds RTO — escalate as incident).

**Alternative rejected: Option 2** — Revise the RTO to 12 hours. This requires a PRD change to NFR-006 and stakeholder sign-off. Not recommended because snapshot backups solve the problem without requiring scope negotiation.

**Verification:** architecture.md contains a Qdrant snapshot/backup decision reconciled with the 4-hour RTO.

---

## Category D — Business Risk

### F-13 — Content IP / Copyright — No Output Guardrails

**Category:** D — Business risk flagged (not strictly architecture)
**Affected Document:** architecture.md (flag and recommendation only)

**Problem:**
The PLC @ Work books are proprietary Solution Tree IP. The RAG pipeline retrieves verbatim text chunks and the LLM may reproduce substantial portions in its answers. The `text_excerpt` field adds 200 characters of quoted text per source. Without guardrails, a single response could reproduce meaningful portions of copyrighted content. For internal MVP testing, the legal risk is low — but there is no awareness of this risk documented anywhere.

**Proposed Resolution:**

Add a subsection titled "Known Risk: Content IP and Copyright" under Cross-Cutting Concerns:

1. **Risk statement:** The RAG pipeline retrieves verbatim text and may reproduce substantial portions in generated answers. The `text_excerpt` field adds additional quoted text per source.
2. **MVP mitigation:** Internal testers only — no guardrail required for MVP launch.
3. **Post-MVP required action:** Before external user rollout, implement at least one of:
   - (a) Post-generation n-gram overlap check (>40% 5-gram overlap triggers paraphrase retry)
   - (b) Licensing review with Solution Tree confirming the use case is covered
   - (c) Both
4. **Contractual dependency:** Confirm with Solution Tree whether internal testing use is explicitly covered by the content license.

**Verification:** architecture.md contains a documented risk entry with post-MVP action items.

---

## Execution Checklist

Apply changes to architecture.md in this order (Category A first to establish the correct baseline):

### Category A — Remove Contradictions with PRD
- [x] F-01: Remove rate limiting from MVP decisions; add to Post-MVP deferrals
- [x] F-02: Replace RFC 7807 with PRD flat error bodies; update rationale
- [x] F-03: Replace envelope pattern with PRD flat response schema; update cross-dependencies
- [x] F-04: Reduce observability to CloudWatch logs + ALB health check; move dashboards/alerts to Post-MVP

### Category B — Add Missing Coverage
- [x] F-05: Add Evaluation Pipeline Architecture section (references FR-014, FR-015, FR-016, FR-017) ✅
- [x] F-06: Add Minimal Test Client decision (references FR-021) ✅
- [x] F-07: Add NFR-008 ingestion sizing analysis and per-book failure isolation ✅
- [x] F-08: Add NFR-009 cold start analysis; model baked into Docker image; health check readiness ✅
- [x] F-09: Add BM25 index lifecycle decision (build, serialize, S3, load at startup) ✅
- [x] F-10: Add precise /health endpoint specification ✅

### Category C — Record Design Decisions
- [x] F-11: Add Redis session TTL decision (15 minutes) ✅
- [x] F-12: Add Qdrant snapshot backup decision; reconcile with NFR-006 RTO ✅

### Category D — Flag Business Risk
- [x] F-13: Add Content IP / Copyright risk entry with post-MVP action items ✅

### Post-Application Verification
- [x] Search for "rate limit" — only Post-MVP mention remains ✅
- [x] Search for "RFC 7807" — only in alternatives column ✅
- [x] Search for "envelope" — only in alternatives column ✅
- [x] Search for "dashboard" — only in deferral contexts ✅
- [x] Confirm F-05 references FR-014, FR-015, FR-016, FR-017 by ID ✅
- [x] Confirm F-06 references FR-021 by ID ✅
- [x] Confirm F-09 specifies S3 as index storage ✅
- [x] Confirm F-10 lists PostgreSQL, Qdrant, and Redis as health check dependencies ✅
- [x] Confirm F-12 uses Option 1 (Qdrant snapshots) ✅
- [x] Update architecture.md frontmatter date (updated to 2026-02-27) ✅
