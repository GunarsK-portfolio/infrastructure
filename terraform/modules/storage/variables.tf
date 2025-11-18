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

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
