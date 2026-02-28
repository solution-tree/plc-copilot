terraform {
  backend "s3" {
    bucket         = "plc-copilot-tfstate"
    region         = "us-east-1"
    dynamodb_table = "plc-copilot-tfstate-lock"
    encrypt        = true
    # key is set via -backend-config at init time per environment:
    #   terraform init -backend-config="key=staging/terraform.tfstate"
    #   terraform init -backend-config="key=production/terraform.tfstate"
  }
}
