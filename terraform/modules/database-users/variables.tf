# Variables for Database Users Module

variable "database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
}

variable "owner_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing portfolio_owner password"
  type        = string
}

variable "admin_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing portfolio_admin password"
  type        = string
}

variable "public_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing portfolio_public password"
  type        = string
}
