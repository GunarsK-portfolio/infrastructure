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
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudTrail alarms (optional)"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption (S3 bucket and CloudWatch logs)"
  type        = string
}
