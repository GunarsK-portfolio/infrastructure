# ECR Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "service_names" {
  description = "List of service names for ECR repositories"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:[a-z0-9-]+:\\d{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format (arn:aws:kms:region:account-id:key/key-id)."
  }
}
