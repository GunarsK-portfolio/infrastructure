# App Runner Module Outputs

output "service_ids" {
  description = "Map of App Runner service IDs"
  value       = { for k, v in aws_apprunner_service.main : k => v.service_id }
}

output "service_arns" {
  description = "Map of App Runner service ARNs"
  value       = { for k, v in aws_apprunner_service.main : k => v.arn }
}

output "service_urls" {
  description = "Map of App Runner service URLs"
  value       = { for k, v in aws_apprunner_service.main : k => v.service_url }
  sensitive   = true
}

output "vpc_connector_arn" {
  description = "VPC connector ARN"
  value       = aws_apprunner_vpc_connector.main.arn
}
