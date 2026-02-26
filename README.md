# PLC Co-Pilot

AI-powered tools for educators built around Professional Learning Communities (PLCs).

## Current Focus: PLC Coach Service

The MVP is a **RAG-based API** that answers educator questions grounded exclusively in Solution Tree's 25 PLC @ Work books. The core hypothesis: a high-quality, book-only retrieval service delivers enough value to educators to justify the larger FERPA-compliant platform planned for later phases.

**Status:** Documentation and blueprint phase — no application code yet.

## Documentation

| Document | Path | Description |
|----------|------|-------------|
| PRD v4 | [`apps/api/docs/prd-v4.md`](apps/api/docs/prd-v4.md) | Product requirements, architecture, schemas, acceptance criteria |
| FERPA Report | [`apps/api/docs/research/ferpa-FINAL.md`](apps/api/docs/research/ferpa-FINAL.md) | Compliance strategy, tenant enclave model, data policies |
| Claude Code Context | [`CLAUDE.md`](CLAUDE.md) | Project context for Claude Code sessions |
| Contributing Guide | [`CONTRIBUTING.md`](CONTRIBUTING.md) | Repo organization, naming conventions, GitHub Flow workflow |

## Apps

| App | Path | Status | Description |
|-----|------|--------|-------------|
| API (PLC Coach) | `apps/api/` | Active (docs only) | RAG query endpoint for PLC book content |
| Teachers Portal | `apps/teachers-portal/` | Planned | Frontend for educators |
| Admins Portal | `apps/admins-portal/` | Planned | Frontend for administrators |

## Technology Stack

- **Language:** Python 3.11+ with FastAPI and Pydantic v2
- **RAG:** LlamaIndex with hybrid search (vector + BM25) and cross-encoder re-ranking
- **Vector DB:** Qdrant (self-hosted on EC2 in private VPC)
- **LLM:** GPT-4o via OpenAI API (zero-retention with DPA)
- **Embeddings:** `text-embedding-3-large` (3,072 dimensions)
- **Infrastructure:** AWS (Fargate, RDS, ElastiCache, S3), Terraform, GitHub Actions

See PRD v4 Section 6 for the full stack and rationale.

## Getting Started

1. Read the [PRD v4](apps/api/docs/prd-v4.md) for product requirements and architecture.
2. Read [CONTRIBUTING.md](CONTRIBUTING.md) for workflow and conventions.
3. See [CLAUDE.md](CLAUDE.md) for project context when using Claude Code.
