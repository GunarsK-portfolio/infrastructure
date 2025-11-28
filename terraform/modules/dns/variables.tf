# DNS Module Variables

variable "domain_name" {
  description = "Primary domain name (e.g., gunarsk.com). Subdomains: admin.*, auth.*, files.*"
  type        = string
}

variable "create_zone" {
  description = "Whether to create the hosted zone and base resources (CAA, logging). Set false for records-only mode."
  type        = bool
  default     = true
}

variable "zone_id" {
  description = "Existing Route53 zone ID (required when create_zone = false)"
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null || can(regex("^Z[A-Z0-9]+$", var.zone_id))
    error_message = "Zone ID must be a valid Route53 hosted zone ID format (e.g., Z1234567890ABC)."
  }
}

variable "cloudfront_distributions" {
  description = "Map of CloudFront distribution domain names (optional - records created only if provided)"
  type = object({
    public  = string
    admin   = string
    auth    = string
    files   = string
    message = string
  })
  default = null
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
