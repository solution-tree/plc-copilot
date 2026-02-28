variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the Qdrant EC2 instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Qdrant"
  type        = string
  default     = "t3.medium"
}

variable "ebs_volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 50
}

variable "ssh_key_name" {
  description = "Name of the EC2 key pair for emergency SSH access"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 data bucket (for snapshots)"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 data bucket (for snapshots)"
  type        = string
}

variable "qdrant_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Qdrant API key"
  type        = string
}
