# Monitoring Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "app_runner_service_arns" {
  description = "Map of App Runner service ARNs (service_name => ARN)"
  type        = map(string)
}

variable "cloudfront_distribution_ids" {
  description = "Map of CloudFront distribution IDs"
  type        = map(string)
}

variable "waf_web_acl_name" {
  description = "Name of the WAF Web ACL for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
