# Terraform Outputs
# Export important resource information for other modules or external use

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

# Aurora Outputs
output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.database.cluster_endpoint
  sensitive   = true
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.database.cluster_reader_endpoint
  sensitive   = true
}

output "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  value       = module.database.cluster_id
}

# ElastiCache Outputs
output "elasticache_primary_endpoint" {
  description = "ElastiCache primary endpoint (port 6379)"
  value       = module.cache.primary_endpoint
  sensitive   = true
}

output "elasticache_reader_endpoint" {
  description = "ElastiCache reader endpoint (port 6380)"
  value       = module.cache.reader_endpoint
  sensitive   = true
}

# S3 Outputs
output "s3_bucket_names" {
  description = "Names of S3 buckets"
  value       = module.storage.bucket_names
}

output "s3_bucket_arns" {
  description = "ARNs of S3 buckets"
  value       = module.storage.bucket_arns
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "URLs of ECR repositories"
  value       = module.ecr.repository_urls
}

# App Runner Outputs
output "app_runner_service_urls" {
  description = "URLs of App Runner services"
  value       = module.app_runner.service_urls
  sensitive   = true
}

output "app_runner_vpc_connector_arn" {
  description = "ARN of App Runner VPC connector"
  value       = module.app_runner.vpc_connector_arn
}

# CloudFront Outputs
output "cloudfront_distribution_ids" {
  description = "Map of CloudFront distribution IDs"
  value = {
    public = module.cloudfront.public_distribution_id
    admin  = module.cloudfront.admin_distribution_id
    auth   = module.cloudfront.auth_distribution_id
    files  = module.cloudfront.files_distribution_id
  }
}

output "cloudfront_distribution_urls" {
  description = "Map of CloudFront distribution URLs"
  value       = module.cloudfront.distribution_urls
}

# Route53 Outputs
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.dns.zone_id
}

output "route53_name_servers" {
  description = "Route53 hosted zone name servers"
  value       = module.dns.name_servers
}

# ACM Certificate Outputs
output "acm_certificate_arn" {
  description = "ARN of ACM certificate"
  value       = module.certificates.certificate_arn
}

# Secrets Manager Outputs
output "secrets_manager_arns" {
  description = "ARNs of secrets in Secrets Manager"
  value       = module.secrets.secret_arns
  sensitive   = true
}

# WAF Outputs
output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = module.waf.web_acl_id
}

# Monitoring Outputs
output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.monitoring.dashboard_name
}

output "cloudwatch_log_group_names" {
  description = "CloudWatch log group names"
  value       = module.monitoring.log_group_names
}
