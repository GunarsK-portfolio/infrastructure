# Database Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Aurora"
  type        = list(string)
}

variable "database_security_group_id" {
  description = "Security group ID for Aurora"
  type        = string
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = "portfolio"
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "17.4"
}

variable "min_capacity" {
  description = "Minimum Aurora Capacity Units"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum Aurora Capacity Units"
  type        = number
  default     = 16
}

variable "backup_retention_days" {
  description = "Backup retention period in days (increased to 30 for disaster recovery)"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 7 and 35 days."
  }
}

variable "master_password_secret_arn" {
  description = "ARN of Secrets Manager secret containing master password"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:\\d{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format (arn:aws:kms:region:account-id:key/key-id)."
  }
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_days" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 31

  validation {
    condition     = contains([7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372, 403, 434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731], var.performance_insights_retention_days)
    error_message = "Performance Insights retention must be 7 days (free tier) or 31-731 days in monthly increments (long-term retention)."
  }
}

variable "enable_enhanced_monitoring" {
  description = "Enable Enhanced Monitoring"
  type        = bool
  default     = true
}

variable "max_connections" {
  description = "Maximum number of database connections (must be appropriate for ACU capacity)"
  type        = number
  default     = 400

  validation {
    condition     = var.max_connections >= 100 && var.max_connections <= 5000
    error_message = "max_connections must be between 100 and 5000."
  }
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
