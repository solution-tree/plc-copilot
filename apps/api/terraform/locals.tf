locals {
  # Consistent resource-name prefix: e.g. "plc-copilot-staging"
  prefix = "${var.project}-${var.environment}"

  # Common tags merged onto every resource in addition to provider default_tags.
  # Add resource-specific tags at the resource level where needed.
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
