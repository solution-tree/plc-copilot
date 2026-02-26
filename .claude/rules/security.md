---
description: Security and FERPA compliance rules for all infrastructure, networking, and data-handling code
globs:
  - "**/*.tf"
  - "**/*.py"
  - "**/docker-compose*.yml"
  - "**/Dockerfile*"
---

# Security & FERPA Compliance Rules

## Source of Truth

- PRD v4 Section 7: `@apps/api/docs/prd-v4.md`
- FERPA report: `@apps/api/docs/research/ferpa-FINAL.md`

## Three-Zone Tenant Enclave Model

| Zone | Name | Contents | MVP Status |
|------|------|----------|------------|
| A | Content Zone | 25 PLC books — PDFs, parsed text, vector embeddings. Proprietary IP, NO PII. | **Built and populated at launch** |
| B | Meeting/Transcript Zone | De-identified PLC meeting transcripts (future) | Defined in Terraform as commented-out code only |
| C | Identity/Student Directory Zone | Real-name-to-token mapping (future) | Defined in Terraform as commented-out code only |

- Zone A is the only active zone for MVP.
- Zones B and C MUST exist as commented Terraform — never provision them until explicitly scoped.

## Zero-Retention OpenAI

- OpenAI API MUST be configured for zero data retention before any production use.
- A signed Data Processing Agreement (DPA) with OpenAI is mandatory.
- Never send PII to OpenAI in the MVP (book content only, no student data).

## No PII in Logs

- Structured JSON logs capture metadata only: `query_received`, `answer_generated`, timestamps, conversation_id.
- NEVER log raw query text, answer text, or any student-identifiable content — even in debug mode.
- Use `user_id` for tracing only; do not resolve to real identity.

## Secrets Management

- All secrets (API keys, DB credentials, OpenAI key) stored in **AWS Secrets Manager**.
- Fetched at runtime via IAM role — never baked into images, env files, or source code.
- `.env` files are gitignored and denied in `.claude/settings.json`.

## Networking — Private VPC

- Single availability zone for MVP (cost optimization).
- ALB in public subnets; Fargate, RDS, ElastiCache, EC2/Qdrant in **private subnets**.
- NAT Gateway for controlled egress (OpenAI API calls).
- No public IP on any compute resource except ALB.

## Encryption

- **At rest:** AWS KMS for RDS, S3, EBS (Qdrant EC2).
- **In transit:** TLS 1.2+ enforced on all connections (ALB, RDS, ElastiCache, OpenAI).

## Ingestion Runs Inside VPC

- GitHub Actions triggers the workflow, but **all content processing runs inside VPC** via AWS Systems Manager (SSM) Run Command on the Qdrant EC2 instance.
- Proprietary PDF content MUST NEVER pass through GitHub public runners.
- This pattern is the foundation for future FERPA data in Zones B/C.

## MVP Authentication

- Static API key via `X-API-Key` request header.
- Missing or invalid key returns `401 Unauthorized`.
- Full user authentication (OAuth/JWT) deferred to post-MVP.

## Infrastructure as Code

- **Terraform only** for all AWS resources — no ClickOps, no CloudFormation, no CDK.
- CI/CD via GitHub Actions: lint, test, Docker build, push to ECR, deploy to Fargate.
