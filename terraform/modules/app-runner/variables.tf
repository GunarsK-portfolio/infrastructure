# App Runner Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "app_runner_security_group_id" {
  description = "Security group ID for App Runner VPC connector"
  type        = string
}

variable "services" {
  description = "Map of service configurations"
  type = map(object({
    name              = string
    cpu               = string
    memory            = string
    port              = number
    min_instances     = number
    max_instances     = number
    max_concurrency   = number
    health_check_path = string
  }))
}

variable "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  type        = map(string)
}

variable "service_image_tags" {
  description = "Map of service names to Docker image tags (use semantic versioning, e.g., v1.0.0)"
  type        = map(string)
}

variable "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  type        = string
}

variable "elasticache_endpoint" {
  description = "ElastiCache endpoint"
  type        = string
}

variable "s3_bucket_names" {
  description = "Map of S3 bucket names"
  type        = map(string)
}

variable "secrets_arns" {
  description = "Map of Secrets Manager ARNs"
  type        = map(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN for decrypting secrets"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name (e.g., gunarsk.com). Subdomains: admin.*, auth.*, files.*"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
