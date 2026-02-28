# Contributing to PLC Coach Service

## Introduction

This document outlines engineering conventions and collaborative workflow for the PLC Coach Service — a Python/FastAPI RAG API for educator PLC questions. As a small, AI-first team, establishing consistent patterns is crucial for maintaining code quality and enabling AI agents to write compatible, consistent code.

This handbook covers:
1. **Naming Conventions** — A unified language for code, database, and API
2. **Project Structure** — Layer-based organization and boundary rules
3. **Development Setup** — Getting started with the codebase
4. **Error Handling** — Exception hierarchy and patterns
5. **Logging** — Structured JSON conventions
6. **Testing** — Strategy, structure, and naming
7. **Database** — Alembic workflow and conventions
8. **FERPA Compliance** — Rules every contributor must follow
9. **Collaborative Workflow** — GitHub Flow and PR process

---

## Naming Conventions

### Core Principles

Every name in the codebase should:

1. **Reveal Intent** — A name should immediately answer: *Why does it exist? What does it do? How is it used?* Avoid generic names like `data`, `temp`, or `item`.
2. **Be Consistent** — If you use `fetch` for data retrieval in one place, don't use `get` or `retrieve` in another.
3. **Be Searchable** — Use names easy to find in a large codebase. `MAX_LOGIN_ATTEMPTS` is findable; the number `3` is not.
4. **Be Pronounceable** — Code is read and discussed. Names should be easy to say aloud.
5. **Avoid Disinformation** — Don't name a variable `user_list` if it isn't a list. Avoid ambiguous abbreviations.

### Python Code Conventions

| Element | Convention | Example |
|---|---|---|
| Modules/files | `snake_case` | `query_service.py`, `retrieval_service.py` |
| Classes | `PascalCase` | `QueryRequest`, `ChunkMetadata` |
| Functions/methods | `snake_case` | `process_query()`, `build_bm25_index()` |
| Variables | `snake_case` | `session_ttl`, `reranker_model` |
| Constants | `UPPER_SNAKE_CASE` | `SESSION_TTL_SECONDS`, `MAX_SOURCES` |
| Booleans | Prefix with `is_`, `has_`, `should_` | `is_ambiguous`, `has_session`, `should_cache` |
| Pydantic models | `PascalCase` class, `snake_case` fields | `class QueryResponse` with field `conversation_id` |

### Database Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Tables | Lowercase plural `snake_case` | `books`, `chunks`, `audit_logs` |
| Columns | `snake_case` | `book_id`, `chapter_number`, `page_number` |
| Foreign keys | `{referenced_table_singular}_id` | `book_id` references `books.id` |
| Indexes | `ix_{table}_{column(s)}` | `ix_chunks_book_id` |
| Unique constraints | `uq_{table}_{column(s)}` | `uq_books_sku` |
| Alembic migrations | Auto-generated prefix + description | `001_initial_schema.py` |

### API / JSON Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Endpoints | Lowercase `snake_case`, versioned | `/api/v1/query`, `/health` |
| JSON request fields | `snake_case` | `user_id`, `conversation_id`, `session_id` |
| JSON response fields | `snake_case` | `book_title`, `text_excerpt`, `clarification_question` |
| Headers | Standard HTTP conventions | `X-API-Key`, `Content-Type` |

---

## Project Structure

The project uses a **layer-based** architecture. See the [architecture doc](apps/api/docs/architecture.md) for the complete directory tree and rationale.

```
src/plc_copilot/
├── api/              # Route handlers and middleware
│   ├── routes/       # query.py, health.py
│   └── middleware/   # auth.py
├── models/           # SQLAlchemy models + Pydantic schemas
├── services/         # Business logic
├── repositories/     # PostgreSQL access only
├── retrieval/        # Qdrant, BM25, re-ranker, hybrid orchestrator
├── core/             # config.py, logging.py, exceptions.py
├── ingestion/        # Separate pipeline (parsers/, loaders/)
└── static/           # test_client.html
```

### Layer Boundaries and Call Direction

```
Routes → Services → Repositories (PostgreSQL)
                  → Retrieval (Qdrant, BM25, Re-ranker)
                  → Session/Cache (Redis)
```

**Strict rules:**

- **Routes** call services only. Routes never touch repositories, retrieval, or Redis directly.
- **Services** orchestrate business logic. They call repositories, retrieval, and cache/session services.
- **Repositories** handle database queries only. They never call services or other repositories.
- **Retrieval** handles search and ranking only. It never calls services or repositories.
- **Core** (config, logging, exceptions) is imported by all layers but never imports from them.
- **Ingestion** shares models and core config but is never imported by API code at runtime.

Violating layer boundaries is a PR rejection reason.

---

## Development Setup

For the full getting-started guide, see the [README](README.md).

**Quick start:**

```bash
uv sync                                           # Install dependencies
cp .env.example .env                               # Configure environment
docker compose -f docker-compose.dev.yml up -d     # Start PostgreSQL, Redis, Qdrant
uv run alembic upgrade head                        # Apply migrations
uv run pre-commit install                          # Install pre-commit hooks
uv run uvicorn plc_copilot.main:app --reload       # Start API
```

---

## Error Handling

### Exception Hierarchy

All application errors use a single hierarchy rooted in `PLCCopilotError` (defined in `core/exceptions.py`):

```python
class PLCCopilotError(Exception):
    status_code: int
    error_message: str

class SessionExpiredError(PLCCopilotError):
    status_code = 400
    error_message = "Session expired or not found. Please resubmit your original query."

class QueryProcessingError(PLCCopilotError):
    status_code = 503
    error_message = "The service is temporarily unavailable. Please try again."

class RetrievalError(PLCCopilotError):
    status_code = 503
    error_message = "The service is temporarily unavailable. Please try again."
```

### Rules

- Global handler via `app.exception_handler()` catches `PLCCopilotError` subclasses and maps to PRD error responses.
- Unhandled exceptions return `500` with `{"error": "An unexpected error occurred."}` — never leak stack traces.
- Third-party failures (OpenAI, Qdrant): catch at service layer, wrap in `PLCCopilotError` subclass, log original exception.
- Let FastAPI/Pydantic handle `422` validation errors natively.

### Anti-Patterns

```python
# WRONG: try/except in route handler
@router.post("/api/v1/query")
async def query(request: QueryRequest):
    try:
        result = await query_service.process(request)
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    # Exceptions should bubble to global handler

# WRONG: raw HTTPException in service code
raise HTTPException(status_code=404, detail="Not found")
# Should raise a PLCCopilotError subclass instead
```

---

## Logging Conventions

### Format

All logs are structured JSON — one JSON object per log line. Uses Python stdlib `logging` module (no third-party loggers).

### Required Fields

Every log entry must include:
- `timestamp` — ISO 8601 with UTC timezone
- `level` — ERROR, WARNING, INFO, or DEBUG
- `event` — `snake_case` verb-noun from the event catalog

When in request context, also include:
- `conversation_id`
- `user_id`
- `source_ip` (from `X-Forwarded-For` header)

### Event Catalog

All log events must be defined in the [architecture doc event catalog](apps/api/docs/architecture.md). Before adding a new event:

1. Follow the `subsystem_verb` or `subsystem_noun_verb` pattern
2. Add the event to the catalog in the architecture doc first
3. Never log PII — no query text, no user-identifiable content
4. Always include `conversation_id` when in request context

### Where Logging Happens

- Service layer and middleware: **yes**
- Route handlers: **no**
- Pydantic models: **no**

### Example

```python
# Correct: structured log event from the catalog
logger.info("query_completed", extra={
    "conversation_id": conversation_id,
    "user_id": user_id,
    "status": "success",
    "duration_ms": elapsed,
})
```

---

## Testing Strategy

### Structure

Tests mirror the source tree:

```
tests/
├── unit/              # Mirrors src/ structure — no external dependencies
├── integration/       # Tests against real services (PostgreSQL, Redis, Qdrant)
├── evaluation/        # RAGAS golden dataset pipeline
│   └── data/          # Golden dataset files (JSON or CSV)
├── load/              # Concurrency verification (NFR-003)
└── conftest.py        # Shared fixtures
```

### Mirroring Rule

If the source is `src/plc_copilot/services/query_service.py`, the test is `tests/unit/services/test_query_service.py`.

### Naming Convention

- Test files: `test_{module_name}.py`
- Test functions: `test_{behavior_being_tested}`
- Example: `test_ambiguous_query_returns_clarification()`

### What Runs Where

| Test Type | When | External Dependencies |
|---|---|---|
| Unit tests | PR pipeline (GitHub Actions) | None — all mocked |
| Integration tests | After staging deploy | Real PostgreSQL, Redis, Qdrant |
| Evaluation pipeline | Manual / scheduled | Running API endpoint |
| Load tests | Manual against staging | Running API endpoint |

---

## Database Conventions

### Alembic Workflow

1. Modify SQLAlchemy models in `models/`
2. Auto-generate migration: `uv run alembic revision --autogenerate -m "description"`
3. Review the generated migration script — auto-generate can miss edge cases
4. Apply: `uv run alembic upgrade head`
5. Commit the migration file with the code changes

### Rules

- All timestamps use `TIMESTAMP WITH TIME ZONE` — stored as UTC
- Migrations are always committed to the repository
- Never modify a migration that has been applied to staging or production — create a new migration instead
- Use `server_default` for database-level defaults where appropriate

---

## FERPA Compliance Rules

Every contributor must follow these rules. Violations are PR rejection reasons.

### DO

- Use `store: false` on every OpenAI API call (chat completion and embedding)
- Use hashed cache keys: `cache:{sha256(normalized_query_text)}`
- Keep all ingestion processing inside the VPC
- Use `user_id` as an opaque string — do not attempt to validate or enrich it
- Log audit events with the fields specified in the event catalog

### DON'T

- Log query text in production (or any environment)
- Log student names or student-identifiable content
- Use raw query text as a Redis key
- Store PII in any data store
- Send proprietary content outside the VPC
- Omit `store: false` from OpenAI API calls

---

## Collaborative Workflow — GitHub Flow

### Why GitHub Flow

| Aspect | GitHub Flow | Git Flow |
|---|---|---|
| Primary branches | `main` | `main` and `develop` |
| Feature branches | Created from `main` | Created from `develop` |
| Best for | Small teams, continuous delivery | Large teams, scheduled releases |
| Complexity | Low | High |

For a small team focused on rapid iteration, GitHub Flow reduces overhead while maintaining quality.

### The Flow in 6 Steps

1. **Create an issue and branch** — Branch from `main` using `{issue-number}/{descriptive-name}` (e.g., `17/add-health-endpoint`)
2. **Develop** — Write code following the conventions in this document
3. **Commit early and often** — Small atomic commits; pull latest from `main` regularly
4. **Open a pull request** — Link to the issue, provide a clear summary of changes
5. **Code review** — At least one approval required; reviewer checks architecture, logic, and conventions
6. **Merge and clean up** — Merge into `main`, delete the feature branch

### Branch Protection Rules

The following rules are enabled on `main`:

- Require a pull request before merging (no direct pushes)
- Require at least 1 approving review
- Dismiss stale approvals when new commits are pushed
- Require status checks to pass (ruff, mypy, unit tests)
- Require branch to be up to date before merging

### Deployment Model

- **Merge to `main`** automatically deploys to **staging**
- **Production deployment** is a manual trigger (separate GitHub Actions workflow)
- Staging mirrors production — test and validate there before promoting

### Pull Request Template

```markdown
**Issue:** #[issue_number]

**Description:**
A brief summary of the changes.

**Changes Made:**
- ...

**Checklist:**
- [ ] `ruff check .` passes with no errors
- [ ] `mypy src/` passes with no errors
- [ ] Unit tests pass (`uv run pytest tests/unit/`)
- [ ] No PII in logs — reviewed all log emission points
- [ ] New log events added to the event catalog in architecture.md
- [ ] Error handling uses `PLCCopilotError` subclasses (no raw HTTP exceptions)
- [ ] Layer boundaries respected (no business logic in routes, no DB calls in services)
- [ ] Database migrations committed (if schema changes)
- [ ] All timestamps use UTC
- [ ] JSON responses use `exclude_none=True`
```
