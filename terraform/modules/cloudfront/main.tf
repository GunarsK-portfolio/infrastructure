# CloudFront Module
# CDN distributions with path-based routing to App Runner services

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# Response Headers Policy - Security Headers (for frontends)
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.project_name}-${var.environment}-security-headers"
  comment = "Security headers for ${var.project_name} ${var.environment}"

  security_headers_config {
    # Force HTTPS for 2 years (HSTS)
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # Prevent clickjacking
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # Prevent MIME sniffing
    content_type_options {
      override = true
    }

    # Control referrer information
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # XSS protection for legacy browsers
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    # Content Security Policy
    # SECURITY NOTE: This CSP uses 'unsafe-hashes' (CSP Level 3) for inline styles
    # Vue @click/@change directives do NOT need unsafe-hashes (they compile to JS)
    # ACTUAL REASON: Vue :style bindings, v-show directive, and Naive UI runtime styles
    #   generate inline style attributes that cannot be nonce-protected
    # RISK: Weaker than nonce-based CSP, but significantly safer than 'unsafe-inline'
    # TODO (8h): Migrate to nonce-based CSP by refactoring all inline styles to CSS classes
    content_security_policy {
      # SECURITY NOTE: Uses 'unsafe-inline' for styles due to Naive UI limitations
      # - Naive UI generates inline styles that cannot be hashed or nonced
      # - 'unsafe-hashes' (CSP L3) is not supported in Safari and insufficient for Naive UI
      # - Scripts remain strict ('self' only, no unsafe-inline/unsafe-eval)
      # - TODO: Migrate to nonce-based CSP when Naive UI supports it
      content_security_policy = join("; ", [
        "default-src 'self'",
        "script-src 'self'",                # Strict: no inline scripts
        "style-src 'self' 'unsafe-inline'", # Required for Naive UI inline styles
        "img-src 'self' data: blob: https:", # Allow external images, data URIs, and blob URLs for WebP conversion
        "font-src 'self' data:",            # Allow web fonts
        "connect-src 'self' https:",        # Allow HTTPS API calls
        "frame-ancestors 'none'",           # Prevent clickjacking
        "base-uri 'self'",                  # Restrict <base> tag
        "form-action 'self'",               # Restrict form submissions
        "upgrade-insecure-requests"         # Upgrade HTTP to HTTPS
      ])
      override = true
    }
  }
}

# Response Headers Policy - API with CORS passthrough
# Uses origin CORS headers instead of adding new ones (override = false)
resource "aws_cloudfront_response_headers_policy" "api_cors" {
  name    = "${var.project_name}-${var.environment}-api-cors"
  comment = "API security headers with CORS passthrough for ${var.project_name} ${var.environment}"

  # CORS: Pass through origin headers (App Runner handles CORS logic)
  cors_config {
    access_control_allow_credentials = true

    access_control_allow_headers {
      items = ["Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With"]
    }

    access_control_allow_methods {
      items = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"]
    }

    access_control_allow_origins {
      items = ["https://${var.domain_name}", "https://admin.${var.domain_name}"]
    }

    access_control_max_age_sec = 86400

    # origin_override = false means: only add CORS if origin didn't set them
    # This lets App Runner's dynamic CORS logic take precedence
    origin_override = false
  }

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

# Public CloudFront Distribution (gunarsk.com)
# Routes: / -> public-web, /api/v1/* -> public-api
resource "aws_cloudfront_distribution" "public" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} Public Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # North America and Europe only
  aliases             = [var.domain_name]
  web_acl_id          = var.web_acl_arn

  # Origin: public-web (Vue frontend)
  origin {
    domain_name = var.app_runner_urls["public-web"]
    origin_id   = "public-web"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Origin: public-api (Go backend)
  origin {
    domain_name = var.app_runner_urls["public-api"]
    origin_id   = "public-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior: route to public-web (index.html - no caching)
  # index.html must not be cached to ensure new deployments serve fresh asset references
  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "public-web"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Path behavior: /assets/* -> public-web (hashed assets - long cache)
  # Vite generates hashed filenames, so assets can be cached indefinitely
  ordered_cache_behavior {
    path_pattern               = "/assets/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "public-web"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 31536000 # 1 year
    max_ttl     = 31536000
  }

  # Path behavior: /api/v1/* -> public-api
  ordered_cache_behavior {
    path_pattern           = "/api/v1/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "public-api"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Accept", "Content-Type", "Origin", "Referer", "User-Agent"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Path behavior: /health -> public-api
  ordered_cache_behavior {
    path_pattern           = "/health"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "public-api"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.3_2025"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "public/"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public"
    }
  )
}

# Admin CloudFront Distribution (admin.gunarsk.com)
# Routes: / -> admin-web, /api/v1/* -> admin-api, /health -> admin-api
resource "aws_cloudfront_distribution" "admin" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} Admin Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = ["admin.${var.domain_name}"]
  web_acl_id          = var.web_acl_arn

  # Origin: admin-web (Vue frontend)
  origin {
    domain_name = var.app_runner_urls["admin-web"]
    origin_id   = "admin-web"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Origin: admin-api (Go backend)
  origin {
    domain_name = var.app_runner_urls["admin-api"]
    origin_id   = "admin-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior: route to admin-web (index.html - no caching)
  # index.html must not be cached to ensure new deployments serve fresh asset references
  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "admin-web"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Path behavior: /assets/* -> admin-web (hashed assets - long cache)
  # Vite generates hashed filenames, so assets can be cached indefinitely
  ordered_cache_behavior {
    path_pattern               = "/assets/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "admin-web"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 31536000 # 1 year
    max_ttl     = 31536000
  }

  # Path behavior: /api/v1/* -> admin-api
  ordered_cache_behavior {
    path_pattern           = "/api/v1/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "admin-api"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Accept", "Origin", "Referer", "User-Agent", "X-Token-TTL"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Path behavior: /health -> admin-api
  ordered_cache_behavior {
    path_pattern           = "/health"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "admin-api"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.3_2025"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "admin/"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-admin"
    }
  )
}

# Auth Service CloudFront Distribution (auth.gunarsk.com)
# Single origin: auth-service
resource "aws_cloudfront_distribution" "auth" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} Auth Service Distribution"
  default_root_object = ""
  price_class         = "PriceClass_100"
  aliases             = ["auth.${var.domain_name}"]
  web_acl_id          = var.web_acl_arn

  origin {
    domain_name = var.app_runner_urls["auth-service"]
    origin_id   = "auth-service"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "auth-service"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.api_cors.id

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Accept", "Origin", "Referer", "User-Agent"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.3_2025"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "auth/"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-auth"
    }
  )
}

# Files API CloudFront Distribution (files.gunarsk.com)
# Single origin: files-api
resource "aws_cloudfront_distribution" "files" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} Files API Distribution"
  default_root_object = ""
  price_class         = "PriceClass_100"
  aliases             = ["files.${var.domain_name}"]
  web_acl_id          = var.web_acl_arn

  origin {
    domain_name = var.app_runner_urls["files-api"]
    origin_id   = "files-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "files-api"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.api_cors.id

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Content-Length", "Accept", "Origin", "Referer", "User-Agent", "Range", "If-Match", "If-None-Match"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.3_2025"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Enable access logging for debugging
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "files/"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-files"
    }
  )
}

# Messaging API CloudFront Distribution (message.gunarsk.com)
# Single origin: messaging-api
resource "aws_cloudfront_distribution" "message" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} Messaging API Distribution"
  default_root_object = ""
  price_class         = "PriceClass_100"
  aliases             = ["message.${var.domain_name}"]
  web_acl_id          = var.web_acl_arn

  origin {
    domain_name = var.app_runner_urls["messaging-api"]
    origin_id   = "messaging-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "messaging-api"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.api_cors.id

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Content-Length", "Accept", "Origin", "Referer", "User-Agent"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.3_2025"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "message/"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-message"
    }
  )
}

# S3 Bucket for CloudFront Access Logs
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${var.project_name}-${var.environment}-cloudfront-logs"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-cloudfront-logs"
    }
  )
}

# Block public access to logs bucket
resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable bucket ownership controls for CloudFront logging
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Lifecycle rule to delete old logs (30 days)
resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 30
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# KMS Key for CloudFront logs encryption
resource "aws_kms_key" "cloudfront_logs" {
  description             = "${var.project_name}-${var.environment}-cloudfront-logs-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudFront to use the key for log delivery"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "cloudfront_logs" {
  name          = "alias/${var.project_name}-${var.environment}-cloudfront-logs"
  target_key_id = aws_kms_key.cloudfront_logs.key_id
}

# Enable server-side encryption for logs bucket (KMS)
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudfront_logs.arn
    }
    bucket_key_enabled = true
  }
}
