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
  description = "KMS key ARN for ECR encryption (optional, uses customer-managed key if provided)"
  type        = string
  default     = null
}
