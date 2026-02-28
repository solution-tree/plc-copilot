# Epics Structure Review — Required Changes

**Date:** 2026-02-27
**Reviewed by:** John (PM), Winston (Architect), Bob (SM), Amelia (Dev), Mary (Analyst)
**Input:** `_bmad-output/planning-artifacts/epics.md`, PRD v4.6, Architecture Decision Document, FERPA Research

---

## How to Use This Document

Each finding is a required change to `epics.md`. They are ordered by priority — execute top to bottom. Apply all changes before running `/bmad-bmm-create-epics-and-stories` to generate stories, or if stories already exist, use `/bmad-bmm-correct-course` to propagate changes.

---

## Priority 1 — Blocks Correct Story Creation

These must be fixed first. If stories are written without these changes, they will be wrong or incomplete.

### P1-1: Add Session & Cache Service to Epic 1 Scope

**Problem:** Epic 5 (Conversational Query Intelligence) requires Redis session management for the clarification flow — `conversation_id`, `session_id`, session TTL (15 min), and the one-question hard limit (FR-008). Epic 4 needs response caching (24h TTL, SHA-256 hashed keys per FERPA). But neither Epic 1 nor any other epic explicitly establishes the session service or cache service.

The architecture doc (Caching Strategy section) defines:
- Session storage for clarification flow
- Response cache with `cache:{sha256(normalized_query_text)}` keys
- Cache scope rules (only cache `success` responses)
- Redis shared pool config: `max_connections=20`, `socket_timeout=5s`, `socket_connect_timeout=2s`

**Where it matters:** Without the Redis service layer established in Epic 1, Epic 4 stories will need to build cache infrastructure AND query logic simultaneously. Epic 5 stories will need to build session infrastructure AND conversational logic simultaneously. That violates the layer separation and creates stories that are too large.

**Required change:** Add to Epic 1's description and FR coverage:
- Add a note that Epic 1 establishes the Redis service layer (connection management, session service skeleton, cache service skeleton)
- This is infrastructure scaffolding, not the full session/cache logic — Epic 4 and Epic 5 build on top of it
- Reference the architecture doc's Redis pool configuration and cache key format

**Source of truth:** Architecture doc → Caching Strategy, Data Architecture sections.

---

### P1-2: Add Cross-Cutting Patterns Section to Epics Document

**Problem:** The architecture doc and CLAUDE.md define mandatory patterns that apply to every epic:
- Structured JSON logging (17 events in catalog, service layer only)
- FERPA compliance patterns (`store: false`, SHA-256 cache keys, no PII in logs)
- Exception hierarchy (`PLCCopilotError` base with subclasses, global handler, no try/except in routes)
- Layer boundaries (Routes → Services → Repositories/Retrieval)
- Pydantic `exclude_none=True` on all responses
- UTC-only datetimes

These are established in Epic 1 but must be enforced in Epics 2–6. The current epic structure doesn't state this relationship.

**Where it matters:** Without this, each epic's stories might re-implement patterns inconsistently or omit them entirely. A developer working on an Epic 4 story might not know they must follow the exception hierarchy established in Epic 1.

**Required change:** Add a new section after "Dependency Flow" called **Cross-Cutting Patterns** that states:
1. Epic 1 establishes all cross-cutting patterns (logging, error handling, FERPA compliance, layer boundaries)
2. All subsequent epics conform to these patterns — they are not optional
3. Code review criteria for every story include pattern compliance
4. Reference: Architecture doc → Cross-Cutting Concerns, CLAUDE.md → Error Handling / Logging / FERPA sections

---

### P1-3: Add Pre-Launch Compliance Checklist as Epic 2 Deliverable

**Problem:** The FERPA research document and PRD mandate a pre-launch compliance checklist that must be completed before production deployment:
1. OpenAI DPA execution (legal, not code)
2. Zero-retention (`store: false`) verification in code
3. OpenAI spending limits configured
4. API key rotation procedure documented
5. Solution Tree content license confirmed
6. NFR-007 vulnerability scan passing (Trivy)

Currently no epic owns this checklist. Items 2, 3, 6 are verifiable in code/CI. Items 1, 4, 5 are operational/legal tasks.

**Where it matters:** Without an explicit home, these items will be "someone else's problem" until launch day. Several are hard blockers for production — you cannot deploy without the DPA.

**Required change:** Add to Epic 2's scope:
- Add "Pre-Launch Compliance Checklist" as a deliverable
- Epic 2 already owns CI/CD and infrastructure — the checklist naturally extends it
- Code-verifiable items (store:false assertion, Trivy gate) become story acceptance criteria
- Operational items (DPA, license, rotation procedure) become a checklist story with documentation deliverables
- Add to FR coverage: "Pre-launch compliance checklist (FERPA research requirements)"

**Source of truth:** FERPA Research → Pre-launch compliance checklist section; PRD → Section 2.3 evaluation strategy references DPA.

---

### P1-4: Clarify FR-020 Split Ownership with Completion Criteria

**Problem:** FR-020 (Health Check Endpoint) is split: "basic DB+Redis in E1, model readiness in E4." The PRD states FR-020 tests: "returns 200 OK when all dependencies reachable; non-200 when any unreachable." The architecture doc adds that the FastAPI lifespan context manager loads the re-ranker model, BM25 index, and warms connection pools — and NFR-009 requires readiness within 120 seconds.

The split is technically correct but creates ambiguity: when is FR-020 "done"?

**Required change:** Update the FR Coverage Map:
- `FR-020` row should read: `Epic 1 + Epic 4` with description: `Health check (Epic 1: DB + Redis connectivity; Epic 4: re-ranker + BM25 model readiness via lifespan). FR-020 acceptance criteria fully met after Epic 4.`
- In Epic 1's description, add: "FR-020 partially implemented — basic dependency checks"
- In Epic 4's description, add: "FR-020 completed — model readiness checks added to health endpoint, NFR-009 cold start verified"

---

## Priority 2 — Causes Rework or Ambiguity During Implementation

These won't produce wrong stories, but they'll cause confusion, rework, or missed dependencies during sprint execution.

### P2-1: Document Cross-Epic Technical Dependencies

**Problem:** Several technical dependencies cross epic boundaries but aren't documented:

1. **Re-ranker model in Docker image (Epic 2 ↔ Epic 4):** The architecture doc specifies "Re-ranker model weights (~90MB) baked into Docker image at build time." The Dockerfile is created in Epic 2 (CI/CD), but the re-ranker is an Epic 4 concern. If Epic 2's Dockerfile story doesn't account for model weight inclusion, Epic 4 will require a Dockerfile rewrite.

2. **Qdrant snapshot cron (Epic 2 ↔ Epic 3):** Architecture doc specifies "daily snapshots via cron + post-ingestion snapshot, S3 storage with 7-day retention, CloudWatch alarm on snapshot age." NFR-006 maps to Epic 2 + 3, but no epic explicitly owns the cron job. The cron needs Qdrant running (Epic 2 infra) with data (Epic 3 ingestion).

3. **BM25 index lifecycle (Epic 3 → Epic 4):** Ingestion (Epic 3) produces the BM25 pickle with SHA-256 checksum. The API (Epic 4) loads it from S3 at startup via lifespan manager. The S3 path, checksum verification, and serialization format must be consistent across both epics.

4. **Vocabulary table for metadata extraction (Epic 3 → Epic 4):** Architecture doc specifies "Dynamic metadata extraction with fuzzy matching (rapidfuzz) against vocabulary table loaded from PostgreSQL at startup." Epic 3 populates this table during ingestion. Epic 4 reads it. The schema must be established before both epics.

**Required change:** Add a new section after "Dependency Flow" called **Cross-Epic Dependencies** with a table:

| Dependency | Producer Epic | Consumer Epic | What Must Align |
|---|---|---|---|
| Re-ranker model in Docker image | Epic 4 (defines model) | Epic 2 (builds image) | Dockerfile must include model download/copy step from Epic 2 onward |
| Qdrant snapshot cron | Epic 2 (infra) + Epic 3 (data) | Operations | Epic 3 includes post-ingestion snapshot; cron setup as late Epic 3 story |
| BM25 serialized index | Epic 3 (produces) | Epic 4 (consumes) | S3 path, pickle format, SHA-256 checksum contract |
| Vocabulary table schema | Epic 3 (populates) | Epic 4 (reads at startup) | PostgreSQL table schema defined in Epic 1 migration, populated in Epic 3 |
| Redis session/cache service | Epic 1 (scaffolds) | Epic 4 (cache), Epic 5 (sessions) | Service interface defined in Epic 1, logic built in consuming epics |

---

### P2-2: Flag Epic 3 as High-Risk with Spike Recommendation

**Problem:** Epic 3 (Content Ingestion Pipeline) involves three-stage PDF parsing (PyMuPDF classification → llmsherpa structure → GPT-4o Vision for landscape pages). This is R&D work — llmsherpa's behavior on real PLC books is unproven, GPT-4o Vision output quality on educational worksheets is unknown, and the corpus scan (FR-004) may reveal surprises.

The epics doc notes FR-004 as "first story, PRD gate" which is good — the corpus scan must complete before full ingestion proceeds. But the epic description doesn't flag the risk.

**Required change:** Add a risk annotation to Epic 3's description:
- **Risk level:** High — parsing pipeline involves unproven tools on real corpus
- **Mitigation:** FR-004 (corpus scan) is the first story and serves as a go/no-go gate
- **Recommendation:** Include a technical spike story after FR-004 to validate llmsherpa + GPT-4o Vision on 2-3 representative books before committing to full-corpus implementation
- Sprint planning should include a risk buffer for Epic 3

---

### P2-3: Reposition NFR-003 Load Testing

**Problem:** NFR-003 (5 concurrent users) is mapped to Epic 6. The architecture doc specifies "Load test: 5 concurrent requests via asyncio + httpx, run manually against staging." However, a meaningful load test should exercise the full pipeline including Epic 5's session management — if a concurrent user hits the clarification flow, the system must handle it.

Epic 6 runs parallel with Epic 5, so a load test in Epic 6 might run before Epic 5 is complete, testing an incomplete system.

**Required change:** Update NFR Coverage Map:
- Move NFR-003 from Epic 6 to a post-Epic-5 activity, or add a note: "NFR-003 load test should be executed after both Epic 5 and Epic 6 are complete to exercise the full pipeline"
- Alternatively, if load testing stays in Epic 6, add acceptance criteria: "Load test includes at least one clarification-flow scenario (requires Epic 5 session management complete)"

---

### P2-4: Add Epic-Level Definition of Done

**Problem:** Each epic lists FRs covered but doesn't state what "done" means at the epic level. Some FRs have acceptance criteria that depend on artifacts from later epics (e.g., FR-005 needs ingested content from Epic 3 to verify citations). The dependency chain implies ordering, but it's not stated.

**Required change:** Add a brief "Definition of Done" to each epic:

- **Epic 1:** All scaffolding, auth, logging, health (basic), error handling, and test client operational locally via `docker compose up`. Pre-commit hooks passing. Layer boundaries established.
- **Epic 2:** Terraform applies to staging. CI pipeline runs on PR (ruff → mypy → unit tests). Merge-to-main pipeline builds, scans, deploys to staging. Production promotion workflow exists. Pre-launch compliance checklist items documented.
- **Epic 3:** All 25 books ingested. Corpus scan report reviewed. 100% chunk metadata coverage. Qdrant snapshots operational. BM25 index in S3 with checksum.
- **Epic 4:** Query endpoint returns grounded, cited answers against ingested corpus. Hybrid retrieval (vector + BM25 + re-ranker) operational. Metadata filtering works. Health check includes model readiness. RAGAS reference-free scores meet Phase 0-B expectations.
- **Epic 5:** Ambiguity detection, one-question clarification flow, and out-of-scope refusal all operational. Session management via Redis. Golden dataset labeled subset validates precision/recall targets.
- **Epic 6:** Full RAGAS evaluation (reference-free + reference-based). Baseline comparison complete. Style preference data collected. Load test passes with 5 concurrent users (after Epic 5 complete).

---

## Summary Checklist

| # | Change | Priority | Section to Modify |
|---|---|---|---|
| P1-1 | Add session & cache service to Epic 1 scope | P1 | Epic 1 description + FR coverage |
| P1-2 | Add cross-cutting patterns section | P1 | New section after Dependency Flow |
| P1-3 | Add pre-launch compliance checklist to Epic 2 | P1 | Epic 2 description + deliverables |
| P1-4 | Clarify FR-020 split with completion criteria | P1 | FR Coverage Map + Epic 1 & 4 descriptions |
| P2-1 | Document cross-epic technical dependencies | P2 | New section after Dependency Flow |
| P2-2 | Flag Epic 3 as high-risk with spike recommendation | P2 | Epic 3 description |
| P2-3 | Reposition NFR-003 load testing | P2 | NFR Coverage Map + Epic 6 notes |
| P2-4 | Add epic-level definition of done | P2 | Each epic description |
