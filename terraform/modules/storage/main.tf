# Storage Module
# S3 Buckets for file storage

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# S3 Buckets
resource "aws_s3_bucket" "main" {
  for_each = toset(var.bucket_names)

  bucket = "${var.project_name}-${each.key}-${var.environment}-${var.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${each.key}-${var.environment}"
      Type = each.key
    }
  )
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policies (optimized for different bucket types)
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  # Transition to IA after 30 days (all buckets)
  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  # Transition to Glacier - different policies per bucket type
  # Images: 365 days (frequently accessed)
  # Documents: 180 days (moderately accessed)
  # Miniatures: 365 days (frequently accessed)
  rule {
    id     = "transition-to-glacier"
    status = contains(["images", "miniatures"], each.key) ? "Disabled" : "Enabled"

    filter {}

    transition {
      days          = each.key == "documents" ? 180 : 365
      storage_class = "GLACIER"
    }
  }

  # Expire old versions after 90 days
  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  # Clean up incomplete multipart uploads
  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# CORS configuration
resource "aws_s3_bucket_cors_configuration" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST"]
    allowed_origins = var.allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Bucket ownership controls
# BucketOwnerEnforced disables ACLs - buckets default to private without explicit ACL
resource "aws_s3_bucket_ownership_controls" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 Bucket for Access Logs
resource "aws_s3_bucket" "logging" {
  bucket = "${var.project_name}-s3-access-logs-${var.environment}-${var.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-s3-access-logs"
      Type = "logging"
    }
  )
}

# Block public access for logging bucket
resource "aws_s3_bucket_public_access_block" "logging" {
  bucket = aws_s3_bucket.logging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning for logging bucket
resource "aws_s3_bucket_versioning" "logging" {
  bucket = aws_s3_bucket.logging.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption for logging bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for logging bucket
resource "aws_s3_bucket_lifecycle_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Bucket ownership controls for logging bucket
resource "aws_s3_bucket_ownership_controls" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# ACL for logging bucket
resource "aws_s3_bucket_acl" "logging" {
  bucket = aws_s3_bucket.logging.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.logging]
}

# Enable S3 access logging for all buckets
resource "aws_s3_bucket_logging" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  target_bucket = aws_s3_bucket.logging.id
  target_prefix = "s3-access-logs/${each.key}/"

  depends_on = [aws_s3_bucket_acl.logging]
}

# Bucket policy (deny non-HTTPS) for main buckets
resource "aws_s3_bucket_policy" "main" {
  for_each = aws_s3_bucket.main

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Bucket policy (deny non-HTTPS) for logging bucket
resource "aws_s3_bucket_policy" "logging" {
  bucket = aws_s3_bucket.logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logging.arn,
          "${aws_s3_bucket.logging.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
