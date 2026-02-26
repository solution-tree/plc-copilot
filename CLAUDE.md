# PLC Co-Pilot — Claude Code Context

## Project Overview

Monorepo for PLC Co-Pilot, a suite of AI-powered tools for educators built around Professional Learning Communities (PLCs). The current focus is the **PLC Coach Service** — a RAG-based API that answers educator questions grounded exclusively in Solution Tree's 25 PLC @ Work books. The core hypothesis: a high-quality, book-only RAG service delivers enough value to educators to justify the larger FERPA-compliant platform. The long-term vision includes meeting transcription (Zone B) and student data (Zone C), but the MVP handles book content only (Zone A). The project is currently in the **documentation and blueprint phase** — no application code has been written yet.

## Source of Truth Documents

| Document | Path | Purpose |
|----------|------|---------|
| PRD v4 | `apps/api/docs/prd-v4.md` | Product spec — all features, schemas, architecture |
| FERPA report | `apps/api/docs/research/ferpa-FINAL.md` | Compliance strategy, tenant enclave model, data policies |
| CONTRIBUTING.md | `CONTRIBUTING.md` | Repo organization, workflow (GitHub Flow), PR templates |
| Golden dataset | `apps/api/tests/fixtures/golden_dataset.json` | Evaluation queries (in-scope + out-of-scope) |

When PRD v4 and any other document conflict, **PRD v4 wins**.

## Technology Stack (PRD v4 Section 6)

| Component | Technology | Notes |
|-----------|------------|-------|
| Framework | Python 3.11+, FastAPI, Pydantic v2 | Async, strong validation |
| RAG orchestration | LlamaIndex | Hybrid search, re-ranking, generation |
| Compute (API) | Docker on AWS Fargate | HIPAA-eligible, single container with re-ranker |
| Vector DB | Qdrant on EC2 | Self-hosted in private VPC, `plc_copilot_v1`, 3072 dims |
| PDF parser | PyMuPDF + llmsherpa + GPT-4o Vision | Three-stage hybrid; llmsherpa is Docker, ingestion-only |
| Re-ranker | `cross-encoder/ms-marco-MiniLM-L-6-v2` | In-process, loaded at API startup |
| Relational DB | PostgreSQL 15+ on RDS | Books, chunks, audit |
| Session cache | Redis 7+ on ElastiCache | Clarification loop state |
| File storage | Amazon S3 | Source PDFs, versioning enabled |
| LLM & embeddings | GPT-4o, `text-embedding-3-large` | OpenAI API, zero-retention with DPA |
| IaC | Terraform | All AWS resources |
| CI/CD | GitHub Actions | Lint, test, build, deploy to Fargate |

## Repository Structure

```
plc-copilot/
├── apps/
│   ├── api/                          # PLC Coach Service (Active — docs only, no code yet)
│   │   ├── docs/
│   │   │   ├── prd-v4.md
│   │   │   └── research/
│   │   │       └── ferpa-FINAL.md
│   │   └── tests/
│   │       └── fixtures/
│   │           └── golden_dataset.json
│   ├── teachers-portal/              # (Planned — empty)
│   └── admins-portal/                # (Planned — empty)
├── packages/                         # (Planned — shared code, empty)
├── .claude/
│   ├── settings.json
│   └── rules/
│       ├── api-design.md
│       ├── security.md
│       └── ingestion.md
├── CLAUDE.md                         # (this file)
├── CONTRIBUTING.md
└── README.md
```

## Code Style (Python)

The API is Python — these conventions override the JS/TS conventions in CONTRIBUTING.md:

| Element | Convention | Example |
|---------|-----------|---------|
| Variables & functions | `snake_case` | `query_engine`, `get_user_id()` |
| Classes | `PascalCase` | `QueryRequest`, `ChunkMetadata` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_RETRIES`, `COLLECTION_NAME` |
| Files & directories | `snake_case` | `query_engine.py`, `scope_guard.py` |

- Linter: **ruff** (format + lint)
- Type hints required on all public function signatures
- Pydantic v2 `BaseModel` for all API schemas

## Key Commands

```bash
# Lint (when code exists)
ruff check apps/api/src/

# Tests (when code exists)
pytest apps/api/tests/ -v

# Git
git status
git diff
git log --oneline -10
```

Terraform and ingestion scripts are future work — do not stub them.

## Hard Constraints

1. **Zero-retention OpenAI** — DPA executed, zero data retention confirmed before any production use.
2. **No secrets in code** — all secrets from AWS Secrets Manager via IAM; `.env` files gitignored.
3. **Stick to the stack** — do not introduce frameworks or services not in PRD v4 Section 6.
4. **PRD v4 is the spec** — when in doubt, read `apps/api/docs/prd-v4.md`.
5. **Terraform only** — no ClickOps, CloudFormation, or CDK for AWS resources.
6. **Ingestion inside VPC** — proprietary content processed via SSM on EC2, never on public runners.
7. **Encryption everywhere** — KMS at rest, TLS 1.2+ in transit.
8. **No PII in logs** — metadata only, even in debug mode.
