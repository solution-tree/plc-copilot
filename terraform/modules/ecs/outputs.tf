output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "URL of the API ECR repository"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_ingestion_repository_url" {
  description = "URL of the ingestion ECR repository"
  value       = aws_ecr_repository.ingestion.repository_url
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.api.name
}

output "fargate_sg_id" {
  description = "Security group ID of Fargate tasks"
  value       = aws_security_group.fargate.id
}

output "app_log_group_name" {
  description = "Name of the application CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "audit_log_group_name" {
  description = "Name of the audit CloudWatch log group"
  value       = aws_cloudwatch_log_group.audit.name
}
