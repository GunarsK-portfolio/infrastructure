# Storage Module Outputs

output "bucket_names" {
  description = "Map of bucket names"
  value       = { for k, v in aws_s3_bucket.main : k => v.id }
}

output "bucket_arns" {
  description = "Map of bucket ARNs"
  value       = { for k, v in aws_s3_bucket.main : k => v.arn }
}

output "bucket_regional_domain_names" {
  description = "Map of bucket regional domain names"
  value       = { for k, v in aws_s3_bucket.main : k => v.bucket_regional_domain_name }
}

output "logging_bucket_id" {
  description = "ID of the S3 access logs bucket"
  value       = aws_s3_bucket.logging.id
}

output "logging_bucket_arn" {
  description = "ARN of the S3 access logs bucket"
  value       = aws_s3_bucket.logging.arn
}
