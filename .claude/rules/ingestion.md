---
description: Ingestion pipeline rules for PDF parsing, chunking, and vector storage
globs:
  - "apps/api/src/ingestion/**"
  - "apps/api/scripts/**"
---

# Ingestion Pipeline Rules

## Source of Truth

PRD v4 Sections 3.1 and 9: `@apps/api/docs/prd-v4.md`

## Three-Stage Hybrid Parser

| Step | Tool | Role | Hosting |
|------|------|------|---------|
| 1 | **PyMuPDF** | Reads every page; classifies by orientation (portrait vs. landscape); detects text-layer presence. Lightweight sorter — no content sent externally. | In-process Python library |
| 2 | **llmsherpa (`nlm-ingestor`)** | Handles standard portrait pages. Parses hierarchical structure (headings, sections, paragraphs, lists, tables). | **Docker container, ingestion-only** |
| 3 | **GPT-4o Vision** | Reserved for landscape pages (reproducibles/worksheets). Renders page as image, generates structured Markdown. | OpenAI API (zero-retention) |

### Critical: llmsherpa Hosting

- llmsherpa / `nlm-ingestor` runs as a **separate Docker container during ingestion only**.
- It is **NOT on Fargate** and is **NOT part of the live API container**.
- It is spun up for ingestion runs and torn down after.

## Ingestion Execution Model

- **Trigger:** GitHub Actions workflow.
- **Processing:** Runs **inside VPC** via AWS Systems Manager (SSM) Run Command on the Qdrant EC2 instance.
- Proprietary PDF content MUST NEVER pass through GitHub public runners.
- This is a hard security requirement — see `.claude/rules/security.md`.

## Metadata Schema

Every chunk MUST carry the full metadata payload. Use a TypedDict (or Pydantic model) to enforce:

```python
class ChunkMetadata(TypedDict):
    book_title: str       # Full book title
    authors: list[str]    # List of author names
    sku: str              # Solution Tree SKU (e.g., BKF219)
    chapter: str | None   # Chapter name (nullable)
    section: str | None   # Section name (nullable)
    page_number: int      # Source page number
    chunk_type: str       # One of: title, body_text, list, table, reproducible
```

- `chunk_type` must be one of the five allowed values.
- Missing required metadata is a pipeline error — fail loudly, do not ingest partial records.

## Pre-Build Corpus Scan (PRD Section 9)

Before any application coding begins, run a lightweight scan of all 25 PDFs producing:

| Metric | Purpose |
|--------|---------|
| Total page count per book | Validates cost/time estimates |
| Landscape page count | Determines GPT-4o Vision call volume |
| Text-layer presence per page | Identifies scanned/image-only pages needing OCR |
| Estimated chunk count | Basis for Qdrant storage sizing and embedding cost |

- Scan script must run against all 25 PDFs in S3.
- Summary report must be generated and reviewed **before ingestion begins**.
- Books with unexpected characteristics must be flagged with handling decisions documented.

## Storage Targets

### Qdrant

- Collection: `plc_copilot_v1`
- Vector dimensions: 3,072 (from `text-embedding-3-large`)
- Payload fields for filtering: `book_sku`, `authors`, `book_title`, `chunk_type`, `page_number`

### PostgreSQL

**`books` table** — one row per book:
- `id`, `sku`, `title`, `authors` (string[]), `created_at`, `updated_at`

**`chunks` table** — one row per ingested chunk:
- `id`, `book_id` (FK), `qdrant_id`, `text_content` (raw text for citations/audit only — NOT full-text indexed), `page_number`, `chunk_type`, `chapter`, `section`, `created_at`

- `text_content` carries NO full-text search index. Keyword search (BM25) is handled entirely at the application layer via LlamaIndex `BM25Retriever`.

## Chunk Types

| Type | Description |
|------|-------------|
| `title` | Book/chapter/section titles |
| `body_text` | Standard paragraph content |
| `list` | Bulleted or numbered lists |
| `table` | Tabular data |
| `reproducible` | Landscape worksheets processed by GPT-4o Vision |
