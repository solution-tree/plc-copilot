# CLAUDE.md: PLC Coach Service

## 1. Project Overview & Core Mission

This project is to build the Minimum Viable Product (MVP) for the **PLC Coach Service**, a Retrieval-Augmented Generation (RAG) API. The service provides educators with expert answers to questions about Professional Learning Communities (PLCs) by querying a curated corpus of approximately 25 proprietary books.

The primary goal is to validate that a high-quality, book-only RAG service can provide more useful and accurate answers than a general-purpose chatbot. The long-term vision is a full-featured, FERPA-compliant coaching platform, so all architectural decisions in this MVP must be made with that future state in mind.

### Key Context Documents

- **The full specification is in the PRD:** `@docs/prd-v2.md`
- **Compliance is non-negotiable:** `@docs/research/ferpa-FINAL.md`
- **The DevOps and Architecture plan:** `@docs/research/plccs-mvp-devops.md`
- **The RAG strategy is defined here:** `@docs/research/rag-strategy-review-v2.md`

## 2. Technology Stack

- **Language:** Python 3.11+
- **API Framework:** FastAPI with Pydantic for data validation.
- **Vector Database:** Qdrant, self-hosted on an EC2 instance.
- **RAG Orchestration:** LlamaIndex.
- **PDF Parsing:** `llmsherpa`, self-hosted as a service on Fargate.
- **LLM & Embeddings:** OpenAI API (GPT-4o for generation, `text-embedding-3-large` for embeddings).
- **Cloud Provider:** AWS.
- **Infrastructure as Code:** Terraform.
- **CI/CD:** GitHub Actions.
- **Compute:** AWS Fargate for stateless services (API, parser); EC2 for stateful Qdrant.
- **Databases:** Amazon RDS for PostgreSQL (session/audit data) and Amazon ElastiCache for Redis (session cache).

## 3. Repository Structure

```
/
├── .claude/              # Claude-specific rules and configurations
│   └── rules/
│       ├── api-design.md
│       ├── ingestion.md
│       └── security.md
├── .github/              # GitHub Actions CI/CD workflows
│   └── workflows/
├── docs/                 # All project documentation (PRD, research)
├── src/
│   ├── api/              # FastAPI routers and endpoints
│   ├── core/             # Core RAG logic, query engine
│   ├── ingestion/        # PDF ingestion pipeline code
│   ├── schemas/          # Pydantic data models
│   ├── config.py         # Configuration loading
│   └── main.py           # FastAPI application entrypoint
├── terraform/            # All Terraform IaC modules
├── tests/                # Pytest unit and integration tests
└── scripts/              # Standalone operational scripts
```

## 4. Key Commands

- **Run local server:** `uvicorn src.main:app --reload --host 0.0.0.0 --port 8000`
- **Run tests:** `pytest`
- **Run linter:** `ruff check .`
- **Apply Terraform changes:** `terraform apply` (from within the `terraform/` directory)
- **Trigger ingestion for a book:** `python scripts/run_ingestion.py --book-sku <SKU>`

## 5. Hard Constraints & Non-Negotiable Rules

- **Compliance First:** All development must adhere to the security and compliance rules defined in `@.claude/rules/security.md`.
- **Stick to the Stack:** Do not introduce new technologies or services not listed in the technology stack above.
- **Zero-Retention is Mandatory:** The OpenAI API client MUST be configured for zero data retention in all environments.
- **No Secrets in Code:** All secrets, API keys, and credentials must be loaded from AWS Secrets Manager. Never hardcode them.
- **Follow the API Contract:** All API development must adhere to the schemas and contracts defined in `@.claude/rules/api-design.md`.
- **Infrastructure is Code:** All AWS infrastructure must be managed via the Terraform files in the `terraform/` directory. No manual changes in the AWS console.
