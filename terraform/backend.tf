# Terraform Backend Configuration
# This file configures remote state storage in S3 with DynamoDB locking
#
# IMPORTANT: Backend configuration cannot use variables (Terraform limitation)
# For multi-environment deployments, use one of these approaches:
#
# Option 1: Backend config file (recommended)
#   Create backend-{env}.hcl files with environment-specific values:
#     terraform init -backend-config=backend-prod.hcl
#
# Option 2: CLI arguments
#   terraform init \
#     -backend-config="bucket=portfolio-terraform-state-{env}" \
#     -backend-config="dynamodb_table=portfolio-terraform-locks-{env}"
#
# Option 3: Terraform workspaces
#   Use workspace-aware state key:
#     key = "infrastructure/${terraform.workspace}/terraform.tfstate"
#
# The S3 bucket and DynamoDB table must be created first via bootstrap

terraform {
  backend "s3" {
    bucket         = "portfolio-terraform-state-prod"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "portfolio-terraform-locks"

    # Additional security settings
    # Enable versioning on the S3 bucket for state file recovery
    # Enable MFA delete for production environments
  }
}
