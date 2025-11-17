# Terraform Backend Configuration
# This file configures remote state storage in S3 with DynamoDB locking
#
# IMPORTANT: The S3 bucket and DynamoDB table must be created manually first
# or using a separate bootstrap Terraform configuration

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
