# Cache Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ElastiCache"
  type        = list(string)
}

variable "cache_security_group_id" {
  description = "Security group ID for ElastiCache"
  type        = string
}

variable "max_data_storage_gb" {
  description = "Maximum data storage in GB"
  type        = number
  default     = 1
}

variable "max_ecpu_per_second" {
  description = "Maximum ECPU per second"
  type        = number
  default     = 5000
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots (30 days for ransomware recovery)"
  type        = number
  default     = 30

  validation {
    condition     = var.snapshot_retention_days >= 1 && var.snapshot_retention_days <= 35
    error_message = "Snapshot retention must be between 1 and 35 days."
  }
}

variable "auth_token_secret_arn" {
  description = "ARN of Secrets Manager secret containing Redis auth token"
  type        = string
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
