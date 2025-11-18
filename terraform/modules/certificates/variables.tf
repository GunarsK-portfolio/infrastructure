# Certificates Module Variables

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID for DNS validation (optional if using manual validation)"
  type        = string
  default     = ""
}

variable "use_route53_validation" {
  description = "Automatically create Route53 DNS validation records and wait for validation (set to false if DNS is managed in Cloudflare)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
