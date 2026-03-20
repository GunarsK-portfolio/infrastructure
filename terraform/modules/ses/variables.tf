# SES Module Variables

variable "domain_name" {
  description = "Domain name for SES identity"
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for S3 encryption"
  type        = string
  default     = null
}

variable "email_forwarding_rules" {
  description = "Map of forwarding rules: recipient address → forwarding address"
  type        = map(string)
  default     = {}
  sensitive   = true
}
