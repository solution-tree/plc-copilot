---
description: API contract and schema rules for the PLC Coach query endpoint
globs:
  - "apps/api/src/api/**"
  - "apps/api/src/schemas/**"
  - "apps/api/tests/**"
---

# API Design Rules

## Source of Truth

PRD v4 Section 5: `@apps/api/docs/prd-v4.md`

## Single Endpoint

`POST /api/v1/query` — the only endpoint for MVP.

## Request Schema

```python
class QueryRequest(BaseModel):
    query: str                    # Required — the user's question
    user_id: str                  # Required — client-provided, for logging/tracing only
    conversation_id: str          # Required — client-generated UUID, echoed in every response
    session_id: str | None = None # Optional — server-generated, sent only on clarification follow-ups
```

- `conversation_id` is sent with EVERY request and echoed in EVERY response. Foundation for Phase 2 memory.
- `session_id` is present ONLY when following up on a `needs_clarification` response.

## Response Schema — Three Statuses

### `success`

```json
{
  "status": "success",
  "conversation_id": "conv-uuid-1234",
  "answer": "...",
  "sources": [
    {
      "book_title": "Learning by Doing: A Handbook for PLCs at Work",
      "sku": "BKF219",
      "page_number": 36,
      "text_excerpt": "...first 200 characters of source passage..."
    }
  ]
}
```

If the response resolves a clarification, include `session_id` in the response as well.

### `needs_clarification`

```json
{
  "status": "needs_clarification",
  "conversation_id": "conv-uuid-1234",
  "session_id": "uuid-goes-here-1234",
  "clarification_question": "Are you asking about formative or summative assessment?"
}
```

### `out_of_scope`

```json
{
  "status": "out_of_scope",
  "conversation_id": "conv-uuid-1234",
  "message": "I can only answer questions based on the PLC @ Work\u00ae book series. This question falls outside that scope."
}
```

- The `message` field uses a **fixed refusal string** — never dynamically generated.
- 100% refusal rate required for out-of-scope test queries.

## Source Citation Fields

Every source object MUST contain exactly these fields:

| Field | Type | Description |
|-------|------|-------------|
| `book_title` | string | Full book title |
| `sku` | string | Solution Tree SKU (e.g., BKF219) |
| `page_number` | integer | Source page number |
| `text_excerpt` | string | First 200 characters of the source passage |

Do NOT use `authors` or `excerpt` — those are not in the PRD v4 source schema.

## Conditional Clarification Rules

Clarification is **conditional**, not mandatory. The system asks a clarifying question ONLY when the query is ambiguous.

### Ambiguity Definition

A query is ambiguous ONLY if **both** conditions are true:
1. The answer would differ meaningfully depending on interpretation.
2. The system cannot determine the correct interpretation from the text alone.

### Three Ambiguity Categories

| Category | Example |
|----------|---------|
| Topic Ambiguity | "What does Learning by Doing say about assessment?" (formative vs. summative vs. common) |
| Scope Ambiguity | "Tell me about PLCs" (too broad) |
| Reference Ambiguity | "What does DuFour say about teams?" (multiple team contexts) |

### One-Question Hard Limit

- Maximum ONE clarifying question per session.
- If the follow-up is still ambiguous, answer with the best interpretation and explicitly state the interpretation chosen.
- NEVER ask a second clarifying question.

## Error Responses

| Scenario | HTTP Status | Body |
|----------|-------------|------|
| Missing/invalid API key | 401 | `{"error": "Unauthorized"}` |
| Malformed request body | 422 | FastAPI/Pydantic validation error |
| Expired/invalid `session_id` | 400 | `{"error": "Session expired or not found..."}` |
| LLM or vector DB failure | 503 | `{"error": "Service temporarily unavailable..."}` |
| Unexpected error | 500 | `{"error": "An unexpected error occurred."}` |

## Pydantic Conventions

- Use Pydantic v2 `BaseModel` for all request/response schemas.
- Place schemas in `apps/api/src/schemas/`.
- Use `model_validator` for cross-field validation (e.g., `session_id` required when following up).
- Use `Field(description=...)` for OpenAPI documentation.

## Identifier Lifecycle

| Field | Scope | Created By | Lifecycle |
|-------|-------|------------|-----------|
| `conversation_id` | Entire thread | Client | Sent every request, echoed every response |
| `session_id` | One clarification loop | Server | Generated on `needs_clarification`, present in resolved `success`, discarded after |
