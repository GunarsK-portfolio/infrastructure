# DNS Module Outputs

output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.zone_id
}

output "zone_name" {
  description = "Route53 hosted zone name"
  value       = var.create_zone ? aws_route53_zone.main[0].name : var.domain_name
}

output "name_servers" {
  description = "Route53 hosted zone name servers (only available when create_zone = true)"
  value       = var.create_zone ? aws_route53_zone.main[0].name_servers : null
}
