# Storage Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "bucket_names" {
  description = "List of bucket names"
  type        = list(string)
}

variable "allowed_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["https://gunarsk.com", "https://admin.gunarsk.com"]
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:\\d{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format (arn:aws:kms:region:account-id:key/key-id)."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
