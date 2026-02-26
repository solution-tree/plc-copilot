# PLC Coach API — Claude Code Context

## Current State

This app is in the **documentation and blueprint phase**. No application code exists yet.
The directory currently contains:

```
apps/api/
├── docs/
│   ├── prd-v4.md                    # Product Requirements Document (source of truth)
│   └── research/
│       └── ferpa-FINAL.md           # FERPA compliance report
└── tests/
    └── fixtures/
        └── golden_dataset.json      # Evaluation dataset (in-scope + out-of-scope)
```

## Planned Source Layout

```
apps/api/
├── src/
│   ├── api/
│   │   ├── main.py                  # FastAPI app, lifespan, middleware
│   │   └── routes/
│   │       └── query.py             # POST /api/v1/query handler
│   ├── schemas/
│   │   ├── request.py               # QueryRequest (Pydantic v2)
│   │   └── response.py              # QueryResponse, Source, error models
│   ├── services/
│   │   ├── query_engine.py          # LlamaIndex orchestration, hybrid search, re-rank
│   │   ├── clarification.py         # Ambiguity detection, session management (Redis)
│   │   └── scope_guard.py           # Out-of-scope detection
│   ├── ingestion/
│   │   ├── pipeline.py              # Three-stage parser orchestrator
│   │   ├── pymupdf_classifier.py    # Page orientation + text-layer detection
│   │   ├── llmsherpa_parser.py      # Portrait page parsing via nlm-ingestor
│   │   ├── vision_parser.py         # Landscape page → GPT-4o Vision
│   │   └── metadata.py              # ChunkMetadata schema + validation
│   └── config/
│       └── settings.py              # Pydantic Settings (from env / Secrets Manager)
├── scripts/
│   ├── corpus_scan.py               # Pre-build corpus analysis (PRD Section 9)
│   └── ingest.py                    # Full ingestion entry point
├── tests/
│   ├── fixtures/
│   │   └── golden_dataset.json
│   ├── test_query.py
│   ├── test_clarification.py
│   └── test_scope_guard.py
├── Dockerfile
├── pyproject.toml
└── docs/
    ├── prd-v4.md
    └── research/
        └── ferpa-FINAL.md
```

## Key Commands (when code exists)

```bash
# Run API locally
uvicorn apps.api.src.api.main:app --reload

# Run tests
pytest apps/api/tests/ -v

# Lint
ruff check apps/api/src/

# Corpus scan (pre-ingestion)
python apps/api/scripts/corpus_scan.py

# Full ingestion (runs inside VPC via SSM, not locally)
python apps/api/scripts/ingest.py
```

## Architecture Notes

- **Single endpoint:** `POST /api/v1/query` (see `@.claude/rules/api-design.md`)
- **Hybrid search:** Vector (Qdrant, `text-embedding-3-large`) + BM25 (LlamaIndex `BM25Retriever` at app layer)
- **Re-ranker:** `cross-encoder/ms-marco-MiniLM-L-6-v2`, loaded in-process at startup
- **Conditional clarification:** One question max per session, Redis-backed state
- **Three response statuses:** `success`, `needs_clarification`, `out_of_scope`

## Evaluation Thresholds (PRD Section 2.3)

| Metric | Threshold |
|--------|-----------|
| Faithfulness | >= 0.80 |
| Answer Relevancy | >= 0.75 |
| Context Precision | >= 0.70 |
| Context Recall | >= 0.70 |

Evaluation uses RAGAS in reference-free mode during build (Phase 0-B).
Full evaluation with expert-authored answers in Phase 3.

## Key References

- PRD v4: `docs/prd-v4.md` (relative to this directory)
- FERPA: `docs/research/ferpa-FINAL.md`
- Golden dataset: `tests/fixtures/golden_dataset.json`
