---
stepsCompleted: [1, 2]
inputDocuments:
  - apps/api/docs/prd-v4.md
  - apps/api/docs/prd-v4-validation-report.md
  - apps/api/docs/research/ferpa-FINAL.md
workflowType: 'architecture'
project_name: 'plc-copilot'
user_name: 'Nani'
date: '2026-02-26'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Guiding Architectural Principle

**Scale-ready, not scale-built.** This MVP is the first phase of an enterprise-level application targeting millions of users. Every architectural decision must pass a dual test: (1) Does it avoid over-engineering the MVP? (2) Would scaling require only configuration changes and infrastructure provisioning — not a rewrite? When in doubt, choose patterns and abstractions that scale horizontally, but deploy the minimal instance for MVP.

### Requirements Overview

**Functional Requirements:**
13 FRs across 3 subsystems:
- **Ingestion Pipeline (FR-001–004):** Batch processing of 25 PLC books from S3 into Qdrant + PostgreSQL. Three-stage parsing: PyMuPDF (classification) → llmsherpa (structure) → GPT-4o Vision (landscape pages). Runs inside VPC via SSM, not part of the live API.
- **Query Engine (FR-005–010):** Single API endpoint with 3 response modes: direct answer, conditional clarification (1-question hard limit via Redis session), and out-of-scope refusal. Includes ambiguity detection and dynamic metadata filtering.
- **Hybrid Search & Re-Ranking (FR-011–013):** Dual retrieval (BM25 keyword + vector semantic) with cross-encoder re-ranking before LLM generation. Quality-critical path with ablation test requirements.

**Non-Functional Requirements:**
7 NFRs scoped for internal testing:
- Response time: 30s P95 (1-3 concurrent users)
- Availability: 95% uptime during business hours
- Concurrency: 5 simultaneous queries
- Encryption: TLS 1.2+ in transit, KMS at rest (no exceptions)
- Audit logs: 90-day retention, no PII even in debug mode
- Backup/Recovery: RTO 4h, RPO 24h
- Security scanning: Critical/high CVEs blocked before deployment

**Scale & Complexity:**

- Primary domain: API backend (Python/FastAPI RAG service on AWS)
- Complexity level: Medium
- Estimated architectural components: 8 (API service, Qdrant, RDS, ElastiCache, S3, ALB, NAT Gateway, ingestion pipeline)
- Long-term target: Enterprise-level, millions of users

### Technical Constraints & Dependencies

- **Technology stack pre-decided:** Python 3.11+/FastAPI, LlamaIndex, Qdrant (self-hosted EC2), PostgreSQL (RDS), Redis (ElastiCache), OpenAI GPT-4o + text-embedding-3-large, cross-encoder/ms-marco-MiniLM-L-6-v2 (in-process)
- **Single AZ deployment** for MVP simplicity
- **HIPAA-eligible compute required** (Fargate, not App Runner)
- **External API dependency:** OpenAI (must have executed DPA with zero-retention)
- **VPC-contained ingestion:** Proprietary content never leaves VPC; ingestion triggered via GitHub Actions but executed via SSM Run Command on EC2
- **Ingestion is a separate workload** from the live API — runs as a Docker container only during batch processing

### Cross-Cutting Concerns Identified

- **FERPA compliance:** Shapes every data handling decision — self-hosted Qdrant, VPC-only ingestion, DPA requirements, no-PII audit logs, three-zone enclave model
- **Encryption:** Universal requirement — KMS at rest, TLS 1.2+ in transit, all data stores, all network communication
- **Audit logging:** Structured JSON logs for all key events, must never capture PII, 90-day retention
- **Secrets management:** All credentials and API keys in AWS Secrets Manager, IAM least-privilege for all service-to-service access
- **VPC networking:** Private subnets for all data stores and compute, public subnet for ALB only, NAT gateway for controlled egress
- **Observability:** CloudWatch log groups for Fargate service (basic for MVP); dashboards and distributed tracing deferred
