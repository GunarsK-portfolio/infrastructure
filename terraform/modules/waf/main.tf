# WAF Module
# AWS WAF for CloudFront (must be in us-east-1)

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for WAF CloudWatch Logs (us-east-1)
# Separate key required because WAF is in us-east-1 while main KMS key is in eu-west-1
resource "aws_kms_key" "waf_logs" {
  description             = "${var.project_name}-${var.environment}-waf-logs-key"
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
        Sid    = "Deny Dangerous Operations Without MFA"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:DisableKey",
          "kms:DeleteAlias"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# KMS Key Alias
resource "aws_kms_alias" "waf_logs" {
  name          = "alias/${var.project_name}-${var.environment}-waf-logs"
  target_key_id = aws_kms_key.waf_logs.key_id
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-${var.environment}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rate limiting for login endpoint (strict to prevent brute-force)
  # Matches: auth.gunarsk.com/*/login
  rule {
    name     = "rate-limit-login"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 10
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "auth.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "CONTAINS"
                search_string         = "/login"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitLogin"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for token refresh endpoint
  # Matches: auth.gunarsk.com/*/refresh
  rule {
    name     = "rate-limit-refresh"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "auth.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "CONTAINS"
                search_string         = "/refresh"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRefresh"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for token validation endpoint
  # Matches: auth.gunarsk.com/*/validate
  rule {
    name     = "rate-limit-validate"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 600
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "auth.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "CONTAINS"
                search_string         = "/validate"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitValidate"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for logout endpoint
  # Matches: auth.gunarsk.com/*/logout
  rule {
    name     = "rate-limit-logout"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 60
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "auth.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "CONTAINS"
                search_string         = "/logout"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitLogout"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for admin API - DELETE operations (most restrictive)
  # Matches: admin.gunarsk.com/api/v1/* + DELETE method
  rule {
    name     = "rate-limit-admin-api-delete"
    priority = 5

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 60
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "admin.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/api/v1"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "delete"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitAdminAPIDelete"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for admin API - POST operations (create operations)
  # Matches: admin.gunarsk.com/api/v1/* + POST method
  rule {
    name     = "rate-limit-admin-api-post"
    priority = 6

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 300
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "admin.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/api/v1"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "post"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitAdminAPIPost"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for admin API - PUT operations (update operations)
  # Matches: admin.gunarsk.com/api/v1/* + PUT method
  rule {
    name     = "rate-limit-admin-api-put"
    priority = 7

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 300
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "admin.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/api/v1"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "put"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitAdminAPIPut"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for admin API - GET operations (read operations)
  # Matches: admin.gunarsk.com/api/v1/* + GET method
  rule {
    name     = "rate-limit-admin-api-get"
    priority = 8

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 600
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "admin.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/api/v1"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                search_string         = "get"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitAdminAPIGet"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for public API
  # Matches: gunarsk.com/api/v1/* (read-only public API)
  rule {
    name     = "rate-limit-public-api"
    priority = 9

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 600
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              or_statement {
                statement {
                  byte_match_statement {
                    field_to_match {
                      single_header {
                        name = "host"
                      }
                    }
                    positional_constraint = "EXACTLY"
                    search_string         = var.domain_name
                    text_transformation {
                      priority = 0
                      type     = "LOWERCASE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    field_to_match {
                      single_header {
                        name = "host"
                      }
                    }
                    positional_constraint = "EXACTLY"
                    search_string         = "www.${var.domain_name}"
                    text_transformation {
                      priority = 0
                      type     = "LOWERCASE"
                    }
                  }
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/api/v1"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPublicAPI"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for files API
  # Matches: files.gunarsk.com/api/v1/files/*
  rule {
    name     = "rate-limit-files-api"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 120
        aggregate_key_type = "IP"

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "files.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/api/v1"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitFilesAPI"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting for messaging API (contact form)
  # Matches: message.gunarsk.com/api/v1/*
  # Stricter limit: 10 requests per 5 minutes per IP (anti-spam)
  rule {
    name     = "rate-limit-messaging-api"
    priority = 11

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = 10
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "message.${var.domain_name}"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                field_to_match {
                  uri_path {}
                }
                positional_constraint = "STARTS_WITH"
                search_string         = "/api/v1"
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMessagingAPI"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Core Rule Set (OWASP Top 10)
  # Override SizeRestrictions_BODY to count mode - allows file uploads > 8KB
  # Application enforces MAX_FILE_SIZE validation (10MB limit in files-api)
  rule {
    name     = "aws-managed-core-rule-set"
    priority = 12

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"

        # Override SizeRestrictions_BODY to count instead of block
        # This allows file uploads > 8KB to pass through
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedCoreRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs (Log4Shell, etc.)
  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 13

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedKnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - SQL Injection Protection
  rule {
    name     = "aws-managed-sqli-rule-set"
    priority = 14

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - IP Reputation List (Known Bad IPs)
  rule {
    name     = "aws-managed-ip-reputation-list"
    priority = 15

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedIPReputationList"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Linux Operating System Protection
  rule {
    name     = "aws-managed-linux-rule-set"
    priority = 16

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesLinuxRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedLinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# CloudWatch Log Group for WAF logs (30 days for security forensics)
# Uses local KMS key (us-east-1) instead of main secrets KMS key (eu-west-1)
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project_name}-${var.environment}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.waf_logs.arn

  tags = var.tags
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn = aws_wafv2_web_acl.main.arn

  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}