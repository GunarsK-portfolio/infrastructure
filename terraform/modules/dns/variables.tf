# DNS Module Variables

variable "domain_name" {
  description = "Primary domain name (e.g., gunarsk.com). Subdomains: admin.*, auth.*, files.*"
  type        = string
}

variable "cloudfront_distributions" {
  description = "Map of CloudFront distribution domain names"
  type = object({
    public = string
    admin  = string
    auth   = string
    files  = string
  })
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
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
