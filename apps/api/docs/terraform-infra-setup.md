# Terraform Infrastructure Plan — PLC Co-Pilot

## Context

The PLC Co-Pilot project currently has comprehensive documentation (PRD, FERPA compliance, security rules) but zero implementation code. This task creates the foundational AWS infrastructure using Terraform, which is a prerequisite for all subsequent development (API, ingestion pipeline, CI/CD). The infrastructure must be FERPA-compliant from day one, following the Tenant Enclave model where Zone A (Content) is active at MVP and Zones B/C are reserved in the network design.

## User Decisions

- **Region:** `us-east-1`
- **HTTPS:** CloudFront with auto-generated `*.cloudfront.net` URL (no custom domain needed yet; FERPA-compliant TLS from day one)
- **TF State:** S3 backend from the start (manual bootstrap of state bucket + DynamoDB lock table required before `terraform init`)
- **Parser/Reranker:** Always-on Fargate services

## File Structure

All files in `apps/api/terraform/`:

```
apps/api/terraform/
├── backend.tf              # S3 backend + DynamoDB state lock
├── providers.tf            # AWS provider ~> 5.0, required versions, default tags
├── variables.tf            # All input variables
├── locals.tf               # Naming prefix, common tags
├── data.tf                 # AZ lookup, AMI for Qdrant
├── vpc.tf                  # VPC, 6 subnets (public/private-app/private-data), IGW, NAT, route tables
├── vpc-endpoints.tf        # S3 gateway endpoint, Secrets Manager interface endpoint
├── vpc-flow-logs.tf        # VPC flow logs → CloudWatch
├── security-groups.tf      # 9 security groups (ALB, API, Parser, Reranker, RDS, Redis, Qdrant + Zone B placeholder, Zone C placeholder)
├── kms.tf                  # Customer-managed KMS key for all encryption
├── iam.tf                  # 8 IAM roles (ECS execution, API task, ingestion task, parser task, reranker task, Qdrant EC2 + Zone B placeholder, Zone C placeholder)
├── s3.tf                   # 3 buckets (books, logs, qdrant-backups) — encrypted, versioned, no public access
├── ecr.tf                  # 4 ECR repos (api, parser, reranker, ingestion)
├── secrets.tf              # Secrets Manager shells (OpenAI key, RDS creds, Redis auth, app API key) — no values in code
├── ecs.tf                  # ECS cluster
├── ecs-api.tf              # API Fargate service + task def + ALB target group registration
├── ecs-parser.tf           # Parser Fargate service + task def + Cloud Map service discovery
├── ecs-reranker.tf         # Reranker Fargate service + task def + Cloud Map service discovery
├── ecs-ingestion.tf        # Ingestion worker task definition only (on-demand, not always-on)
├── alb.tf                  # ALB (HTTP listener only, internal target for CloudFront), target group
├── cloudfront.tf           # CloudFront distribution (HTTPS termination, *.cloudfront.net URL, origin = ALB)
├── waf.tf                  # WAFv2 web ACL (managed rules + rate limiting) attached to CloudFront
├── ec2-qdrant.tf           # Qdrant EC2 (t4g.medium ARM, encrypted EBS gp3, user data script, SSM access)
├── rds.tf                  # RDS PostgreSQL 15 (db.t3.micro, single-AZ, encrypted, automated backups)
├── elasticache.tf          # ElastiCache Redis 7 (cache.t3.micro, encrypted at rest + in transit)
├── service-discovery.tf    # Cloud Map private DNS namespace for internal service-to-service calls
├── cloudwatch.tf           # Log groups, metric alarms, SNS topic for alerts
├── xray.tf                 # X-Ray tracing: IAM permissions for X-Ray daemon on each Fargate task role
├── outputs.tf              # Key outputs (CloudFront URL, ALB DNS, ECR URIs, RDS endpoint, Redis endpoint, Qdrant IP)
├── terraform.tfvars.example # Canonical reference showing every variable and its purpose (no secrets)
└── envs/
    ├── dev.tfvars          # Dev environment overrides (smallest instance sizes, single-AZ)
    ├── staging.tfvars      # Staging environment overrides (mirrors prod sizing)
    └── prod.tfvars         # Prod environment overrides (multi-AZ, larger instances, longer retention)
```

Apply with: `terraform apply -var-file="envs/staging.tfvars"`

Also add Terraform entries to `.gitignore`.

## Key Design Decisions

1. **Flat file structure, no modules** — MVP simplicity; one file per resource domain, easy to refactor into modules later
2. **Tenant Enclave zone boundaries** — Zone A (Content) is active for MVP; Zone B (Meetings) and Zone C (Identity) get placeholder security groups and IAM roles with no rules/policies attached, plus CIDR reservations (`10.0.48.0/20` and `10.0.64.0/20`) as comments in `vpc.tf` — satisfies AC-1 and lets future work slot in without restructuring
3. **Single NAT Gateway** — saves ~$32/month; `single_nat_gateway` variable to toggle multi-AZ later
4. **Single KMS key** — one customer-managed key for all encryption (S3, RDS, EBS, ElastiCache, Secrets Manager, CloudWatch Logs); can split per-zone post-MVP
5. **Secrets Manager shells only** — Terraform creates secret resources but never stores values; `ignore_changes` on secret versions
6. **Data subnets have no NAT route** — RDS, ElastiCache, Qdrant cannot reach the internet; S3 access via free gateway endpoint
7. **Cloud Map for internal services** — parser (`parser.plc-copilot.local`) and reranker (`reranker.plc-copilot.local`) discovered via DNS, avoiding extra ALBs
8. **No SSH on Qdrant EC2** — access via SSM Session Manager only
9. **CloudFront for HTTPS** — auto-generated `*.cloudfront.net` domain provides free TLS termination; ALB stays HTTP-only (internal); WAF attaches to CloudFront instead of ALB; custom domain can be added later via ACM cert + CloudFront alias
10. **S3 backend for Terraform state** — remote state from day one; requires manual bootstrap of S3 bucket + DynamoDB lock table before first `terraform init`

## Security Group Matrix

| SG | Inbound From | Ports | Notes |
|---|---|---|---|
| `alb-sg` | CloudFront prefix list | 80 | ALB is HTTP-only; CloudFront handles HTTPS |
| `api-sg` | `alb-sg` | 8000 | API containers |
| `parser-sg` | `api-sg` | 5000 | Internal only |
| `reranker-sg` | `api-sg` | 8080 | Internal only |
| `rds-sg` | `api-sg`, `ingestion-sg` | 5432 | PostgreSQL |
| `redis-sg` | `api-sg` | 6379 | Redis |
| `qdrant-sg` | `api-sg`, `ingestion-sg` | 6333, 6334 | Qdrant HTTP + gRPC |
| `zone-b-sg` | _(none)_ | — | Zone B placeholder; no rules until Meetings zone is built |
| `zone-c-sg` | _(none)_ | — | Zone C placeholder; no rules until Identity zone is built |

## Implementation Order

1. **Foundation:** `backend.tf`, `providers.tf`, `variables.tf`, `locals.tf`, `data.tf`
2. **Networking:** `vpc.tf`, `vpc-endpoints.tf`, `vpc-flow-logs.tf`
3. **Security:** `kms.tf`, `security-groups.tf`, `iam.tf`
4. **Storage:** `s3.tf`, `ecr.tf`, `secrets.tf`
5. **Data tier:** `rds.tf`, `elasticache.tf`, `ec2-qdrant.tf`
6. **Compute:** `service-discovery.tf`, `ecs.tf`, `alb.tf`, `cloudfront.tf`, `waf.tf`, `ecs-api.tf`, `ecs-parser.tf`, `ecs-reranker.tf`, `ecs-ingestion.tf`
7. **Monitoring:** `cloudwatch.tf`, `xray.tf`, `outputs.tf`
8. **Docs:** `terraform.tfvars.example`, `envs/dev.tfvars`, `envs/staging.tfvars`, `envs/prod.tfvars`, `.gitignore` updates

## Variables (key ones, all have sensible MVP defaults except `environment` and `alert_email`)

- `project` = `"plc-copilot"`, `environment` (required), `aws_region` = `"us-east-1"`
- `vpc_cidr` = `"10.0.0.0/16"`, `single_nat_gateway` = `true`
- `api_cpu` = 512, `api_memory` = 2048, `api_desired_count` = 1
- `parser_cpu` = 1024, `parser_memory` = 4096
- `reranker_cpu` = 512, `reranker_memory` = 2048
- `ingestion_cpu` = 1024, `ingestion_memory` = 4096
- `qdrant_instance_type` = `"t4g.medium"`, `qdrant_ebs_size_gb` = 50
- `rds_instance_class` = `"db.t3.micro"`, `rds_multi_az` = false, `rds_backup_retention` = 7
- `redis_node_type` = `"cache.t3.micro"`
- `waf_rate_limit` = 1000, `log_retention_days` = 90

## Estimated MVP Cost: ~$255-275/month

## Bootstrap (manual, one-time, before `terraform init`)

1. Create S3 bucket: `plc-copilot-terraform-state` (versioning enabled, encryption enabled, block public access)
2. Create DynamoDB table: `plc-copilot-terraform-locks` (partition key: `LockID`, type: String)

## Verification

1. `terraform init` — should succeed with S3 backend
2. `terraform validate` — all files syntactically valid
3. `terraform plan` — shows ~65-85 resources to create, zero errors
4. Review security groups, IAM policies, and encryption settings in the plan output
5. Confirm no secrets appear in any `.tf` file or state output
6. Confirm CloudFront distribution output shows `*.cloudfront.net` HTTPS URL

## Post-Implementation: Reset Context

Per your request, after plan approval I will ask you to reset context before implementing — the plan file persists across sessions so I can pick it up fresh.

---

## Progress Log

### 2026-02-23

**Bootstrap — complete**
- S3 bucket `plc-copilot-terraform-state` created manually (versioning + encryption + block public access).
- DynamoDB table `plc-copilot-terraform-locks` created manually (partition key: `LockID`, type: String).

**Step 1: Foundation — complete**
- `backend.tf` — S3 remote state at `api/terraform.tfstate`, DynamoDB lock table wired in.
- `providers.tf` — AWS provider `~> 5.0`, default tags (`Project`, `Environment`, `ManagedBy`) on all resources.
- `variables.tf` — All input variables with MVP defaults; only `environment` and `alert_email` are required at apply time.
- `locals.tf` — `local.prefix` (e.g. `plc-copilot-staging`) and `local.common_tags`.
- `data.tf` — AZ lookup, latest AL2023 ARM64 AMI (for Qdrant t4g.medium), CloudFront managed prefix list, current account ID and region.

**Up next**
- Run `terraform init` from `apps/api/terraform/` to verify S3 backend connects.
- Step 2: Networking — `vpc.tf`, `vpc-endpoints.tf`, `vpc-flow-logs.tf`.
