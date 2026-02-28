# PLC Coach Service

An AI-powered coaching API for educators, grounded in the Professional Learning Community (PLC) @ Work book series. The service uses a RAG (Retrieval-Augmented Generation) pipeline — combining hybrid BM25 + vector search, cross-encoder re-ranking, and GPT-4o generation — to deliver precise, cited answers from a curated 25-book corpus. Designed as the foundational step toward a comprehensive coaching ecosystem that can incorporate local context such as meeting transcripts and student data.

## Status

**MVP — Internal Testing Phase**

The service is being built for a small internal testing team (1–3 users). Not yet deployed to production or exposed to external users.

## Tech Stack

| Component | Technology |
|---|---|
| Language / Framework | Python 3.11+ / FastAPI / Pydantic |
| Package Manager | uv |
| RAG Orchestration | LlamaIndex |
| Vector Database | Qdrant (self-hosted on EC2) |
| Relational Database | PostgreSQL 15+ (Amazon RDS) |
| Cache / Sessions | Redis 7+ (Amazon ElastiCache) |
| LLM | OpenAI GPT-4o |
| Embeddings | OpenAI text-embedding-3-large |
| Re-ranker | cross-encoder/ms-marco-MiniLM-L-6-v2 (in-process) |
| Keyword Search | rank_bm25 |
| ORM / Migrations | SQLAlchemy 2.0 / Alembic |
| Linting / Formatting | ruff |
| Type Checking | mypy |
| Testing | pytest / pytest-asyncio / pytest-cov |
| Infrastructure | Terraform / AWS Fargate / GitHub Actions |

## Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (package manager)
- Docker and Docker Compose
- AWS CLI (configured for deployment)
- OpenAI API key

## Getting Started

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd plc-copilot
   ```

2. **Install dependencies**

   ```bash
   uv sync
   ```

3. **Set up environment variables**

   ```bash
   cp .env.example .env
   # Edit .env with your local configuration (API keys, database URLs, etc.)
   ```

4. **Start local services**

   ```bash
   docker compose -f docker-compose.dev.yml up -d
   ```

   This starts PostgreSQL, Redis, and Qdrant containers for local development.

5. **Apply database migrations**

   ```bash
   uv run alembic upgrade head
   ```

6. **Install pre-commit hooks**

   ```bash
   uv run pre-commit install
   ```

7. **Start the API server**

   ```bash
   uv run uvicorn plc_copilot.main:app --reload
   ```

   The API is available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

## Project Structure

The project follows a layer-based architecture. See the [architecture doc](apps/api/docs/architecture.md) for the complete directory tree.

```
src/plc_copilot/
├── api/              # Route handlers and middleware (auth, routes)
├── models/           # SQLAlchemy ORM models and Pydantic schemas
├── services/         # Business logic (query orchestration, session, cache)
├── repositories/     # PostgreSQL data access layer
├── retrieval/        # Hybrid search (vector, BM25, re-ranker, orchestrator)
├── core/             # Configuration, structured logging, exception hierarchy
├── ingestion/        # Separate pipeline for PDF processing (parsers, loaders)
└── static/           # Minimal test client HTML
```

```
tests/
├── unit/             # Unit tests (mirrors src/ structure)
├── integration/      # Tests against real services (PostgreSQL, Redis, Qdrant)
├── evaluation/       # RAGAS evaluation pipeline and golden dataset
└── load/             # Concurrency verification (5 simultaneous queries)
```

## Development

**Run unit tests:**

```bash
uv run pytest tests/unit/
```

**Run integration tests** (requires docker-compose services):

```bash
uv run pytest tests/integration/
```

**Lint and format:**

```bash
uv run ruff check .
uv run ruff format .
```

**Type check:**

```bash
uv run mypy src/
```

**Create a database migration:**

```bash
uv run alembic revision --autogenerate -m "description of changes"
```

**Run ingestion pipeline locally:**

```bash
uv run python -m plc_copilot.ingestion
```

## API Overview

**Single endpoint:** `POST /api/v1/query`

**Authentication:** Static API key in the `X-API-Key` request header.

**Three response modes:**

| Status | Meaning |
|---|---|
| `success` | Direct answer with source citations (book title, SKU, page number, text excerpt) |
| `needs_clarification` | Ambiguous query — returns a single clarifying question with a `session_id` |
| `out_of_scope` | Query outside the PLC book corpus — returns a hard refusal message |

**Health check:** `GET /health` (unauthenticated, used by ALB)

## Deployment

- **Infrastructure:** Terraform modules for VPC, RDS, ElastiCache, Qdrant EC2, ECS/Fargate, ALB, S3
- **CI/CD:** GitHub Actions — PR pipeline (ruff, mypy, unit tests) and merge pipeline (build, Trivy scan, deploy)
- **Environments:** Staging (auto-deploy on merge to main) and Production (manual promotion)
- **Ingestion:** Triggered via GitHub Actions, executed inside VPC via SSM Run Command

## Documentation

| Document | Path | Description |
|---|---|---|
| PRD | [`apps/api/docs/prd.md`](apps/api/docs/prd.md) | Product requirements and acceptance criteria |
| Architecture | [`apps/api/docs/architecture.md`](apps/api/docs/architecture.md) | Technical decisions, patterns, project structure |
| FERPA Research | [`apps/api/docs/research/ferpa-FINAL.md`](apps/api/docs/research/ferpa-FINAL.md) | Compliance constraints and security model |
| Contributing | [`CONTRIBUTING.md`](CONTRIBUTING.md) | Development workflow, conventions, PR process |
| AI Agent Guide | [`CLAUDE.md`](CLAUDE.md) | Concise rules for AI coding agents |
