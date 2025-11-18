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
  description = "KMS key ARN for encrypting CloudWatch logs (optional)"
  type        = string
  default     = null
}
