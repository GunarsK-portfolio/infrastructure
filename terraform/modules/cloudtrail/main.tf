# CloudTrail Module
# Manages AWS CloudTrail for API audit logging
# Provides multi-region trail with CloudWatch integration and S3 storage

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# S3 Bucket for CloudTrail Logs
# Object Lock enabled to prevent log deletion/tampering
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.project_name}-cloudtrail-logs-${var.environment}-${var.account_id}"

  # Object Lock must be enabled at bucket creation
  object_lock_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cloudtrail-logs"
    }
  )
}

# Block all public access to CloudTrail bucket
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for CloudTrail bucket
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Object Lock configuration for CloudTrail bucket
# Compliance mode with 90-day retention prevents deletion of audit logs
resource "aws_s3_bucket_object_lock_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.cloudtrail]
}

# Server-side encryption for CloudTrail bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for CloudTrail logs
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "transition-old-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket ownership controls for CloudTrail bucket
resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Explicit ACL for CloudTrail bucket
resource "aws_s3_bucket_acl" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.cloudtrail]
}

# S3 Bucket for CloudTrail Access Logs
resource "aws_s3_bucket" "cloudtrail_logging" {
  bucket = "${var.project_name}-cloudtrail-access-logs-${var.environment}-${var.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cloudtrail-access-logs"
      Type = "logging"
    }
  )
}

# Block public access for CloudTrail logging bucket
resource "aws_s3_bucket_public_access_block" "cloudtrail_logging" {
  bucket = aws_s3_bucket.cloudtrail_logging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning for CloudTrail logging bucket
resource "aws_s3_bucket_versioning" "cloudtrail_logging" {
  bucket = aws_s3_bucket.cloudtrail_logging.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption for CloudTrail logging bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logging" {
  bucket = aws_s3_bucket.cloudtrail_logging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for CloudTrail logging bucket
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logging" {
  bucket = aws_s3_bucket.cloudtrail_logging.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket ownership controls for CloudTrail logging bucket
resource "aws_s3_bucket_ownership_controls" "cloudtrail_logging" {
  bucket = aws_s3_bucket.cloudtrail_logging.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# ACL for CloudTrail logging bucket
resource "aws_s3_bucket_acl" "cloudtrail_logging" {
  bucket = aws_s3_bucket.cloudtrail_logging.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.cloudtrail_logging]
}

# Enable S3 access logging for CloudTrail bucket
resource "aws_s3_bucket_logging" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  target_bucket = aws_s3_bucket.cloudtrail_logging.id
  target_prefix = "cloudtrail-access-logs/"

  depends_on = [aws_s3_bucket_acl.cloudtrail_logging]
}

# Bucket policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}-${var.environment}"
  retention_in_days = var.cloudtrail_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cloudtrail-logs"
    }
  )
}

# IAM Role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-${var.environment}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.project_name}-${var.environment}-cloudtrail-cw-policy"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      },
      {
        Sid    = "AWSCloudTrailPutLogEvents"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# CloudTrail Trail
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"
      values = [
        "arn:aws:s3:::${var.project_name}-*/"
      ]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cloudtrail"
    }
  )

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_cloudwatch
  ]
}

# CloudWatch Metric Filter for Security Events
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "${var.project_name}-${var.environment}-unauthorized-api-calls"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${var.project_name}/${var.environment}/CloudTrail"
    value     = "1"
  }
}

# CloudWatch Alarm for Unauthorized API Calls
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  count = var.enable_cloudtrail_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.project_name}/${var.environment}/CloudTrail"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Triggers when unauthorized API calls are detected"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = var.tags
}

# CloudWatch Metric Filter for Root Account Usage
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  name           = "${var.project_name}-${var.environment}-root-account-usage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "${var.project_name}/${var.environment}/CloudTrail"
    value     = "1"
  }
}

# CloudWatch Alarm for Root Account Usage
resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  count = var.enable_cloudtrail_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-root-account-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootAccountUsage"
  namespace           = "${var.project_name}/${var.environment}/CloudTrail"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Triggers when root account is used"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = var.tags
}
