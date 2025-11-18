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

# Response Headers Policy - Security Headers
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
  }

  # Content Security Policy
  # IMPORTANT: This CSP uses 'unsafe-hashes' for Vue 3 event handlers
  custom_headers_config {
    items {
      header = "Content-Security-Policy"
      # Strict CSP for production:
      # - Removed 'unsafe-inline' and 'unsafe-eval' for scripts
      # - Allow 'unsafe-hashes' for Vue event handlers (onclick, etc)
      # - Allow specific CDNs if needed (add to script-src/style-src)
      # - Use 'strict-dynamic' when nonce-based CSP is implemented
      value = join("; ", [
        "default-src 'self'",
        "script-src 'self' 'unsafe-hashes'", # unsafe-hashes allows Vue event handlers
        "style-src 'self' 'unsafe-hashes'",  # unsafe-hashes allows inline styles from Naive UI
        "img-src 'self' data: https:",       # Allow external images and data URIs
        "font-src 'self' data:",             # Allow web fonts
        "connect-src 'self' https:",         # Allow HTTPS API calls
        "frame-ancestors 'none'",            # Prevent clickjacking
        "base-uri 'self'",                   # Restrict <base> tag
        "form-action 'self'",                # Restrict form submissions
        "upgrade-insecure-requests"          # Upgrade HTTP to HTTPS
      ])
      override = true
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

  # Default behavior: route to public-web
  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "public-web"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
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
      headers      = ["*"]

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
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
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

  # Default behavior: route to admin-web
  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "admin-web"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
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
      headers      = ["*"]

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
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
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
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true
      headers      = ["*"]

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
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
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
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true
      headers      = ["*"]

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
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-files"
    }
  )
}
