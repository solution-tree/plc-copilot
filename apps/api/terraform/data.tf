# ── Availability Zones ────────────────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

# ── Latest Amazon Linux 2023 ARM64 AMI (for Qdrant EC2 t4g.medium) ────────────

data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# ── CloudFront managed prefix list (for ALB inbound rule) ─────────────────────

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# ── Current AWS account ID and region ─────────────────────────────────────────

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
