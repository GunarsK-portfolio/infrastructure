# Database Users Module
# Creates PostgreSQL users for the portfolio application

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.23"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# Data sources to fetch passwords from Secrets Manager
data "aws_secretsmanager_secret_version" "owner_password" {
  secret_id = var.owner_password_secret_arn
}

data "aws_secretsmanager_secret_version" "admin_password" {
  secret_id = var.admin_password_secret_arn
}

data "aws_secretsmanager_secret_version" "public_password" {
  secret_id = var.public_password_secret_arn
}

# Portfolio Owner User - DDL rights for migrations
resource "postgresql_role" "portfolio_owner" {
  name     = "portfolio_owner"
  login    = true
  password = jsondecode(data.aws_secretsmanager_secret_version.owner_password.secret_string)["password"]

  # Owner needs elevated privileges for DDL operations
  create_database = false
  create_role     = false
  inherit         = true
  replication     = false
  superuser       = false
}

# Portfolio Admin User - CRUD rights for application
resource "postgresql_role" "portfolio_admin" {
  name     = "portfolio_admin"
  login    = true
  password = jsondecode(data.aws_secretsmanager_secret_version.admin_password.secret_string)["password"]

  create_database = false
  create_role     = false
  inherit         = true
  replication     = false
  superuser       = false
}

# Portfolio Public User - SELECT only for public API
resource "postgresql_role" "portfolio_public" {
  name     = "portfolio_public"
  login    = true
  password = jsondecode(data.aws_secretsmanager_secret_version.public_password.secret_string)["password"]

  create_database = false
  create_role     = false
  inherit         = true
  replication     = false
  superuser       = false
}

# Grant rds_superuser to portfolio_owner for DDL operations
resource "postgresql_grant_role" "owner_rds_superuser" {
  role       = postgresql_role.portfolio_owner.name
  grant_role = "rds_superuser"
}

# Database-level grants
resource "postgresql_grant" "owner_database" {
  database    = var.database_name
  role        = postgresql_role.portfolio_owner.name
  object_type = "database"
  privileges  = ["CREATE", "CONNECT", "TEMPORARY"]
}

resource "postgresql_grant" "admin_database" {
  database    = var.database_name
  role        = postgresql_role.portfolio_admin.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "public_database" {
  database    = var.database_name
  role        = postgresql_role.portfolio_public.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

# Schema-level grants (requires connecting to the database)
# Note: These grants will be applied via Flyway migrations or manual setup
# because Terraform cannot dynamically switch databases within the provider
