# CLAUDE.md — PLC Coach Service

## Project Overview

RAG-powered API for educator PLC (Professional Learning Community) questions. Single endpoint (`POST /api/v1/query`) backed by hybrid BM25 + vector search, cross-encoder re-ranking, and GPT-4o generation over a 25-book corpus. MVP phase — internal testing only, 1–3 users. Separate ingestion pipeline processes PDFs into Qdrant + PostgreSQL.

## Source of Truth

| Document | Path | Scope |
|---|---|---|
| PRD | `apps/api/docs/prd.md` | Product requirements, acceptance criteria, API contract |
| Architecture | `apps/api/docs/architecture.md` | All technical decisions, patterns, structure |
| FERPA Research | `apps/api/docs/research/ferpa-FINAL.md` | Compliance constraints |

**Architecture doc wins on conflicts.** If this file contradicts the architecture doc, the architecture doc is correct.

## Tech Stack

- **Language/Framework:** Python 3.11+ / FastAPI / Pydantic
- **Package Manager:** uv
- **RAG Orchestration:** LlamaIndex
- **Vector Store:** Qdrant (self-hosted EC2)
- **Relational DB:** PostgreSQL (RDS) via SQLAlchemy 2.0 + Alembic
- **Cache/Sessions:** Redis (ElastiCache)
- **LLM:** OpenAI GPT-4o (`store: false` on every request)
- **Embeddings:** OpenAI text-embedding-3-large (3,072 dimensions)
- **Re-ranker:** cross-encoder/ms-marco-MiniLM-L-6-v2 (in-process)
- **Keyword Search:** rank_bm25 (serialized with pickle, loaded from S3)
- **Linting/Formatting:** ruff
- **Type Checking:** mypy
- **Testing:** pytest + pytest-asyncio + pytest-cov
- **Pre-commit:** pre-commit (ruff + mypy hooks)
- **Infrastructure:** Terraform, GitHub Actions, AWS Fargate

## Project Structure

```
src/plc_copilot/
├── api/              # Route handlers
│   ├── routes/       # query.py, health.py
│   └── middleware/   # auth.py
├── models/           # SQLAlchemy models + Pydantic schemas
├── services/         # Business logic (query, session, cache)
├── repositories/     # PostgreSQL access only
├── retrieval/        # Qdrant vector, BM25 keyword, re-ranker, hybrid orchestrator
├── core/             # config.py, logging.py, exceptions.py
├── ingestion/        # Separate pipeline (parsers/, loaders/)
└── static/           # test_client.html (FR-021)
```

```
tests/
├── unit/             # Mirrors src/ structure
├── integration/      # Real services (RDS, Redis, Qdrant)
├── evaluation/       # RAGAS golden dataset pipeline
│   └── data/         # golden_dataset.json
└── load/             # NFR-003 concurrency verification
```

## Layer Boundaries

```
Routes → Services → Repositories (PostgreSQL)
                  → Retrieval (Qdrant, BM25, Re-ranker)
                  → Session/Cache (Redis)
```

**Rules:**
- Routes call services. **Never** call repositories or retrieval directly.
- Services orchestrate business logic. Services call repositories, retrieval, and Redis services.
- Repositories handle database queries only. Never call services or other repositories.
- Retrieval modules handle search/ranking only. Never call services or repositories.
- Core (config, logging, exceptions) is imported by all layers but never imports from them.
- Ingestion shares models and core config but is never imported by API code at runtime.

## Development Commands

```bash
# Start local services (PostgreSQL, Redis, Qdrant)
docker compose -f docker-compose.dev.yml up -d

# Apply database migrations
uv run alembic upgrade head

# Start API server (development)
uv run uvicorn plc_copilot.main:app --reload

# Run ingestion pipeline locally
uv run python -m plc_copilot.ingestion

# Run unit tests
uv run pytest tests/unit/

# Run integration tests (requires docker-compose services)
uv run pytest tests/integration/

# Lint and format
uv run ruff check .
uv run ruff format .

# Type check
uv run mypy src/

# Run all pre-commit hooks
pre-commit run --all-files

# Create a new migration
uv run alembic revision --autogenerate -m "description"
```

## Naming Conventions

### Python Code

| Element | Convention | Example |
|---|---|---|
| Modules/files | `snake_case` | `query_engine.py` |
| Classes | `PascalCase` | `QueryRequest` |
| Functions/methods | `snake_case` | `process_query()` |
| Variables | `snake_case` | `session_ttl` |
| Constants | `UPPER_SNAKE_CASE` | `SESSION_TTL_SECONDS` |
| Pydantic models | `PascalCase` class, `snake_case` fields | `class QueryResponse`, field `conversation_id` |

### Database

| Element | Convention | Example |
|---|---|---|
| Tables | lowercase plural `snake_case` | `books`, `chunks`, `audit_logs` |
| Columns | `snake_case` | `book_id`, `chapter_number` |
| Foreign keys | `{referenced_table_singular}_id` | `book_id` → `books.id` |
| Indexes | `ix_{table}_{column(s)}` | `ix_chunks_book_id` |
| Unique constraints | `uq_{table}_{column(s)}` | `uq_books_sku` |

### API / JSON

| Element | Convention | Example |
|---|---|---|
| Endpoints | lowercase `snake_case`, versioned | `/api/v1/query` |
| Request/response fields | `snake_case` | `conversation_id`, `session_id` |
| Headers | HTTP standard | `X-API-Key`, `Content-Type` |

## Error Handling

- **Base class:** `PLCCopilotError` in `core/exceptions.py`
- **Subclasses:** `SessionExpiredError`, `QueryProcessingError`, `RetrievalError`, etc.
- **Global handler:** `app.exception_handler()` catches `PLCCopilotError` subclasses → maps to PRD error bodies
- **Unhandled exceptions:** catch-all returns `500` with `{"error": "An unexpected error occurred."}` — never leak stack traces
- **Third-party failures:** catch at service layer, wrap in `PLCCopilotError` subclass, log original exception
- **Validation:** let FastAPI/Pydantic handle `422` natively
- **No try/except in route handlers.** Exceptions bubble up, get caught once at the global handler.

## Logging

- **Library:** Python stdlib `logging` (no third-party loggers)
- **Format:** Structured JSON — one JSON object per log line
- **Required fields:** `timestamp` (ISO 8601 UTC), `level`, `event`, `conversation_id` (when available), `user_id` (when in request context), `source_ip` (from `X-Forwarded-For`)
- **Forbidden:** Any PII — no query text in production logs, no student names
- **Where:** Service layer and middleware only. Not in route handlers. Not in Pydantic models.
- **Event naming:** `snake_case` verb-noun, prefixed by subsystem (`query_*`, `ingestion_*`, `health_*`)
- **Event catalog:** Defined in architecture.md. All events must be in the catalog — no undocumented events.

## Date/Time

- **Everything is UTC, always.** No local timezone conversion anywhere.
- Use `datetime.datetime.now(datetime.timezone.utc)` — never `datetime.datetime.now()`.
- Database columns: `TIMESTAMP WITH TIME ZONE`.
- API responses and logs: ISO 8601 with UTC timezone (`2026-02-27T14:30:00Z`).

## Response Format

- `status` field is the discriminator: `success`, `needs_clarification`, `out_of_scope`
- Pydantic `model_config` uses `exclude_none=True` — omit absent optional fields, never send `null`
- Error bodies follow PRD Section 5.4: flat `{"error": "..."}` format

### PRD Error Bodies (exact text)

| Status | Body |
|---|---|
| `401` | `{"error": "Unauthorized"}` |
| `400` | `{"error": "Session expired or not found. Please resubmit your original query."}` |
| `503` | `{"error": "The service is temporarily unavailable. Please try again."}` |
| `500` | `{"error": "An unexpected error occurred."}` |
| `422` | FastAPI/Pydantic default |

## FERPA / Security Rules

- **No PII in logs** — not even in debug mode. `user_id` is an opaque string, not validated PII.
- **OpenAI:** `store: false` on every chat completion and embedding request.
- **VPC-contained ingestion:** proprietary content never leaves VPC. Ingestion triggered by GitHub Actions but executed via SSM on EC2.
- **API key in `X-API-Key` header** — stored in AWS Secrets Manager, injected via env var.
- **Qdrant API key enabled** — defense-in-depth beyond VPC isolation.
- **Cache keys:** `cache:{sha256(normalized_query_text)}` — never use raw query text as Redis key.
- **S3 bucket:** private, versioned, IAM-restricted.

## What NOT to Do

- **No `camelCase`** for Python variables, functions, database columns, or JSON fields
- **No naive datetimes** — always use `timezone.utc`
- **No PII in logs** — no query text, no student names, no student-identifiable content
- **No business logic in route handlers** — routes call services only
- **No undocumented log events** — every event must be in the architecture.md event catalog
- **No try/except in routes** — let exceptions bubble to global handler
- **No `null` in JSON responses** — use Pydantic `exclude_none=True`
- **No direct database calls in services** — go through repositories
- **No direct Qdrant/BM25 calls in services** — go through retrieval layer
- **No raw HTTP exceptions in service code** — raise `PLCCopilotError` subclasses
- **No `PascalCase` table names** — use lowercase plural `snake_case`
- **No importing API code from ingestion or vice versa at runtime**
- **No `store: true`** (or omitting `store`) on OpenAI API calls
