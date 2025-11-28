# CloudFront Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name (e.g., gunarsk.com). Subdomains: admin.*, auth.*, files.*"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}

variable "app_runner_urls" {
  description = "Map of App Runner service URLs (without https://)"
  type        = map(string)

  validation {
    condition = alltrue([
      for required_key in ["public-web", "public-api", "admin-web", "admin-api", "auth-service", "files-api", "messaging-api"] :
      contains(keys(var.app_runner_urls), required_key)
    ])
    error_message = "app_runner_urls must contain all required service keys: public-web, public-api, admin-web, admin-api, auth-service, files-api, messaging-api"
  }
}

variable "web_acl_arn" {
  description = "WAF Web ACL ARN to attach to CloudFront distributions"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
