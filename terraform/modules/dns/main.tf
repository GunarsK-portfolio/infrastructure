# DNS Module
# Route53 hosted zone and DNS records

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(
    var.tags,
    {
      Name = var.domain_name
    }
  )
}

# CloudFront hosted zone ID (constant for all CloudFront distributions)
locals {
  cloudfront_zone_id = "Z2FDTNDATAQYW2"
}

# A record for root domain (gunarsk.com) pointing to public CloudFront
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_distributions.public
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# AAAA record for root domain (IPv6)
resource "aws_route53_record" "root_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_distributions.public
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# A record for admin subdomain
resource "aws_route53_record" "admin" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "admin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_distributions.admin
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# AAAA record for admin subdomain (IPv6)
resource "aws_route53_record" "admin_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "admin.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_distributions.admin
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# A record for auth subdomain
resource "aws_route53_record" "auth" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "auth.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_distributions.auth
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# AAAA record for auth subdomain (IPv6)
resource "aws_route53_record" "auth_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "auth.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_distributions.auth
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# A record for files subdomain
resource "aws_route53_record" "files" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "files.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_distributions.files
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# AAAA record for files subdomain (IPv6)
resource "aws_route53_record" "files_ipv6" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "files.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_distributions.files
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# CAA records (Certificate Authority Authorization)
resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "CAA"
  ttl     = 3600

  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \"amazon.com\""
  ]
}

# DNSSEC Signing
resource "aws_route53_hosted_zone_dnssec" "main" {
  hosted_zone_id = aws_route53_zone.main.zone_id
}

# Query Logging
resource "aws_route53_query_log" "main" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53.arn
  zone_id                  = aws_route53_zone.main.zone_id
}

# CloudWatch Log Group for Route53 query logs
resource "aws_cloudwatch_log_group" "route53" {
  name              = "/aws/route53/${var.domain_name}"
  retention_in_days = 30

  tags = var.tags
}

# CloudWatch Log Resource Policy for Route53
resource "aws_cloudwatch_log_resource_policy" "route53" {
  policy_name = "${var.domain_name}-route53-query-logging"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.route53.arn}:*"
      }
    ]
  })
}
