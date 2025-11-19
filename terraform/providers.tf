# AWS Provider Configuration
# Defines required Terraform and provider versions

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.23"
    }
  }
}

# Primary AWS Provider - EU West 1 (Ireland)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Portfolio"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Secondary AWS Provider for ACM Certificates
# CloudFront requires certificates in us-east-1 region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "Portfolio"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# PostgreSQL Provider for Database User Management
# Connects to Aurora cluster to create application users
provider "postgresql" {
  host            = module.database.cluster_endpoint
  port            = 5432
  database        = "portfolio"
  username        = jsondecode(data.aws_secretsmanager_secret_version.master_password.secret_string)["username"]
  password        = jsondecode(data.aws_secretsmanager_secret_version.master_password.secret_string)["password"]
  sslmode         = "require"
  connect_timeout = 15
  superuser       = false
}
