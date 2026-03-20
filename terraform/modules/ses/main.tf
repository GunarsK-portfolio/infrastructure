# SES Module
# Amazon Simple Email Service configuration

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

# SES Domain Identity
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# Route53 TXT record for domain verification
resource "aws_route53_record" "ses_verification" {
  zone_id = var.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main.verification_token]
}

# Wait for domain verification
resource "aws_ses_domain_identity_verification" "main" {
  domain     = aws_ses_domain_identity.main.id
  depends_on = [aws_route53_record.ses_verification]
}

# DKIM for domain authentication
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# Route53 DKIM CNAME records
resource "aws_route53_record" "ses_dkim" {
  count = 3

  zone_id = var.zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# MAIL FROM domain configuration
resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${var.domain_name}"
}

# Route53 MX record for MAIL FROM domain
resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = var.zone_id
  name    = aws_ses_domain_mail_from.main.mail_from_domain
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${data.aws_region.current.region}.amazonses.com"]
}

# Route53 SPF record for MAIL FROM domain
resource "aws_route53_record" "ses_mail_from_spf" {
  zone_id = var.zone_id
  name    = aws_ses_domain_mail_from.main.mail_from_domain
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}

# Current region data source
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# =============================================================================
# Email Receiving & Forwarding
# =============================================================================

locals {
  enable_forwarding = length(var.email_forwarding_rules) > 0
}

# MX record for inbound email (root domain)
resource "aws_route53_record" "ses_inbound_mx" {
  count = local.enable_forwarding ? 1 : 0

  zone_id = var.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 600
  records = ["10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com"]
}

# S3 bucket for raw incoming emails
resource "aws_s3_bucket" "ses_incoming" {
  count = local.enable_forwarding ? 1 : 0

  bucket = "${var.project_name}-ses-incoming-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-ses-incoming"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "ses_incoming" {
  count = local.enable_forwarding ? 1 : 0

  bucket = aws_s3_bucket.ses_incoming[0].id

  rule {
    id     = "expire-after-30-days"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ses_incoming" {
  count = local.enable_forwarding ? 1 : 0

  bucket = aws_s3_bucket.ses_incoming[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ses_incoming" {
  count = local.enable_forwarding ? 1 : 0

  bucket                  = aws_s3_bucket.ses_incoming[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SES needs permission to write to S3
resource "aws_s3_bucket_policy" "ses_incoming" {
  count = local.enable_forwarding ? 1 : 0

  bucket = aws_s3_bucket.ses_incoming[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSESPuts"
        Effect    = "Allow"
        Principal = { Service = "ses.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.ses_incoming[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# SES Receipt Rule Set
resource "aws_ses_receipt_rule_set" "main" {
  count = local.enable_forwarding ? 1 : 0

  rule_set_name = "${var.project_name}-${var.environment}-inbound"
}

resource "aws_ses_active_receipt_rule_set" "main" {
  count = local.enable_forwarding ? 1 : 0

  rule_set_name = aws_ses_receipt_rule_set.main[0].rule_set_name
}

# SES Receipt Rule — store to S3, then invoke Lambda
resource "aws_ses_receipt_rule" "forward" {
  count = local.enable_forwarding ? 1 : 0

  name          = "${var.project_name}-forward"
  rule_set_name = aws_ses_receipt_rule_set.main[0].rule_set_name
  recipients    = keys(var.email_forwarding_rules)
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.ses_incoming[0].id
    object_key_prefix = "incoming/"
    position          = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.email_forwarder[0].arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_s3_bucket_policy.ses_incoming[0],
    aws_lambda_permission.ses[0],
  ]
}

# =============================================================================
# Lambda — Email Forwarder
# =============================================================================

data "archive_file" "email_forwarder" {
  count = local.enable_forwarding ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/forward_email.py"
  output_path = "${path.module}/lambda/forward_email.zip"
}

resource "aws_lambda_function" "email_forwarder" {
  count = local.enable_forwarding ? 1 : 0

  function_name    = "${var.project_name}-${var.environment}-email-forwarder"
  filename         = data.archive_file.email_forwarder[0].output_path
  source_code_hash = data.archive_file.email_forwarder[0].output_base64sha256
  handler          = "forward_email.handler"
  runtime          = "python3.13"
  timeout          = 30
  memory_size      = 128

  role = aws_iam_role.email_forwarder[0].arn

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.ses_incoming[0].id
      FORWARDING_RULES = jsonencode(var.email_forwarding_rules)
      FROM_DOMAIN      = var.domain_name
    }
  }

  tags = var.tags
}

# Allow SES to invoke Lambda
resource "aws_lambda_permission" "ses" {
  count = local.enable_forwarding ? 1 : 0

  statement_id   = "AllowSESInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.email_forwarder[0].function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "email_forwarder" {
  count = local.enable_forwarding ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.email_forwarder[0].function_name}"
  retention_in_days = 14

  tags = var.tags
}

# IAM Role for Lambda
resource "aws_iam_role" "email_forwarder" {
  count = local.enable_forwarding ? 1 : 0

  name = "${var.project_name}-${var.environment}-email-forwarder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "email_forwarder" {
  count = local.enable_forwarding ? 1 : 0

  name = "email-forwarder-policy"
  role = aws_iam_role.email_forwarder[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.ses_incoming[0].arn}/*"
      },
      {
        Sid      = "SESSend"
        Effect   = "Allow"
        Action   = ["ses:SendRawEmail"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}
