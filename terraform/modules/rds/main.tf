locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ------------------------------------------------------------------------------
# Security Group (ingress rules added in root main.tf to avoid circular deps)
# ------------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-rds"
  }
}

# ------------------------------------------------------------------------------
# Random Password
# ------------------------------------------------------------------------------

resource "random_password" "rds" {
  length  = 32
  special = false
}

# ------------------------------------------------------------------------------
# Secrets Manager (RDS credentials)
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "${var.project}/${var.environment}/rds-credentials"

  tags = {
    Name = "${local.name_prefix}-rds-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = "plc_copilot_admin"
    password = random_password.rds.result
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}

# ------------------------------------------------------------------------------
# RDS Instance
# ------------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = "15"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = "plc_copilot_admin"
  password = random_password.rds.result

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false

  backup_retention_period   = 7
  skip_final_snapshot       = var.environment == "staging"
  final_snapshot_identifier = var.environment == "production" ? "${local.name_prefix}-final-snapshot" : null
  deletion_protection       = var.deletion_protection

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
