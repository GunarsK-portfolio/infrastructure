# DNS Module Variables

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "admin_domain_name" {
  description = "Admin subdomain name"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
}

variable "cloudfront_zone_id" {
  description = "CloudFront hosted zone ID"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
