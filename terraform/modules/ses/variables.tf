# SES Module Variables

variable "domain_name" {
  description = "Domain name for SES identity"
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
}
