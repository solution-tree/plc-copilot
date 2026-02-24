# ── Project ───────────────────────────────────────────────────────────────────

variable "project" {
  description = "Project name, used in resource naming."
  type        = string
  default     = "plc-copilot"
}

variable "environment" {
  description = "Deployment environment (e.g. staging, production)."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be 'staging' or 'production'."
  }
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway to reduce cost. Set false for multi-AZ redundancy."
  type        = bool
  default     = true
}

# ── ECS — API ─────────────────────────────────────────────────────────────────

variable "api_cpu" {
  description = "Fargate CPU units for the API task."
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "Fargate memory (MiB) for the API task."
  type        = number
  default     = 2048
}

variable "api_desired_count" {
  description = "Desired number of API Fargate tasks."
  type        = number
  default     = 1
}

# ── ECS — Parser ──────────────────────────────────────────────────────────────

variable "parser_cpu" {
  description = "Fargate CPU units for the parser task."
  type        = number
  default     = 1024
}

variable "parser_memory" {
  description = "Fargate memory (MiB) for the parser task."
  type        = number
  default     = 4096
}

variable "parser_desired_count" {
  description = "Desired number of parser Fargate tasks."
  type        = number
  default     = 1
}

# ── ECS — Reranker ────────────────────────────────────────────────────────────

variable "reranker_cpu" {
  description = "Fargate CPU units for the reranker task."
  type        = number
  default     = 512
}

variable "reranker_memory" {
  description = "Fargate memory (MiB) for the reranker task."
  type        = number
  default     = 2048
}

variable "reranker_desired_count" {
  description = "Desired number of reranker Fargate tasks."
  type        = number
  default     = 1
}

# ── ECS — Ingestion ───────────────────────────────────────────────────────────

variable "ingestion_cpu" {
  description = "Fargate CPU units for the ingestion task."
  type        = number
  default     = 1024
}

variable "ingestion_memory" {
  description = "Fargate memory (MiB) for the ingestion task."
  type        = number
  default     = 4096
}

# ── Qdrant EC2 ────────────────────────────────────────────────────────────────

variable "qdrant_instance_type" {
  description = "EC2 instance type for the Qdrant node."
  type        = string
  default     = "t4g.medium"
}

variable "qdrant_ebs_size_gb" {
  description = "Size (GiB) of the Qdrant data EBS volume."
  type        = number
  default     = 50
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS. Disabled at MVP to reduce cost."
  type        = bool
  default     = false
}

variable "rds_backup_retention" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7
}

# ── ElastiCache ───────────────────────────────────────────────────────────────

variable "redis_node_type" {
  description = "ElastiCache node type for Redis."
  type        = string
  default     = "cache.t3.micro"
}

# ── WAF / Observability ───────────────────────────────────────────────────────

variable "waf_rate_limit" {
  description = "Max requests per 5-minute window per IP before WAF rate-limit rule triggers."
  type        = number
  default     = 1000
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days."
  type        = number
  default     = 90
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm SNS notifications."
  type        = string
}
