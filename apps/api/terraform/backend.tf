terraform {
  backend "s3" {
    bucket         = "plc-copilot-terraform-state"
    key            = "api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "plc-copilot-terraform-locks"
    encrypt        = true
  }
}
