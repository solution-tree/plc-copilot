---
validationTarget: 'apps/api/docs/prd-v4.md'
validationDate: '2026-02-27'
inputDocuments:
  - apps/api/docs/prd-v4.md
  - apps/api/docs/research/ferpa-FINAL.md
  - _bmad-output/planning-artifacts/architecture.md
validationStepsCompleted: ['step-v-01-discovery', 'fr-review-party-mode']
validationStatus: IN_PROGRESS
---

# PRD Validation Report

**PRD Being Validated:** apps/api/docs/prd-v4.md (v4.5)
**Validation Date:** 2026-02-27

## Input Documents

- **PRD:** apps/api/docs/prd-v4.md (v4.5)
- **FERPA Research:** apps/api/docs/research/ferpa-FINAL.md
- **Architecture:** _bmad-output/planning-artifacts/architecture.md

## Validation Findings

### FR Completeness & Quality Review (Party Mode)

#### Missing FRs (High)

| # | Missing FR | Evidence | Action |
|---|---|---|---|
| 1 | Audit Logging | Section 7.2 describes capability; no FR traces to it | Add FR-017 |
| 2 | API Key Authentication | Section 5.1 describes it; AC #6 depends on it | Add FR-018 |
| 3 | Style Preference Collection | Section 2.3 Phase 3 Track B; AC #15 requires it | Add FR-019 |
| 4 | Minimal Test Client | Section 2.2 calls it in-scope | Add FR-020 |
| 5 | Health Check Endpoint | NFR-002 and NFR-009 depend on it existing | Add FR-021 |

#### Weak Test Criteria (Medium)

| # | FR | Issue | Action |
|---|---|---|---|
| 6 | FR-002 | "hierarchy preserved" is unverifiable as written | Tighten with spot-check methodology |
| 7 | FR-005 | "grounded" is subjective without metric reference | Cross-reference RAGAS Faithfulness from FR-014 |
| 8 | FR-010 | Fallback path (< 3 results) has no test criteria | Add fallback test case |
| 9 | FR-010 | Metadata extraction accuracy unmeasured | Add extraction accuracy threshold (>= 0.90) |
| 10 | FR-011/013 | Ablation thresholds ambiguous in purpose | Clarify as contribution-detection tests |
| 11 | FR-016 | "statistically meaningful" undefined | Replace with concrete aggregate comparison |

#### Other Findings (Low)

| # | Issue | Action |
|---|---|---|
| 12 | Golden dataset minimum of 5 ambiguous queries too small for precision/recall measurement | Increase to 10 in Section 2.3 |
| 13 | FR-002 contains 3 distinct processing paths — compound requirement | Note for epic decomposition (not a PRD defect) |

#### Resolution Status

All 13 findings have been resolved in PRD v4.5:

- **Actions 1–5:** FR-017 through FR-021 added (FR-017 as Style Preference under Section 3.4; FR-018–021 under new Section 3.5 Cross-Cutting Capabilities)
- **Action 6:** FR-002 test criteria tightened with spot-check methodology tied to FR-004 corpus scan
- **Action 7:** FR-005 parenthetical added cross-referencing RAGAS Faithfulness
- **Actions 8–9:** FR-010 test criteria expanded with fallback path coverage and extraction accuracy >= 0.90
- **Action 10:** FR-011 and FR-013 ablation tests clarified as contribution-detection, not quality gates
- **Action 11:** FR-016 test criteria replaced vague "statistically meaningful" with concrete aggregate comparison
- **Action 12:** Ambiguous query minimum increased from 5 to 10 (in-scope adjusted from 35 to 30 to maintain 50 total)
- **Action 13:** FR-002 flagged for story-level decomposition during epic breakdown — not a PRD defect

#### Downstream Note for Epic Planning

FR-002 (Layout-Aware Parsing) contains three distinct processing paths that should be decomposed into separate stories during epic breakdown:
1. Portrait pages with text layers → llmsherpa structural parsing
2. Landscape pages → GPT-4o Vision description generation
3. Pages without text layers → flagging for manual review

Each path has distinct implementation effort, test strategies, and dependencies.
