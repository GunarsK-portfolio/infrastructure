# Message Queue Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Amazon MQ"
  type        = list(string)
}

variable "mq_security_group_id" {
  description = "Security group ID for Amazon MQ"
  type        = string
}

variable "instance_type" {
  description = "Amazon MQ instance type"
  type        = string
  default     = "mq.t3.micro"

  validation {
    condition     = can(regex("^mq\\.", var.instance_type))
    error_message = "Instance type must be a valid Amazon MQ instance type (mq.t3.micro, mq.m5.large, etc.)."
  }
}

variable "engine_version" {
  description = "RabbitMQ engine version"
  type        = string
  default     = "4.2"

  validation {
    condition     = can(regex("^[34]\\.", var.engine_version))
    error_message = "Engine version must be a valid RabbitMQ version (3.x or 4.x)."
  }
}

variable "credentials_secret_arn" {
  description = "ARN of Secrets Manager secret containing RabbitMQ credentials"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
