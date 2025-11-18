# Terraform Variables
# Define all input variables for the infrastructure

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "portfolio"
}

variable "owner" {
  description = "Project owner/team name"
  type        = string
  default     = "DevOps"
}

variable "domain_name" {
  description = "Primary domain name (e.g., gunarsk.com). Subdomains: admin.*, auth.*, files.*"
  type        = string
  default     = "gunarsk.com"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required for high availability."
  }

  validation {
    condition     = alltrue([for az in var.availability_zones : can(regex("^${var.aws_region}[a-z]$", az))])
    error_message = "Availability zones must match the AWS region. Example: if aws_region is 'eu-west-1', AZs must be 'eu-west-1a', 'eu-west-1b', etc."
  }
}

# Aurora Serverless v2 Configuration
variable "aurora_min_capacity" {
  description = "Minimum ACUs for Aurora Serverless v2"
  type        = number
  default     = 1

  validation {
    condition     = var.aurora_min_capacity >= 0.5 && var.aurora_min_capacity <= 256
    error_message = "Aurora min capacity must be between 0.5 and 256 ACUs."
  }
}

variable "aurora_max_capacity" {
  description = "Maximum ACUs for Aurora Serverless v2"
  type        = number
  default     = 16

  validation {
    condition     = var.aurora_max_capacity >= 0.5 && var.aurora_max_capacity <= 256
    error_message = "Aurora max capacity must be between 0.5 and 256 ACUs."
  }
}

variable "aurora_engine_version" {
  description = "PostgreSQL engine version for Aurora"
  type        = string
  default     = "17.4"
}

variable "aurora_backup_retention_days" {
  description = "Number of days to retain Aurora backups"
  type        = number
  default     = 30

  validation {
    condition     = var.aurora_backup_retention_days >= 1 && var.aurora_backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

# App Runner Configuration
variable "app_runner_services" {
  description = "List of App Runner service configurations"
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

  default = {
    auth-service = {
      name              = "auth-service"
      cpu               = "1 vCPU"
      memory            = "2 GB"
      port              = 8080
      min_instances     = 1
      max_instances     = 10
      max_concurrency   = 100
      health_check_path = "/health"
    }
    admin-api = {
      name              = "admin-api"
      cpu               = "1 vCPU"
      memory            = "2 GB"
      port              = 8080
      min_instances     = 1
      max_instances     = 10
      max_concurrency   = 100
      health_check_path = "/health"
    }
    public-api = {
      name              = "public-api"
      cpu               = "1 vCPU"
      memory            = "2 GB"
      port              = 8080
      min_instances     = 1
      max_instances     = 10
      max_concurrency   = 100
      health_check_path = "/health"
    }
    files-api = {
      name              = "files-api"
      cpu               = "1 vCPU"
      memory            = "2 GB"
      port              = 8080
      min_instances     = 1
      max_instances     = 10
      max_concurrency   = 100
      health_check_path = "/health"
    }
    admin-web = {
      name              = "admin-web"
      cpu               = "1 vCPU"
      memory            = "2 GB"
      port              = 80
      min_instances     = 1
      max_instances     = 10
      max_concurrency   = 100
      health_check_path = "/"
    }
    public-web = {
      name              = "public-web"
      cpu               = "1 vCPU"
      memory            = "2 GB"
      port              = 80
      min_instances     = 1
      max_instances     = 10
      max_concurrency   = 100
      health_check_path = "/"
    }
  }
}

variable "service_image_tags" {
  description = "Docker image tags per service (use semantic versioning, e.g., v1.0.0)"
  type        = map(string)
  default = {
    auth-service = "latest"
    admin-api    = "latest"
    public-api   = "latest"
    files-api    = "latest"
    admin-web    = "latest"
    public-web   = "latest"
  }

  validation {
    condition = alltrue([
      for tag in values(var.service_image_tags) :
      can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+", tag)) || tag == "latest"
    ])
    error_message = "All image tags must be semantic version (v1.0.0 or 1.0.0) or 'latest'. Use versioned tags for production."
  }
}

# S3 Bucket Configuration
variable "s3_buckets" {
  description = "List of S3 bucket types (final names: {project}-{type}-{env}-{account})"
  type        = list(string)
  default = [
    "images",
    "documents",
    "miniatures"
  ]

  validation {
    condition     = alltrue([for name in var.s3_buckets : can(regex("^[a-z0-9-]+$", name))])
    error_message = "Bucket types must contain only lowercase letters, numbers, and hyphens."
  }
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

# Security Configuration
variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring for Aurora"
  type        = bool
  default     = true
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights for Aurora"
  type        = bool
  default     = true
}


variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_budgets" {
  description = "Enable AWS Budgets for cost control"
  type        = bool
  default     = false
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD (only used if enable_budgets = true)"
  type        = number
  default     = 100
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts (only used if enable_budgets = true)"
  type        = list(string)
  default     = []
}

# CloudTrail Configuration
variable "cloudtrail_log_retention_days" {
  description = "Number of days to retain CloudTrail logs in CloudWatch"
  type        = number
  default     = 365

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudtrail_log_retention_days)
    error_message = "CloudTrail log retention must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_cloudtrail_alarms" {
  description = "Enable CloudWatch alarms for CloudTrail security events"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
