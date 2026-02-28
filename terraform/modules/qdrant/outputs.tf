output "private_ip" {
  description = "Private IP address of the Qdrant EC2 instance"
  value       = aws_instance.qdrant.private_ip
}

output "instance_id" {
  description = "Instance ID of the Qdrant EC2 instance"
  value       = aws_instance.qdrant.id
}

output "qdrant_sg_id" {
  description = "Security group ID of the Qdrant EC2 instance"
  value       = aws_security_group.qdrant.id
}
