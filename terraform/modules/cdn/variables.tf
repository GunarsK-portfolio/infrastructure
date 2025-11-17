# CDN Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "admin_domain_name" {
  description = "Admin domain name"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  type        = string
}

variable "app_runner_service_urls" {
  description = "Map of App Runner service URLs"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
