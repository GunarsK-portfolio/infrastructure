# Cache Module Outputs

output "cache_id" {
  description = "ElastiCache serverless cache ID"
  value       = aws_elasticache_serverless_cache.main.id
}

output "cache_arn" {
  description = "ElastiCache serverless cache ARN"
  value       = aws_elasticache_serverless_cache.main.arn
}

output "primary_endpoint" {
  description = "Primary endpoint (port 6379 - write endpoint)"
  value       = aws_elasticache_serverless_cache.main.endpoint[0].address
  sensitive   = true
}

output "reader_endpoint" {
  description = "Reader endpoint (port 6380 - read endpoint)"
  value       = length(aws_elasticache_serverless_cache.main.reader_endpoint) > 0 ? aws_elasticache_serverless_cache.main.reader_endpoint[0].address : null
  sensitive   = true
}

output "port" {
  description = "Cache port"
  value       = aws_elasticache_serverless_cache.main.endpoint[0].port
}
