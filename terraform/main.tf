# ==============================================================================
# Secrets Manager — empty secret containers (values populated via CLI)
# ==============================================================================

resource "aws_secretsmanager_secret" "qdrant_api_key" {
  name = "${var.project}/${var.environment}/qdrant-api-key"

  tags = {
    Name = "${var.project}-${var.environment}-qdrant-api-key"
  }
}

resource "aws_secretsmanager_secret" "openai_api_key" {
  name = "${var.project}/${var.environment}/openai-api-key"

  tags = {
    Name = "${var.project}-${var.environment}-openai-api-key"
  }
}

resource "aws_secretsmanager_secret" "api_service_key" {
  name = "${var.project}/${var.environment}/api-service-key"

  tags = {
    Name = "${var.project}-${var.environment}-api-service-key"
  }
}

# ==============================================================================
# Module: VPC
# ==============================================================================

module "vpc" {
  source = "./modules/vpc"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# ==============================================================================
# Module: S3
# ==============================================================================

module "s3" {
  source = "./modules/s3"

  project     = var.project
  environment = var.environment
}

# ==============================================================================
# Module: ECS (creates Fargate SG needed by other modules' SG rules)
# ==============================================================================

module "ecs" {
  source = "./modules/ecs"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  cpu                = var.fargate_cpu
  memory             = var.fargate_memory
  s3_bucket_arn      = module.s3.bucket_arn
  rds_secret_arn     = module.rds.secret_arn
  qdrant_secret_arn  = aws_secretsmanager_secret.qdrant_api_key.arn
  openai_secret_arn  = aws_secretsmanager_secret.openai_api_key.arn
  api_key_secret_arn = aws_secretsmanager_secret.api_service_key.arn
}

# ==============================================================================
# Module: Qdrant
# ==============================================================================

module "qdrant" {
  source = "./modules/qdrant"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_subnet_ids[0]
  instance_type     = var.qdrant_instance_type
  ebs_volume_size   = var.qdrant_ebs_volume_size
  ssh_key_name      = var.ssh_key_name
  s3_bucket_arn     = module.s3.bucket_arn
  s3_bucket_name    = module.s3.bucket_name
  qdrant_secret_arn = aws_secretsmanager_secret.qdrant_api_key.arn
}

# ==============================================================================
# Module: RDS
# ==============================================================================

module "rds" {
  source = "./modules/rds"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  deletion_protection  = var.rds_deletion_protection
}

# ==============================================================================
# Module: ElastiCache
# ==============================================================================

module "elasticache" {
  source = "./modules/elasticache"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_group_name = module.vpc.elasticache_subnet_group_name
  node_type         = var.elasticache_node_type
}

# ==============================================================================
# Cross-module Security Group Rules
# Defined here to avoid circular dependencies between modules.
# ==============================================================================

# --- Fargate -> Qdrant (REST API) ---
resource "aws_security_group_rule" "qdrant_from_fargate_rest" {
  type                     = "ingress"
  from_port                = 6333
  to_port                  = 6333
  protocol                 = "tcp"
  source_security_group_id = module.ecs.fargate_sg_id
  security_group_id        = module.qdrant.qdrant_sg_id
  description              = "Qdrant REST from Fargate"
}

# --- Fargate -> Qdrant (gRPC) ---
resource "aws_security_group_rule" "qdrant_from_fargate_grpc" {
  type                     = "ingress"
  from_port                = 6334
  to_port                  = 6334
  protocol                 = "tcp"
  source_security_group_id = module.ecs.fargate_sg_id
  security_group_id        = module.qdrant.qdrant_sg_id
  description              = "Qdrant gRPC from Fargate"
}

# --- Fargate -> RDS ---
resource "aws_security_group_rule" "rds_from_fargate" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.ecs.fargate_sg_id
  security_group_id        = module.rds.security_group_id
  description              = "PostgreSQL from Fargate"
}

# --- Qdrant -> RDS (ingestion) ---
resource "aws_security_group_rule" "rds_from_qdrant" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.qdrant.qdrant_sg_id
  security_group_id        = module.rds.security_group_id
  description              = "PostgreSQL from Qdrant EC2 (ingestion)"
}

# --- Fargate -> Redis ---
resource "aws_security_group_rule" "redis_from_fargate" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.ecs.fargate_sg_id
  security_group_id        = module.elasticache.security_group_id
  description              = "Redis from Fargate"
}

# --- Qdrant -> Redis (ingestion) ---
resource "aws_security_group_rule" "redis_from_qdrant" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.qdrant.qdrant_sg_id
  security_group_id        = module.elasticache.security_group_id
  description              = "Redis from Qdrant EC2 (ingestion)"
}
