# Architecture Adversarial Review — Round 3

**Date:** 2026-02-27
**Reviewed Document:** `_bmad-output/planning-artifacts/architecture.md`
**Review Method:** Multi-agent adversarial review (3 independent agents + orchestrator)
**Agents Used:**
1. **Orchestrator** — Initial cynical review (13 findings)
2. **Findings Validator** — Cross-examined all 13 original findings for accuracy
3. **FERPA & Security Specialist** — Independent security/compliance review against architecture + FERPA research
4. **DevOps/Infrastructure Specialist** — Independent operational review

---

## Validation of Original 13 Findings

| # | Original Finding | Validator Verdict | Action |
|---|---|---|---|
| 1 | Redis health check vs. graceful degradation contradiction | **VALID** | Fix in architecture |
| 2 | Response cache key never defined | **OVERBLOWN** — low risk at MVP scale, but still a spec gap | Fix (define the key) |
| 3 | conversation_id and user_id unvalidated | **OVERBLOWN** — intentional debt, FERPA risk is data exposure not audit spoofing | No change needed |
| 4 | Pickle deserialization attack vector | **OVERBLOWN** — threat model requires S3 compromise first | Add security note + S3 IAM mitigation |
| 5 | No ingestion scheduling guardrail | **OVERBLOWN** — consequence is degraded perf for 1-3 testers, not data loss | No change needed |
| 6 | Evaluation pipeline pollutes audit logs | **VALID** | Fix in architecture |
| 7 | No CORS policy | **OVERBLOWN** — same-origin test client, no external frontends at MVP | No change needed |
| 8 | Terraform state security | **OVERBLOWN** — S3 default encryption + IAM is standard practice | No change needed |
| 9 | Re-ranker model update requires rebuild | **OVERBLOWN** — this is the intended workflow, not a flaw | No change needed |
| 10 | Single API key = zero attribution | **WRONG** — attribution exists via user_id, API key is authn not attribution | No change needed |
| 11 | Session TTL arbitrary and not configurable | **OVERBLOWN** — well-reasoned default, configurability is trivial | No change needed |
| 12 | exclude_none=True suppresses null values | **WRONG** — intentional design, no fields need semantic null | No change needed |
| 13 | Connection pool sizing unspecified | **VALID** | Fix in architecture |

---

## New Findings from Specialist Agents

### FERPA & Security Agent — 8 New Findings

| ID | Title | Risk | Summary |
|---|---|---|---|
| F3-01 | Redis encryption at rest not required in Terraform | **CRITICAL** | `at_rest_encryption_enabled` and `transit_encryption_enabled` not specified. Violates the doc's own "KMS at rest, all data stores" rule. App must use `rediss://` (TLS) not `redis://`. |
| F3-02 | Response cache leaks data across teams; cache key exposes PII | **HIGH** | Cache key undefined. If key contains raw query text, student names appear as Redis keys. No per-user/team cache isolation. |
| F3-03 | OpenAI zero-retention not verified; no key rotation; no prompt injection defense | **HIGH** | No startup verification of `store: false`. No rotation cadence. Prompt injection acknowledged as risk for post-MVP. |
| F3-04 | Audit logs lack source IP, retention too short, missing data-access events | **HIGH** | No `source_ip` in event fields. 90-day retention insufficient for state law investigations. No authorization failure events. |
| F3-05 | Qdrant has no authentication | **HIGH** | Any VPC process has unrestricted access. No API key configured. Security groups too broad. |
| F3-06 | No data deletion architecture | **HIGH** | FERPA requires deletion capabilities. No S3 lifecycle policies, no cascade deletion strategy, no deletion verification. Forward note needed for transcript pipeline. |
| F3-07 | Pickle deserialization RCE risk | **MEDIUM** | S3 IAM should restrict PutObject on BM25 prefix to ingestion role only. Checksum verification recommended. |
| F3-08 | Health check exposes infrastructure topology | **MEDIUM** | Unauthenticated `/health` returns dependency names. Should return only status code; details behind auth or logged internally. |

### DevOps/Infrastructure Agent — 7 New Findings

| ID | Title | Severity | Summary |
|---|---|---|---|
| OPS-01 | No ECS deployment strategy or rollback | **BLOCKING** | No rolling/blue-green decision. No circuit breaker. No rollback procedure. Bad deploy = total outage. |
| OPS-02 | No resource sizing for any compute | **BLOCKING** | Fargate CPU/memory, EC2 instance type, RDS class, ElastiCache node type all unspecified. Agents will guess. |
| OPS-03 | Qdrant recovery incomplete; backup monitoring absent | **IMPORTANT** | No step-by-step recovery. Cron on same EC2 = single point of failure. No alarm if snapshot fails. EBS config missing. |
| OPS-04 | CloudWatch log retention not configured | **IMPORTANT** | Default is "never expire." Audit logs mixed with app logs in one group. Should be separate groups with explicit retention. |
| OPS-05 | No docker-compose for local dev | **IMPORTANT** | Can't run API locally without staging infra. Need PostgreSQL + Redis + Qdrant containers. |
| OPS-06 | CI/CD has no integration test stage or staging gate | **IMPORTANT** | Pipeline says "pytest" with no distinction. No staging validation before production. Load test is manual with no enforcement. |
| OPS-07 | OpenAI cost controls and key rotation missing | **IMPORTANT** | No spending limits. No key rotation procedure. No extended outage handling (serve stale cache?). |

---

## Consolidated Action Items (18 total, priority order)

### Must Fix Before Implementation Begins

1. **[CRITICAL] Redis encryption at rest** — Add `at_rest_encryption_enabled = true` and `transit_encryption_enabled = true` as mandatory Terraform parameters. Specify `rediss://` connection protocol.
2. **[BLOCKING] ECS deployment strategy** — Specify deployment circuit breaker with auto-rollback, min/max healthy percent, rollback procedure.
3. **[BLOCKING] Resource sizing** — Add starting specs for Fargate, Qdrant EC2, RDS, ElastiCache with rationale.

### Must Fix Before First Story Implementation

4. **[HIGH] Qdrant authentication** — Enable API key auth, store in Secrets Manager, restrict security group inbound to Fargate + ingestion SGs only.
5. **[VALID] Redis health check contradiction** — Remove Redis from health check dependencies; degrade gracefully on cache miss, return 400 on expired session.
6. **[HIGH] Audit log improvements** — Add `source_ip` to required fields, separate log groups for audit vs app logs, extend retention analysis.
7. **[HIGH] OpenAI guardrails** — Add zero-retention verification, key rotation policy, spending limits to pre-launch checklist.
8. **[HIGH] Response cache key** — Define key as `cache:{sha256(query_text)}`, document scope rules for post-MVP team isolation.
9. **[HIGH] Data deletion forward note** — Acknowledge deletion obligations, note S3 lifecycle policies for transcripts, flag BM25 rebuild requirement.
10. **[IMPORTANT] Qdrant recovery procedure** — Add recovery steps, external snapshot monitoring alarm, EBS config.
11. **[IMPORTANT] Local dev docker-compose** — Add `docker-compose.dev.yml` to project structure.
12. **[IMPORTANT] CI/CD staging gate** — Specify which tests run in CI, add staging deploy + manual promotion.
13. **[VALID] Evaluation traffic tagging** — Add `source` field to query request schema and event catalog.
14. **[VALID] Connection pool sizing** — Specify pool sizes for SQLAlchemy, Redis, Qdrant client.

### Should Fix (Lower Priority)

15. **[MEDIUM] Health check response sanitization** — Public response returns status only; dependency details behind auth or logged.
16. **[MEDIUM] Pickle security note** — Add S3 IAM restriction (PutObject to ingestion role only), checksum verification.
17. **[IMPORTANT] CloudWatch log retention** — Set explicit retention in Terraform, separate audit from app logs.
18. **[VALID] Update frontmatter** — Add `round-3` to `adversarialReviewsApplied`.
