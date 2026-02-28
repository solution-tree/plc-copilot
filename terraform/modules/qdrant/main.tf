locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ------------------------------------------------------------------------------
# Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "qdrant" {
  name        = "${local.name_prefix}-qdrant"
  description = "Security group for Qdrant EC2 instance"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${local.name_prefix}-qdrant"
  }
}

# ------------------------------------------------------------------------------
# IAM Role + Instance Profile
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "qdrant" {
  name               = "${local.name_prefix}-qdrant"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-qdrant"
  }
}

# SSM managed policy (for ingestion via SSM Run Command)
resource "aws_iam_role_policy_attachment" "qdrant_ssm" {
  role       = aws_iam_role.qdrant.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch agent managed policy
resource "aws_iam_role_policy_attachment" "qdrant_cloudwatch" {
  role       = aws_iam_role.qdrant.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# S3 snapshot access + Secrets Manager read
data "aws_iam_policy_document" "qdrant_custom" {
  statement {
    sid = "S3SnapshotAccess"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }

  statement {
    sid = "SecretsManagerRead"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.qdrant_secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "qdrant_custom" {
  name   = "${local.name_prefix}-qdrant-custom"
  role   = aws_iam_role.qdrant.id
  policy = data.aws_iam_policy_document.qdrant_custom.json
}

resource "aws_iam_instance_profile" "qdrant" {
  name = "${local.name_prefix}-qdrant"
  role = aws_iam_role.qdrant.name
}

# ------------------------------------------------------------------------------
# AMI (Amazon Linux 2023)
# ------------------------------------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "qdrant" {
  name              = "/plc-copilot/${var.environment}/qdrant"
  retention_in_days = 30

  tags = {
    Name = "${local.name_prefix}-qdrant-logs"
  }
}

# ------------------------------------------------------------------------------
# EC2 Instance
# ------------------------------------------------------------------------------

resource "aws_instance" "qdrant" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.instance_type
  key_name             = var.ssh_key_name
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.qdrant.name

  vpc_security_group_ids = [aws_security_group.qdrant.id]

  root_block_device {
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
    iops        = 3000
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    region         = data.aws_region.current.name
    environment    = var.environment
    secret_id      = "plc-copilot/${var.environment}/qdrant-api-key"
    s3_bucket      = var.s3_bucket_name
    log_group_name = aws_cloudwatch_log_group.qdrant.name
  })

  tags = {
    Name = "${local.name_prefix}-qdrant"
  }
}

data "aws_region" "current" {}
