variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID (12 digits)"
  type        = string

  validation {
    condition     = can(regex("^\\d{12}$", var.account_id))
    error_message = "AWS Account ID must be exactly 12 digits."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cloudtrail_log_retention_days" {
  description = "Number of days to retain CloudTrail logs in CloudWatch"
  type        = number
  default     = 90

  validation {
    condition     = var.cloudtrail_log_retention_days >= 1 && var.cloudtrail_log_retention_days <= 3653
    error_message = "CloudTrail log retention must be between 1 and 3653 days (approximately 10 years)."
  }
}

variable "enable_cloudtrail_alarms" {
  description = "Enable CloudWatch alarms for CloudTrail security events"
  type        = bool
  default     = true

  validation {
    condition     = !var.enable_cloudtrail_alarms || var.sns_topic_arn != ""
    error_message = "SNS topic ARN is required when CloudTrail alarms are enabled. Set enable_cloudtrail_alarms=false or provide sns_topic_arn."
  }
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudTrail alarms (required if enable_cloudtrail_alarms=true)"
  type        = string
  default     = ""

  validation {
    condition     = var.sns_topic_arn == "" || can(regex("^arn:aws:sns:[a-z0-9-]+:\\d{12}:[a-zA-Z0-9_-]+$", var.sns_topic_arn))
    error_message = "SNS topic ARN must be a valid ARN format: arn:aws:sns:region:account-id:topic-name or empty string."
  }
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption (S3 bucket and CloudWatch logs)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:\\d{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format (arn:aws:kms:region:account-id:key/key-id)."
  }
}
