# ==============================================================================
# ALB
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

# ==============================================================================
# ECR
# ==============================================================================

output "ecr_api_repository_url" {
  description = "URL of the API ECR repository"
  value       = module.ecs.ecr_repository_url
}

output "ecr_ingestion_repository_url" {
  description = "URL of the ingestion ECR repository"
  value       = module.ecs.ecr_ingestion_repository_url
}

# ==============================================================================
# ECS
# ==============================================================================

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

# ==============================================================================
# RDS
# ==============================================================================

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.port
}

# ==============================================================================
# ElastiCache
# ==============================================================================

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = module.elasticache.port
}

# ==============================================================================
# Qdrant
# ==============================================================================

output "qdrant_private_ip" {
  description = "Private IP of the Qdrant EC2 instance"
  value       = module.qdrant.private_ip
}

output "qdrant_instance_id" {
  description = "Instance ID of the Qdrant EC2 instance"
  value       = module.qdrant.instance_id
}

# ==============================================================================
# S3
# ==============================================================================

output "s3_bucket_name" {
  description = "Name of the data S3 bucket"
  value       = module.s3.bucket_name
}

# ==============================================================================
# CloudWatch
# ==============================================================================

output "app_log_group_name" {
  description = "Name of the application CloudWatch log group"
  value       = module.ecs.app_log_group_name
}

output "audit_log_group_name" {
  description = "Name of the audit CloudWatch log group"
  value       = module.ecs.audit_log_group_name
}
