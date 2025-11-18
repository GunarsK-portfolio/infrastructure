# CloudFront Module Outputs

output "public_distribution_id" {
  description = "Public CloudFront distribution ID"
  value       = aws_cloudfront_distribution.public.id
}

output "public_distribution_domain_name" {
  description = "Public CloudFront distribution domain name (for DNS CNAME)"
  value       = aws_cloudfront_distribution.public.domain_name
}

output "admin_distribution_id" {
  description = "Admin CloudFront distribution ID"
  value       = aws_cloudfront_distribution.admin.id
}

output "admin_distribution_domain_name" {
  description = "Admin CloudFront distribution domain name (for DNS CNAME)"
  value       = aws_cloudfront_distribution.admin.domain_name
}

output "auth_distribution_id" {
  description = "Auth CloudFront distribution ID"
  value       = aws_cloudfront_distribution.auth.id
}

output "auth_distribution_domain_name" {
  description = "Auth CloudFront distribution domain name (for DNS CNAME)"
  value       = aws_cloudfront_distribution.auth.domain_name
}

output "files_distribution_id" {
  description = "Files CloudFront distribution ID"
  value       = aws_cloudfront_distribution.files.id
}

output "files_distribution_domain_name" {
  description = "Files CloudFront distribution domain name (for DNS CNAME)"
  value       = aws_cloudfront_distribution.files.domain_name
}

output "distribution_urls" {
  description = "Map of all CloudFront distribution URLs"
  value = {
    public = "https://${var.domain_name}"
    admin  = "https://admin.${var.domain_name}"
    auth   = "https://auth.${var.domain_name}"
    files  = "https://files.${var.domain_name}"
  }
}
