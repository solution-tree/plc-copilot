# Sprint Change Proposal — Epics Review Findings Implementation

**Date:** 2026-02-27
**Triggered by:** Pre-implementation team review of `epics.md`
**Review team:** John (PM), Winston (Architect), Bob (SM), Amelia (Dev), Mary (Analyst)
**Change scope:** Minor — Direct implementation by development team
**Target artifact:** `_bmad-output/planning-artifacts/epics.md`

---

## Section 1: Issue Summary

### Problem Statement

The team review of `epics.md` identified 8 structural gaps that would cause incorrect story generation (P1 items) or implementation confusion and rework (P2 items) if not addressed before running `/bmad-bmm-create-epics-and-stories`.

### Context

This review was conducted pre-implementation — no code exists, no stories have been generated, and no sprints have started. The findings reference the architecture doc, FERPA research, and PRD as sources of truth. All identified gaps are documentation omissions in the epics document, not errors in the architecture or PRD.

### Evidence

8 specific findings documented in `_bmad-output/planning-artifacts/epics-review-findings.md`, each with:
- Precise problem description
- Source of truth reference
- Required change specification

---

## Section 2: Impact Analysis

### Epic Impact

| Epic | Changes | Findings |
|---|---|---|
| Epic 1 | Add Redis service layer scope, clarify FR-020 as partial, add DoD | P1-1, P1-4, P2-4 |
| Epic 2 | Add pre-launch compliance checklist deliverable, add DoD | P1-3, P2-4 |
| Epic 3 | Add risk annotation and spike recommendation, add DoD | P2-2, P2-4 |
| Epic 4 | Add FR-020 completion note, add DoD | P1-4, P2-4 |
| Epic 5 | Add DoD | P2-4 |
| Epic 6 | Add NFR-003 timing constraint, add DoD | P2-3, P2-4 |
| All (new section) | Cross-cutting patterns enforcement | P1-2 |
| All (new section) | Cross-epic technical dependencies table | P2-1 |

### Story Impact

No stories exist yet. These changes prevent incorrect stories from being generated. After applying these changes, `/bmad-bmm-create-epics-and-stories` will produce stories that correctly account for:
- Redis infrastructure scaffolding in Epic 1 (separate from cache/session logic in Epics 4/5)
- Compliance deliverables in Epic 2
- Risk-aware sequencing in Epic 3 (spike before full implementation)
- FR-020 completion criteria spanning Epics 1 and 4
- Cross-cutting pattern compliance in all stories
- Cross-epic dependency awareness

### Artifact Conflicts

- **PRD:** No changes needed. PRD is source of truth, not modified.
- **Architecture doc:** No changes needed. Architecture doc is source of truth for all findings.
- **FERPA research:** No changes needed. Referenced as source of truth for compliance checklist.
- **UI/UX:** N/A — no UI/UX specs exist.

### Technical Impact

None. No code, infrastructure, or deployments exist. Changes are confined to planning documentation.

---

## Section 3: Recommended Approach

### Selected Path: Direct Adjustment

All 8 findings are additive text modifications to a single file (`epics.md`). No code rollback, no MVP scope change, no architectural rethinking required.

| Factor | Assessment |
|---|---|
| Effort | Low — 9 text edits to one file |
| Risk | Low — additive changes, nothing removed or restructured |
| Timeline impact | Zero — no sprints have started |
| Alternatives considered | Rollback (N/A, no code exists), MVP Review (N/A, scope unchanged) |

### Rationale

This is the ideal correct-course scenario: gaps identified during review, before any implementation work. The cost of fixing is minimal (edit a document) versus the cost of not fixing (wrong stories, oversized stories, missing infrastructure, compliance items falling through cracks).

---

## Section 4: Detailed Change Proposals

All changes target: `_bmad-output/planning-artifacts/epics.md`

### 4.1 — FR Coverage Map: FR-020 row (P1-4)

**OLD:**
```
| FR-020 | Epic 1 + 4 | Health check (basic DB+Redis in E1, model readiness in E4) |
```

**NEW:**
```
| FR-020 | Epic 1 + Epic 4 | Health check (Epic 1: DB + Redis connectivity; Epic 4: re-ranker + BM25 model readiness via lifespan). FR-020 acceptance criteria fully met after Epic 4 |
```

---

### 4.2 — NFR Coverage Map: NFR-003 row (P2-3)

**OLD:**
```
| NFR-003 | Epic 6 | Concurrent users (5) — load test script |
```

**NEW:**
```
| NFR-003 | Epic 6 (post-Epic 5) | Concurrent users (5) — load test script. Must execute after Epic 5 complete to exercise full pipeline including clarification-flow sessions |
```

---

### 4.3 — Epic 1: Add Redis service layer + FR-020 partial + DoD (P1-1, P1-4, P2-4)

**OLD:**
```
### Epic 1: Project Scaffold & Core API
The developer can clone the repo, run `docker compose up`, and have a working local API skeleton with auth, health checks, audit logging, error handling, and a test client — ready for feature development.
**FRs covered:** FR-018, FR-019, FR-020 (basic), FR-021
```

**NEW:**
```
### Epic 1: Project Scaffold & Core API
The developer can clone the repo, run `docker compose up`, and have a working local API skeleton with auth, health checks, audit logging, error handling, and a test client — ready for feature development. Establishes the Redis service layer (connection pool management, session service skeleton, cache service skeleton) that Epic 4 (caching) and Epic 5 (sessions) build upon. Redis pool config per architecture doc: `max_connections=20`, `socket_timeout=5s`, `socket_connect_timeout=2s`. Cache key format: `cache:{sha256(normalized_query_text)}`.
**FRs covered:** FR-018, FR-019, FR-020 (partial — basic DB + Redis connectivity checks), FR-021

**Definition of Done:** All scaffolding, auth, logging, health (basic), error handling, and test client operational locally via `docker compose up`. Pre-commit hooks passing. Layer boundaries established. Redis service layer scaffolded with connection pool, session service skeleton, and cache service skeleton.
```

---

### 4.4 — Epic 2: Add compliance checklist + DoD (P1-3, P2-4)

**OLD:**
```
### Epic 2: Infrastructure & CI/CD
The operator can deploy the API to AWS staging and promote to production through an automated, security-scanned pipeline.
**NFRs addressed:** NFR-002, NFR-004, NFR-005, NFR-007
```

**NEW:**
```
### Epic 2: Infrastructure & CI/CD
The operator can deploy the API to AWS staging and promote to production through an automated, security-scanned pipeline. Includes pre-launch compliance checklist as a deliverable: OpenAI DPA execution verification, `store: false` code assertion, spending limits configuration, API key rotation procedure documentation, Solution Tree content license confirmation, and NFR-007 Trivy scan gate. Code-verifiable items (store:false assertion, Trivy gate) become story acceptance criteria; operational/legal items (DPA, license, rotation procedure) become a documentation deliverable story.
**NFRs addressed:** NFR-002, NFR-004, NFR-005, NFR-007
**Additional deliverables:** Pre-launch compliance checklist (FERPA research requirements)

**Definition of Done:** Terraform applies to staging. CI pipeline runs on PR (ruff → mypy → unit tests). Merge-to-main pipeline builds, scans, deploys to staging. Production promotion workflow exists. Pre-launch compliance checklist items documented.
```

---

### 4.5 — Epic 3: Add risk annotation + spike + DoD (P2-2, P2-4)

**OLD:**
```
### Epic 3: Content Ingestion Pipeline
The operator can ingest the full 25-book PLC @ Work corpus through a layout-aware parsing pipeline, producing richly-tagged, searchable chunks in the vector store and relational database.
**FRs covered:** FR-001, FR-002, FR-003, FR-004
**NFRs addressed:** NFR-006 (Qdrant snapshots), NFR-008
```

**NEW:**
```
### Epic 3: Content Ingestion Pipeline
The operator can ingest the full 25-book PLC @ Work corpus through a layout-aware parsing pipeline, producing richly-tagged, searchable chunks in the vector store and relational database.
**FRs covered:** FR-001, FR-002, FR-003, FR-004
**NFRs addressed:** NFR-006 (Qdrant snapshots), NFR-008

**Risk level:** High — parsing pipeline involves unproven tools (llmsherpa, GPT-4o Vision) on real corpus.
**Mitigation:** FR-004 (corpus scan) is the first story and serves as a go/no-go gate.
**Recommendation:** Include a technical spike story after FR-004 to validate llmsherpa + GPT-4o Vision on 2-3 representative books before committing to full-corpus implementation. Sprint planning should include a risk buffer for Epic 3.

**Definition of Done:** All 25 books ingested. Corpus scan report reviewed. 100% chunk metadata coverage. Qdrant snapshots operational. BM25 index in S3 with checksum.
```

---

### 4.6 — Epic 4: Add FR-020 completion + DoD (P1-4, P2-4)

**OLD:**
```
### Epic 4: RAG Query Engine
The API consumer can submit PLC @ Work questions and receive grounded, cited answers powered by hybrid retrieval, cross-encoder re-ranking, and metadata filtering.
**FRs covered:** FR-005, FR-010, FR-011, FR-012, FR-013
**NFRs addressed:** NFR-001, NFR-009
```

**NEW:**
```
### Epic 4: RAG Query Engine
The API consumer can submit PLC @ Work questions and receive grounded, cited answers powered by hybrid retrieval, cross-encoder re-ranking, and metadata filtering. FR-020 completed in this epic — model readiness checks (re-ranker + BM25) added to health endpoint, NFR-009 cold start verified.
**FRs covered:** FR-005, FR-010, FR-011, FR-012, FR-013, FR-020 (completed — model readiness)
**NFRs addressed:** NFR-001, NFR-009

**Definition of Done:** Query endpoint returns grounded, cited answers against ingested corpus. Hybrid retrieval (vector + BM25 + re-ranker) operational. Metadata filtering works. Health check includes model readiness. RAGAS reference-free scores meet Phase 0-B expectations.
```

---

### 4.7 — Epic 5: Add DoD (P2-4)

**OLD:**
```
### Epic 5: Conversational Query Intelligence
The API consumer gets intelligent query handling — ambiguous queries receive exactly one targeted clarifying question via session management, and out-of-scope queries receive a clear boundary signal.
**FRs covered:** FR-006, FR-007, FR-008, FR-009
```

**NEW:**
```
### Epic 5: Conversational Query Intelligence
The API consumer gets intelligent query handling — ambiguous queries receive exactly one targeted clarifying question via session management, and out-of-scope queries receive a clear boundary signal.
**FRs covered:** FR-006, FR-007, FR-008, FR-009

**Definition of Done:** Ambiguity detection, one-question clarification flow, and out-of-scope refusal all operational. Session management via Redis (building on Epic 1 session service skeleton). Golden dataset labeled subset validates precision >= 0.80, recall >= 0.70.
```

---

### 4.8 — Epic 6: Add NFR-003 timing + DoD (P2-3, P2-4)

**OLD:**
```
### Epic 6: Quality Evaluation & Validation
The evaluator can measure RAG pipeline quality using RAGAS metrics, compare against a raw GPT-4o baseline, and collect A/B style preference data for answer tuning.
**FRs covered:** FR-014, FR-015, FR-016, FR-017
**NFRs addressed:** NFR-003
```

**NEW:**
```
### Epic 6: Quality Evaluation & Validation
The evaluator can measure RAG pipeline quality using RAGAS metrics, compare against a raw GPT-4o baseline, and collect A/B style preference data for answer tuning.
**FRs covered:** FR-014, FR-015, FR-016, FR-017
**NFRs addressed:** NFR-003 (load test must execute after Epic 5 complete to exercise full pipeline including clarification-flow sessions)

**Definition of Done:** Full RAGAS evaluation (reference-free + reference-based). Baseline comparison complete. Style preference data collected. Load test passes with 5 concurrent users (after Epic 5 complete).
```

---

### 4.9 — New sections: Cross-Cutting Patterns + Cross-Epic Dependencies (P1-2, P2-1)

**Appended after Dependency Flow section:**

```
### Cross-Cutting Patterns

Epic 1 establishes all cross-cutting patterns that every subsequent epic must conform to. These are mandatory, not optional:

1. **Structured JSON logging** — 17 events in catalog, service layer only. No undocumented events.
2. **FERPA compliance** — `store: false` on all OpenAI requests, SHA-256 cache keys, no PII in logs at any level.
3. **Exception hierarchy** — `PLCCopilotError` base with subclasses, global handler, no try/except in routes.
4. **Layer boundaries** — Routes → Services → Repositories/Retrieval. No shortcuts.
5. **Response format** — Pydantic `exclude_none=True` on all responses. No `null` values.
6. **Date/time** — UTC-only datetimes everywhere. `datetime.now(datetime.timezone.utc)`.

**Enforcement:** Code review criteria for every story in Epics 2–6 include pattern compliance. Reference: Architecture doc → Cross-Cutting Concerns; CLAUDE.md → Error Handling, Logging, FERPA sections.

### Cross-Epic Dependencies

| Dependency | Producer Epic | Consumer Epic | What Must Align |
|---|---|---|---|
| Re-ranker model in Docker image | Epic 4 (defines model) | Epic 2 (builds image) | Dockerfile must include model download/copy step from Epic 2 onward |
| Qdrant snapshot cron | Epic 2 (infra) + Epic 3 (data) | Operations | Epic 3 includes post-ingestion snapshot; cron setup as late Epic 3 story |
| BM25 serialized index | Epic 3 (produces) | Epic 4 (consumes) | S3 path, pickle format, SHA-256 checksum contract |
| Vocabulary table schema | Epic 3 (populates) | Epic 4 (reads at startup) | PostgreSQL table schema defined in Epic 1 migration, populated in Epic 3 |
| Redis session/cache service | Epic 1 (scaffolds) | Epic 4 (cache), Epic 5 (sessions) | Service interface defined in Epic 1, logic built in consuming epics |
```

---

## Section 5: Implementation Handoff

### Change Scope: Minor

All changes are additive text modifications to a single planning document (`epics.md`). No code, infrastructure, or deployment changes required.

### Handoff

| Recipient | Responsibility |
|---|---|
| Nani (Dev) | Apply all 9 edits to `epics.md` |
| BMAD story generation | Run `/bmad-bmm-create-epics-and-stories` after edits applied to generate correct stories |

### Success Criteria

1. All 9 edits applied to `epics.md`
2. All 8 findings from `epics-review-findings.md` addressed
3. Cross-cutting patterns section present and lists all 6 mandatory patterns
4. Cross-epic dependencies table present with all 5 dependency rows
5. Every epic has a Definition of Done
6. FR-020 and NFR-003 coverage map rows updated
7. Epic 1 includes Redis service layer scope
8. Epic 2 includes compliance checklist deliverable
9. Epic 3 includes risk annotation and spike recommendation
