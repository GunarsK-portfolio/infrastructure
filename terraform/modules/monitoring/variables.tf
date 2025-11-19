# Monitoring Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "app_runner_service_arns" {
  description = "Map of App Runner service ARNs (service_name => ARN)"
  type        = map(string)
}

variable "cloudfront_distribution_ids" {
  description = "Map of CloudFront distribution IDs"
  type        = map(string)
}

variable "waf_web_acl_name" {
  description = "Name of the WAF Web ACL for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

variable "enable_waf_alarms" {
  description = "Enable WAF alarms"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Database monitoring variables
variable "db_cluster_id" {
  description = "Aurora cluster ID for monitoring"
  type        = string
  default     = ""
}

variable "enable_db_alarms" {
  description = "Enable Aurora database alarms"
  type        = bool
  default     = true
}

# Cache monitoring variables
variable "cache_id" {
  description = "ElastiCache serverless cache ID for monitoring"
  type        = string
  default     = ""
}

variable "enable_cache_alarms" {
  description = "Enable ElastiCache alarms"
  type        = bool
  default     = true
}

# App Runner alarm thresholds
variable "app_runner_4xx_threshold" {
  description = "Threshold for App Runner 4xx error rate (%)"
  type        = number
  default     = 5
}

variable "app_runner_5xx_threshold" {
  description = "Threshold for App Runner 5xx error rate (%)"
  type        = number
  default     = 1
}

variable "app_runner_latency_threshold" {
  description = "Threshold for App Runner request latency (seconds)"
  type        = number
  default     = 3
}

variable "app_runner_request_count_threshold" {
  description = "Threshold for App Runner low request count (per 5 min, indicates service down)"
  type        = number
  default     = 1
}

# Database alarm thresholds
variable "db_connection_threshold" {
  description = "Threshold for Aurora database connections"
  type        = number
  default     = 400
}

# Cache alarm thresholds
variable "cache_memory_threshold" {
  description = "Threshold for ElastiCache memory utilization (%)"
  type        = number
  default     = 80
}

variable "cache_max_data_storage_gb" {
  description = "Maximum data storage in GB for ElastiCache (used to calculate memory percentage)"
  type        = number
  default     = 10
}

variable "cache_evictions_threshold" {
  description = "Threshold for ElastiCache evictions per minute"
  type        = number
  default     = 100
}

# SNS configuration
variable "alarm_email_addresses" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:\\d{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format (arn:aws:kms:region:account-id:key/key-id) or null."
  }
}
