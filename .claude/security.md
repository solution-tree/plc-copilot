# Security & Compliance Rules

These rules are non-negotiable and must be enforced in all code.

- **FERPA Compliance:** The service must be architected according to the Tenant Enclave model described in the PRD (`@docs/PLC_Coach_One_Shot_PRD.md`). Even though the MVP only implements Zone A (Content), the boundaries for future zones must be respected in the infrastructure design (e.g., IAM roles, security groups).

- **Zero-Retention for OpenAI:** The OpenAI API client must be configured for zero data retention. This is a hard requirement. When initializing the OpenAI client, ensure the appropriate headers or parameters are set to enforce this.

- **No PII in Logs:** Do not log any part of the user's query or the LLM's response. Audit logs should only contain metadata (timestamps, session IDs, source citations), not content.

- **Secrets Management:** All secrets (API keys, database passwords, etc.) must be loaded from AWS Secrets Manager. Do not store secrets in environment variables, configuration files, or the code itself.

- **Private Networking:** All services (API, Qdrant, RDS, ElastiCache) must reside in private VPC subnets. Only the Application Load Balancer should be in a public subnet.

- **Encryption:** All data must be encrypted at rest (using KMS for S3, RDS, and EBS volumes) and in transit (TLS 1.2+).
