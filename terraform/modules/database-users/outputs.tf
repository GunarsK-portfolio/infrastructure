# Outputs for Database Users Module

output "owner_username" {
  description = "Username of the portfolio owner"
  value       = postgresql_role.portfolio_owner.name
}

output "admin_username" {
  description = "Username of the portfolio admin"
  value       = postgresql_role.portfolio_admin.name
}

output "public_username" {
  description = "Username of the portfolio public user"
  value       = postgresql_role.portfolio_public.name
}
