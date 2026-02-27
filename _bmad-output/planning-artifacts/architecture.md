---
stepsCompleted: [1, 2, 3]
inputDocuments:
  - apps/api/docs/prd-v4.md
  - apps/api/docs/prd-v4-validation-report.md
  - apps/api/docs/research/ferpa-FINAL.md
workflowType: 'architecture'
project_name: 'plc-copilot'
user_name: 'Nani'
date: '2026-02-26'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Guiding Architectural Principle

**Scale-ready, not scale-built.** This MVP is the first phase of an enterprise-level application targeting millions of users. Every architectural decision must pass a dual test: (1) Does it avoid over-engineering the MVP? (2) Would scaling require only configuration changes and infrastructure provisioning — not a rewrite? When in doubt, choose patterns and abstractions that scale horizontally, but deploy the minimal instance for MVP.

### Requirements Overview

**Functional Requirements:**
13 FRs across 3 subsystems:
- **Ingestion Pipeline (FR-001–004):** Batch processing of 25 PLC books from S3 into Qdrant + PostgreSQL. Three-stage parsing: PyMuPDF (classification) → llmsherpa (structure) → GPT-4o Vision (landscape pages). Runs inside VPC via SSM, not part of the live API.
- **Query Engine (FR-005–010):** Single API endpoint with 3 response modes: direct answer, conditional clarification (1-question hard limit via Redis session), and out-of-scope refusal. Includes ambiguity detection and dynamic metadata filtering.
- **Hybrid Search & Re-Ranking (FR-011–013):** Dual retrieval (BM25 keyword + vector semantic) with cross-encoder re-ranking before LLM generation. Quality-critical path with ablation test requirements.

**Non-Functional Requirements:**
7 NFRs scoped for internal testing:
- Response time: 30s P95 (1-3 concurrent users)
- Availability: 95% uptime during business hours
- Concurrency: 5 simultaneous queries
- Encryption: TLS 1.2+ in transit, KMS at rest (no exceptions)
- Audit logs: 90-day retention, no PII even in debug mode
- Backup/Recovery: RTO 4h, RPO 24h
- Security scanning: Critical/high CVEs blocked before deployment

**Scale & Complexity:**

- Primary domain: API backend (Python/FastAPI RAG service on AWS)
- Complexity level: Medium
- Estimated architectural components: 8 (API service, Qdrant, RDS, ElastiCache, S3, ALB, NAT Gateway, ingestion pipeline)
- Long-term target: Enterprise-level, millions of users

### Technical Constraints & Dependencies

- **Technology stack pre-decided:** Python 3.11+/FastAPI, LlamaIndex, Qdrant (self-hosted EC2), PostgreSQL (RDS), Redis (ElastiCache), OpenAI GPT-4o + text-embedding-3-large, cross-encoder/ms-marco-MiniLM-L-6-v2 (in-process)
- **Single AZ deployment** for MVP simplicity
- **HIPAA-eligible compute required** (Fargate, not App Runner)
- **External API dependency:** OpenAI (must have executed DPA with zero-retention)
- **VPC-contained ingestion:** Proprietary content never leaves VPC; ingestion triggered via GitHub Actions but executed via SSM Run Command on EC2
- **Ingestion is a separate workload** from the live API — runs as a Docker container only during batch processing

### Cross-Cutting Concerns Identified

- **FERPA compliance:** Shapes every data handling decision — self-hosted Qdrant, VPC-only ingestion, DPA requirements, no-PII audit logs, three-zone enclave model
- **Encryption:** Universal requirement — KMS at rest, TLS 1.2+ in transit, all data stores, all network communication
- **Audit logging:** Structured JSON logs for all key events, must never capture PII, 90-day retention
- **Secrets management:** All credentials and API keys in AWS Secrets Manager, IAM least-privilege for all service-to-service access
- **VPC networking:** Private subnets for all data stores and compute, public subnet for ALB only, NAT gateway for controlled egress
- **Observability:** CloudWatch log groups for Fargate service (basic for MVP); dashboards and distributed tracing deferred

## Starter Template Evaluation

### Primary Technology Domain

API backend (Python/FastAPI RAG service on AWS) based on project requirements analysis.

### Technical Tooling Decisions

| Category | Selection | Rationale | Alternatives Considered |
|---|---|---|---|
| Package Manager | **uv** | 10-100x faster than alternatives, handles Python version management, PEP 621 compliant `pyproject.toml`, single binary, native workspace support for future monorepo | Poetry (heavier, slower, better for PyPI publishing — not relevant here), PDM (good but smaller community momentum), pip (no lockfile, no dependency resolution) |
| Testing | **pytest** | Industry standard, native FastAPI `TestClient` integration, rich plugin ecosystem | unittest (more verbose, no fixture system), nose2 (smaller community) |
| Linting & Formatting | **ruff** | Replaces black + flake8 + isort + autoflake in a single Rust-based tool, current Python standard | black + flake8 + isort (3 separate tools, 3 configs), pylint (heavy, slow) |
| Type Checking | **mypy** | Standard Python type checker, strong Pydantic/FastAPI integration | pyright (also viable but mypy more established in Python ecosystem) |
| Pre-commit | **pre-commit** | Enforces ruff + mypy on every commit, prevents quality regressions | Manual enforcement (unreliable) |

### Starter Options Considered

| Starter | Evaluated | Verdict |
|---|---|---|
| fastapi-template-uv | Good tooling (uv + ruff + pytest) | Too generic — no RAG, no dual-store pattern |
| py-fastapi-starter | Clean modular architecture | No RAG patterns, wrong deployment model |
| fastapi-production-template | Docker + CI/CD included | Targets Render/Koyeb, not AWS Fargate |
| **Custom scaffold (uv init)** | Full control over structure | **Best fit for domain-specific requirements** |

### Selected Approach: Custom Scaffold via `uv init`

**Rationale:** No existing starter template addresses the project's specific requirements: LlamaIndex RAG orchestration, Qdrant + PostgreSQL dual storage, hybrid BM25/vector search, FERPA-compliant VPC architecture, and a separate ingestion pipeline workload. A custom scaffold avoids rip-and-replace overhead while adopting current best-practice tooling.

**Initialization Commands:**

```bash
uv init plc-copilot-api
cd plc-copilot-api
uv add fastapi pydantic uvicorn
uv add --dev pytest pytest-asyncio pytest-cov ruff mypy pre-commit
```

### Scale-Ready Enhancements (from ADR Review)

**uv Workspace Readiness:** The single-package `uv init` is MVP-appropriate. The `pyproject.toml` structure is natively workspace-compatible — when the project grows to include separate packages (e.g., `plc-copilot-ingestion`, `plc-copilot-eval`, `plc-copilot-shared`), uv workspaces can be enabled without migration. No action needed now; the pattern scales naturally.

**Async Test Infrastructure:** `pytest-asyncio` is included from day one because FastAPI is async. `pytest-cov` is included with a minimum coverage gate configured in CI from the first story. These are not optional for a production async service.

**Test Directory Structure:** The scaffold must establish a test directory structure that mirrors the application and supports the PRD's evaluation requirements:
- `tests/unit/` — Unit tests for individual components
- `tests/integration/` — Integration tests for component interactions (Qdrant, RDS, Redis)
- `tests/evaluation/` — Golden dataset evaluation pipeline, ablation tests (FR-011, FR-013), RAGAS scoring

**Retrieval Layer Abstraction (Forward Flag):** The retrieval mechanism (BM25 + vector + re-ranker) should be structured behind an abstraction that allows the implementation to be swapped without changing the query engine. This is an architectural decision for Step 4, flagged here because the project structure must accommodate it.

**Note:** Project initialization using these commands should be the first implementation story.
