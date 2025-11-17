# Budgets Module Outputs

output "monthly_budget_name" {
  description = "Monthly budget name"
  value       = var.enable_budgets ? aws_budgets_budget.monthly[0].name : null
}

output "daily_budget_name" {
  description = "Daily budget name"
  value       = var.enable_budgets && var.enable_daily_budget ? aws_budgets_budget.daily[0].name : null
}
