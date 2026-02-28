environment  = "staging"
vpc_cidr     = "10.0.0.0/16"
ssh_key_name = "plc-copilot-staging"

# Instance sizing (MVP defaults)
rds_instance_class     = "db.t3.micro"
rds_allocated_storage  = 20
elasticache_node_type  = "cache.t3.micro"
qdrant_instance_type   = "t3.medium"
qdrant_ebs_volume_size = 50
fargate_cpu            = 1024
fargate_memory         = 2048

# Staging: no deletion protection
rds_deletion_protection = false
