variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
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
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption (S3 bucket and CloudWatch logs)"
  type        = string
}
