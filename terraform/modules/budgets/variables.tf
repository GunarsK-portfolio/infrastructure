# Budgets Module Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_budgets" {
  description = "Enable AWS Budgets"
  type        = bool
  default     = true
}

variable "enable_daily_budget" {
  description = "Enable daily budget alerts for rapid cost detection"
  type        = bool
  default     = false
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 100
}

variable "daily_budget_limit" {
  description = "Daily budget limit in USD (only used if enable_daily_budget = true)"
  type        = number
  default     = 10
}

variable "alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "At least one email address must be provided for budget alerts."
  }
}

variable "service_budgets" {
  description = "Service-specific budgets (optional)"
  type = map(object({
    service_name = string
    limit        = number
    time_unit    = string
  }))
  default = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
