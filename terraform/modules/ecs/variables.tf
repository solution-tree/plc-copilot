variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ECS resources will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Fargate tasks"
  type        = list(string)
}

variable "container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8000
}

variable "cpu" {
  description = "Fargate task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 2048
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 data bucket (for BM25 index access)"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  type        = string
}

variable "qdrant_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Qdrant API key"
  type        = string
}

variable "openai_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the OpenAI API key"
  type        = string
}

variable "api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the API service key"
  type        = string
}
