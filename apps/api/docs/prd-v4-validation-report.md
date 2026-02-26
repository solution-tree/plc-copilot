---
validationTarget: 'apps/api/docs/prd-v4.md'
validationDate: '2026-02-26'
inputDocuments:
  - 'apps/api/docs/prd-v4.md'
  - 'apps/api/docs/research/ferpa-FINAL.md'
validationStepsCompleted:
  - step-v-01-discovery
  - step-v-02-format-detection
  - step-v-03-density-validation
  - step-v-04-brief-coverage-validation
  - step-v-05-measurability-validation
  - step-v-06-traceability-validation
  - step-v-07-implementation-leakage-validation
  - step-v-08-domain-compliance-validation
  - step-v-09-project-type-validation
  - step-v-10-smart-validation
  - step-v-11-holistic-quality-validation
  - step-v-12-completeness-validation
validationStatus: COMPLETE
holisticQualityRating: '4/5 - Good'
overallStatus: Warning
---

# PRD Validation Report

**PRD Being Validated:** apps/api/docs/prd-v4.md
**Validation Date:** 2026-02-26

## Input Documents

- PRD: prd-v4.md ✓
- Compliance Reference: ferpa-FINAL.md ✓
- Technical Specification: Not found (referenced in PRD but not present in repository)

## Validation Findings

## Format Detection

**PRD Structure (Level 2 Headers):**
1. ## 1. Vision & Strategic Context
2. ## 2. MVP Goals & Scope
3. ## 3. Core Features & Requirements
4. ## 4. Data Models & Schema
5. ## 5. API Specification
6. ## 6. Architecture & Technology Stack
7. ## 7. Security & Compliance: The Tenant Enclave Foundation
8. ## 8. Acceptance Criteria
9. ## 9. Pre-Build Corpus Analysis
10. ## 10. Key Decisions Log

**BMAD Core Sections Present:**
- Executive Summary: Missing (Vision & Strategic Context is partial coverage)
- Success Criteria: Present (Section 2.1 Key Goals + Section 8 Acceptance Criteria)
- Product Scope: Present (Section 2 MVP Goals & Scope + Section 2.2 Non-Goals)
- User Journeys: Missing
- Functional Requirements: Present (Section 3 Core Features & Requirements)
- Non-Functional Requirements: Missing (Security in Section 7 but not structured as NFRs)

**Format Classification:** BMAD Variant
**Core Sections Present:** 3/6

## Information Density Validation

**Anti-Pattern Violations:**

**Conversational Filler:** 0 occurrences

**Wordy Phrases:** 0 occurrences

**Redundant Phrases:** 0 occurrences

**Total Violations:** 0

**Severity Assessment:** Pass

**Recommendation:** PRD demonstrates excellent information density. Every sentence carries weight with zero filler. Minor observation: Section 1 uses "designed to provide" (could be "provides") — not a violation but an optional tightening opportunity.

## Product Brief Coverage

**Status:** N/A - No Product Brief was provided as input

## Measurability Validation

### Functional Requirements

**Total FRs Analyzed:** 13 Acceptance Criteria (Section 8) + narrative features (Section 3)

**Format Violations:** Pervasive — requirements are written as acceptance criteria ("The endpoint correctly implements..."), not in "[Actor] can [capability]" format. Noted as structural gap; already captured under BMAD Variant classification.

**Subjective Adjectives Found:** 1
- Section 8, AC 12: "returns a coherent, grounded answer" — "coherent" is subjective; no test criterion defined for what constitutes coherence.

**Vague Quantifiers Found:** 0

**Implementation Leakage:** 5 instances
- Section 3.1: PyMuPDF, llmsherpa, GPT-4o Vision named within feature requirements (not in architecture section)
- Section 3.3: BM25 and cross-encoder re-ranker named within feature requirements

**FR Violations Total:** 6

### Non-Functional Requirements

**Total NFRs Analyzed:** 0 (no dedicated NFR section exists)

**Missing Metrics:** 2
- Security NFRs present in Section 7 prose but not formalized as testable NFRs (e.g., "TLS 1.2+", "no PII in logs")
- Availability/uptime NFR absent with no acknowledged exclusion

**Incomplete Template:** All (no NFR section to apply template to)

**Missing Context:** N/A

**NFR Violations Total:** 2 (structural absence + unacknowledged availability gap)

### Overall Assessment

**Total Requirements Analyzed:** 13 ACs + narrative FRs; 0 formal NFRs
**Total Violations:** 8 (6 FR + 2 NFR)

**Severity:** Warning (5–10 violations)

**Recommendation:** Implementation leakage in Section 3 is the primary FR concern — tool names belong in the Architecture section (Section 6), not requirements. The missing NFR section is a structural gap; security controls from Section 7 should be reformatted as measurable NFRs. Performance NFRs are intentionally excluded (valid for MVP). Availability SLA exclusion should be explicitly acknowledged.

## Traceability Validation

### Chain Validation

**Executive Summary → Success Criteria:** Intact
- Vision clearly establishes the hypothesis to prove; all 3 Key Goals in Section 2.1 directly trace to it.

**Success Criteria → User Journeys:** Broken
- No User Journeys section exists. No user personas, interaction flows, or user types are defined anywhere in the document.

**User Journeys → Functional Requirements:** Partially traceable
- FRs in Section 3 address clear educator needs (querying, clarification, out-of-scope detection), but these connections are implicit — not formally linked to any documented journey.
- ACs 7, 8, 9, 12, 13 trace to implicit user needs only; no formal journey anchor exists.

**Scope → FR Alignment:** Intact
- Section 2.2 Non-Goals are well-defined and honored throughout; all 13 ACs are in-scope.

### Orphan Elements

**Orphan Functional Requirements:** 0 (all requirements are justifiable by business objectives)

**Unsupported Success Criteria:** 0

**User Journeys Without FRs:** N/A — no user journeys exist

### Traceability Matrix

| Chain | Status | Notes |
|---|---|---|
| Vision → Success Criteria | ✓ Intact | Strong alignment across all 3 goals |
| Success Criteria → User Journeys | ✗ Broken | User Journeys section missing entirely |
| User Journeys → FRs | ⚠️ Partial | FRs justified by business need, not formal journeys |
| Scope → FR Alignment | ✓ Intact | Non-Goals well-defined and honored |

**Total Traceability Issues:** 1 broken chain, 1 partial chain

**Severity:** Warning

**Recommendation:** Traceability gaps identified — the missing User Journeys section breaks the chain between success criteria and requirements. Add at minimum one user journey for the primary educator use case (querying the system, receiving an answer, following up on clarification). This will strengthen downstream work when epics and stories are created.

## Implementation Leakage Validation

### Leakage by Category

**Backend Frameworks:** 1 violation
- Section 5.4: "Standard FastAPI/Pydantic validation error" — names framework in API contract

**Databases / Cloud Platforms:** 4 violations
- Section 8, AC 5: S3, Qdrant, PostgreSQL named in acceptance criterion
- Section 8, AC 6: "public ALB URL" — AWS-specific term in acceptance criterion

**Libraries / Tools in Feature Descriptions:** 6 violations
- Section 3.1: PyMuPDF, llmsherpa, GPT-4o Vision named within feature requirements
- Section 3.3: BM25, cross-encoder re-ranker, LlamaIndex BM25Retriever named within feature requirements

**Evaluation Framework:** 2 violations (borderline)
- Section 8, ACs 10–11: RAGAS named as specific evaluation framework in acceptance criteria

### Summary

**Total Implementation Leakage Violations:** 13

**Severity:** Critical (>5)

**Recommendation:** Extensive implementation leakage in Section 3. Requirements should specify WHAT the system must do, not WHICH tools implement it. Section 3.1 describes the ingestion tool pipeline (how) rather than ingestion capabilities (what). These tool names belong in Section 6 (Architecture), not Section 3 (Requirements). The AC-level references to Qdrant/PostgreSQL/S3/ALB are borderline — they verify the architectural contract but still technically leak implementation. Consider abstracting ACs to reference capability outcomes rather than infrastructure components.

**Note:** API endpoint path (`POST /api/v1/query`), JSON schema, and UUID format are capability-relevant and are NOT violations.

## Domain Compliance Validation

**Domain:** EdTech (inferred from content — no frontmatter classification present)
**Complexity:** Medium (regulated)

### Required Special Sections (EdTech)

**Privacy Compliance:** Present and Adequate
- Section 7 covers FERPA "school official" designation, three-zone Tenant Enclave model, state-level laws (NY Ed Law § 2-d, SOPIPA), DPA requirement for OpenAI, and zero-retention mandate. Strong coverage.

**Student Data Controls:** Present and Adequate
- Zone C (Identity/Student Directory) defined as commented-out Terraform code; MVP explicitly excludes student data in Section 2.2 Non-Goals.

**Content Guidelines:** Partially Present
- Section 3.2 defines out-of-scope detection and hard refusal. No explicit content policy or guidelines section; no definition of what constitutes inappropriate content for the educator audience.

**Accessibility Features:** Not Acknowledged
- MVP is API-only (no UI), so WCAG compliance is not immediately applicable. However, this exclusion is not documented in Section 2.2 Non-Goals. Future portal phases will require accessibility requirements.

**Curriculum Alignment:** Partially Present
- Corpus selection (PLC @ Work® series) implies educational validity, but no formal curriculum alignment or educational standards statement exists.

### Compliance Matrix

| Requirement | Status | Notes |
|---|---|---|
| FERPA compliance | Met | Comprehensive coverage in Section 7 |
| Student data controls | Met | MVP exclusion explicit; Zone C architecture defined |
| Content guidelines | Partial | Out-of-scope detection present; no content policy |
| Accessibility (WCAG) | Not Acknowledged | N/A for MVP API, but exclusion should be explicit |
| Curriculum/educational validity | Partial | Implicit through corpus choice; not formalized |

**Required Sections Present:** 2/5 fully met, 2/5 partial, 1/5 not acknowledged

**Severity:** Warning

**Recommendation:** FERPA coverage is excellent and well-documented. Add explicit acknowledgment of accessibility deferral to Section 2.2 Non-Goals. Consider adding a brief content guidelines statement. The missing PRD frontmatter `classification.domain: edtech` should be added to make domain context machine-readable for downstream tools.

## Project-Type Compliance Validation

**Project Type:** api_backend (inferred — no frontmatter classification present)

### Required Sections

**Endpoint Specs:** Present — Section 5 is comprehensive with full request/response schemas and flow examples ✓

**Auth Model:** Present — Section 5.1 and 7.2 cover X-API-Key authentication ✓

**Data Schemas:** Present — Section 4 covers PostgreSQL and Qdrant schemas; Section 5.2–5.3 cover API schemas ✓

**Error Codes:** Present — Section 5.4 documents all 5 error scenarios with HTTP status codes ✓

**Rate Limits:** Missing — No rate limiting, throttling, or quota policy documented

**API Docs:** Partial — API documented in prose format; no formal OpenAPI/Swagger specification noted

### Excluded Sections (Should Not Be Present)

**UX/UI:** Absent ✓
**Visual Design:** Absent ✓
**User Journeys:** Absent ✓ (EXPECTED for api_backend — this RESOLVES the traceability gap noted in Step 6)

### Compliance Summary

**Required Sections:** 4/6 present, 1 missing (rate_limits), 1 partial (api_docs)
**Excluded Sections Present:** 0 violations
**Compliance Score:** ~67%

**Severity:** Warning

**Recommendation:** Add rate limiting documentation (even if "not enforced in MVP," acknowledge the policy). Consider noting intent to provide OpenAPI spec. The absence of User Journeys is confirmed correct behavior for an api_backend project type — the traceability finding in Step 6 should be treated as informational only (not a gap).

⚠️ **Traceability Correction:** User Journeys were flagged as missing in Step 6. Per project-types.csv, `user_journeys` is in the skip_sections list for api_backend. The Step 6 severity should be downgraded from Warning to Informational for this specific point.

## SMART Requirements Validation

**Total Functional Requirements Analyzed:** 13 Acceptance Criteria (AC-01 through AC-13)

### Scoring Summary

**All scores ≥ 3:** 92% (12/13)
**All scores ≥ 4:** 54% (7/13)
**Overall Average Score:** 4.4/5.0

### Scoring Table

| AC # | Specific | Measurable | Attainable | Relevant | Traceable | Average | Flag |
|------|----------|------------|------------|----------|-----------|---------|------|
| AC-01 | 4 | 3 | 5 | 5 | 4 | 4.2 | |
| AC-02 | 4 | 4 | 5 | 5 | 4 | 4.4 | |
| AC-03 | 4 | 4 | 4 | 5 | 4 | 4.2 | |
| AC-04 | 5 | 5 | 4 | 5 | 5 | 4.8 | |
| AC-05 | 5 | 5 | 4 | 5 | 4 | 4.6 | |
| AC-06 | 5 | 5 | 5 | 5 | 5 | 5.0 | |
| AC-07 | 5 | 4 | 4 | 5 | 4 | 4.4 | |
| AC-08 | 5 | 4 | 5 | 5 | 4 | 4.6 | |
| AC-09 | 5 | 5 | 4 | 5 | 5 | 4.8 | |
| AC-10 | 5 | 5 | 4 | 5 | 5 | 4.8 | |
| AC-11 | 5 | 5 | 3 | 5 | 5 | 4.6 | |
| AC-12 | 4 | 2 | 4 | 5 | 3 | 3.6 | ⚠️ |
| AC-13 | 3 | 3 | 4 | 5 | 3 | 3.6 | |

**Legend:** 1=Poor, 3=Acceptable, 5=Excellent | ⚠️ = score < 3 in one or more categories

### Improvement Suggestions

**AC-12 (flagged — Measurable = 2):** "coherent" is subjective and untestable. Replace with: "A query for a known in-scope topic returns an answer that includes ≥2 source citations with book title, SKU, page number, and text excerpt, and earns a Faithfulness score ≥ 0.80 on the RAGAS pipeline."

**AC-13 (borderline):** "relevant results" lacks a quantitative threshold. Suggest: "returns ≥1 result with chunk_type = reproducible." Also define "a query for a reproducible" more precisely (e.g., a query containing the word "reproducible" or "worksheet").

### Overall Assessment

**Severity:** Pass (< 10% flagged — only 1/13 ACs flagged)

**Recommendation:** FRs demonstrate strong overall quality (avg 4.4/5.0). Address AC-12 subjective language and AC-13 vague quantifier before downstream work begins. AC-11 attainability (score 3) reflects realistic concern — the RAGAS thresholds are ambitious; consider documenting the rationale for the chosen thresholds.

## Holistic Quality Assessment

### Document Flow & Coherence

**Assessment:** Good

**Strengths:**
- Clear narrative arc: problem → hypothesis → MVP scope → features → API contract → architecture → security → ACs → pre-work → decisions
- Decision Log (Section 10) is exceptional — explains rationale for 10 key choices; rare and valuable
- Evaluation Strategy (Section 2.3) with phased RAGAS approach is best-in-class for RAG validation documentation
- API specification (Section 5) with full request/response examples is immediately actionable

**Areas for Improvement:**
- Document blurs the what/how boundary — reads as combined PRD + architecture overview
- No distinct executive summary separating strategic vision from MVP goal definitions

### Dual Audience Effectiveness

**For Humans:**
- Executive-friendly: Strong — vision, goals, non-goals clearly communicated
- Developer clarity: Excellent — full API spec with examples, tech stack table
- Designer clarity: N/A for MVP (API-only)
- Stakeholder decision-making: Strong — Decision Log and ACs answer "why" and "when done"

**For LLMs:**
- Machine-readable structure: Adequate — ## headers consistent; no frontmatter classification
- UX readiness: Weak — no journeys, personas, or flows (expected for api_backend)
- Architecture readiness: Strong — Sections 4, 6, 7 provide rich LLM-consumable context
- Epic/Story readiness: Good — 13 numbered ACs with specific thresholds

**Dual Audience Score:** 3.5/5

### BMAD PRD Principles Compliance

| Principle | Status | Notes |
|-----------|--------|-------|
| Information Density | Met | Zero filler; every sentence informative |
| Measurability | Partial | ACs mostly measurable; AC-12 subjective; no formal NFR section |
| Traceability | Partial | Vision→Goals intact; api_backend correctly omits journeys |
| Domain Awareness | Partial | FERPA excellent; domain undeclared in frontmatter; content guidelines thin |
| Zero Anti-Patterns | Met | No filler or padding detected |
| Dual Audience | Partial | Strong for devs/architects; weaker for UX/story generation |
| Markdown Format | Partial | Tables and headers well-used; missing frontmatter; sections don't match BMAD standard names |

**Principles Met:** 2/7 fully, 5/7 partial

### Overall Quality Rating

**Rating:** 4/5 — Good

Strong technical depth and specificity, especially in evaluation strategy, API contract, and security architecture. Gaps are primarily BMAD structural (format compliance) rather than content gaps. Document is immediately useful to the engineering team. BMAD revisions would improve machine-readability for architecture and epic generation.

### Top 3 Improvements

1. **Refactor Section 3 to describe capabilities, not tools**
   Extract PyMuPDF/llmsherpa/GPT-4o Vision from requirements into the tech spec. Rewrite Section 3.1 in terms of what the system does ("classifies pages by layout, parses document hierarchy, generates descriptions for visual worksheet pages") rather than which tools accomplish it.

2. **Add a `## Non-Functional Requirements` section**
   Formalize measurable NFRs from Section 7's security prose (e.g., "TLS 1.2+ enforced at the ALB") and add an explicit availability acknowledgment ("Availability SLA deferred to Phase 2").

3. **Add PRD frontmatter with domain and project-type classification**
   A 5-line YAML block (`classification.domain: edtech`, `classification.projectType: api_backend`, version, date, status) makes this document machine-readable for BMAD tooling and self-documenting for collaborators.

### Summary

**This PRD is:** A technically strong, well-specified API PRD with excellent evaluation rigor and security architecture, that would benefit most from structural BMAD alignment — particularly separating requirements from implementation details and adding formalized NFRs.

## Completeness Validation

### Template Completeness

**Template Variables Found:** 0 — No template variables remaining ✓

### Content Completeness by Section

**Executive Summary:** Incomplete — Content present in Section 1 "Vision & Strategic Context" but not labeled as Executive Summary; lacks full scope statement

**Success Criteria:** Incomplete — Split between Section 2.1 "Key Goals" and Section 8 "Acceptance Criteria"; content exists but fragmented; Key Goals lack specific metrics

**Product Scope:** Complete — Section 2 MVP Goals & Scope plus Section 2.2 Non-Goals well-defined ✓

**User Journeys:** N/A — Expected absent for api_backend project type ✓

**Functional Requirements:** Incomplete — Narrative feature descriptions in Section 3, formal ACs in Section 8; not in standard FR format

**Non-Functional Requirements:** Missing — No dedicated section; security controls present in Section 7 prose but not structured as NFRs

### Section-Specific Completeness

**Success Criteria Measurability:** Some measurable — RAGAS thresholds in Section 2.3 are highly measurable; Key Goals in Section 2.1 are qualitative

**User Journeys Coverage:** N/A (api_backend)

**FRs Cover MVP Scope:** Yes — all in-scope items have corresponding ACs ✓

**NFRs Have Specific Criteria:** None — no NFR section exists

### Frontmatter Completeness

**stepsCompleted:** Missing
**classification:** Missing
**inputDocuments:** Missing
**date:** Missing from frontmatter (present in document body)

**Frontmatter Completeness:** 0/4

### Completeness Summary

**Overall Completeness:** ~60% against BMAD standard (3/6 standard sections complete or present)

**Critical Gaps:** 1 — NFR section missing
**Minor Gaps:** 3 — Executive Summary label/structure, Success Criteria fragmentation, Frontmatter entirely absent

**Severity:** Warning

**Recommendation:** PRD has minor-to-moderate completeness gaps. No template variables remain. Primary gaps are structural: add NFR section, consolidate or label Executive Summary, and add frontmatter. The 7 non-BMAD-standard sections (Data Models, API Specification, Architecture, Security, Acceptance Criteria, Corpus Analysis, Key Decisions) are all complete and high-quality.
