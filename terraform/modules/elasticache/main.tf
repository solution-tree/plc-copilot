locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ------------------------------------------------------------------------------
# Security Group (ingress rules added in root main.tf to avoid circular deps)
# ------------------------------------------------------------------------------

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}

# ------------------------------------------------------------------------------
# ElastiCache Replication Group (single-node)
# ------------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis for ${local.name_prefix} sessions and cache"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.node_type

  num_cache_clusters = 1

  subnet_group_name  = var.subnet_group_name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  port = 6379

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}
