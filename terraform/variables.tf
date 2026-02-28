variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "plc-copilot"
}

variable "environment" {
  description = "Deployment environment (staging, production)"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be 'staging' or 'production'."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones (2 required for ALB and subnet groups)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ------------------------------------------------------------------------------
# Instance sizing
# ------------------------------------------------------------------------------

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "qdrant_instance_type" {
  description = "EC2 instance type for Qdrant"
  type        = string
  default     = "t3.medium"
}

variable "qdrant_ebs_volume_size" {
  description = "EBS volume size in GB for Qdrant"
  type        = number
  default     = 50
}

variable "fargate_cpu" {
  description = "Fargate task CPU units (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "fargate_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 2048
}

# ------------------------------------------------------------------------------
# SSH Key
# ------------------------------------------------------------------------------

variable "ssh_key_name" {
  description = "Name of the EC2 key pair for Qdrant emergency SSH access"
  type        = string
}

# ------------------------------------------------------------------------------
# Deletion protection
# ------------------------------------------------------------------------------

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = false
}
