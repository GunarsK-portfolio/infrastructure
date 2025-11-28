# Secrets Module
# Manages AWS Secrets Manager secrets for the portfolio application
# IMPORTANT: No hardcoded secrets - secrets are created with placeholder values
# Actual secret values must be populated manually or via external process

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# Get current AWS account and caller identity
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for Secrets Encryption (optional, enhances audit trail)
resource "aws_kms_key" "secrets" {
  description             = "${var.project_name}-${var.environment}-secrets-key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # Explicit key policy for least-privilege access control
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Get*",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:CreateGrant",
          "kms:RetireGrant",
          "kms:TagResource",
          "kms:UntagResource"
        ]
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
        Sid    = "Allow Secrets Manager to use the key"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
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
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "sns.${data.aws_region.current.region}.amazonaws.com"
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
      },
      {
        Sid    = "Allow ECR to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:RetireGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ecr.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow CloudTrail to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "cloudtrail.${data.aws_region.current.region}.amazonaws.com",
              "s3.${data.aws_region.current.region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-secrets-kms"
    }
  )
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# Aurora Master Password Secret
resource "aws_secretsmanager_secret" "aurora_master_password" {
  name_prefix             = "${var.project_name}-${var.environment}-aurora-master-"
  description             = "Aurora Serverless v2 master password"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-master-password"
    }
  )
}

# Initial secret version with strong random password
# IMPORTANT: Update this with your own secure password after deployment using:
# aws secretsmanager update-secret --secret-id <secret-arn> --secret-string '{"username":"portfolio_master","password":"your-secure-password"}'
resource "aws_secretsmanager_secret_version" "aurora_master_password" {
  secret_id = aws_secretsmanager_secret.aurora_master_password.id
  secret_string = jsonencode({
    username = "portfolio_master"
    password = random_password.aurora_master.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Aurora Owner User Password
resource "aws_secretsmanager_secret" "aurora_owner_password" {
  name_prefix             = "${var.project_name}-${var.environment}-aurora-owner-"
  description             = "Aurora owner user password (DDL rights)"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-owner-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "aurora_owner_password" {
  secret_id = aws_secretsmanager_secret.aurora_owner_password.id
  secret_string = jsonencode({
    username = "portfolio_owner"
    password = random_password.aurora_owner.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Aurora Admin User Password
resource "aws_secretsmanager_secret" "aurora_admin_password" {
  name_prefix             = "${var.project_name}-${var.environment}-aurora-admin-"
  description             = "Aurora admin user password (DML rights)"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-admin-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "aurora_admin_password" {
  secret_id = aws_secretsmanager_secret.aurora_admin_password.id
  secret_string = jsonencode({
    username = "portfolio_admin"
    password = random_password.aurora_admin.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Aurora Public User Password
resource "aws_secretsmanager_secret" "aurora_public_password" {
  name_prefix             = "${var.project_name}-${var.environment}-aurora-public-"
  description             = "Aurora public user password (SELECT only)"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-public-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "aurora_public_password" {
  secret_id = aws_secretsmanager_secret.aurora_public_password.id
  secret_string = jsonencode({
    username = "portfolio_public"
    password = random_password.aurora_public.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Aurora Messaging User Password
resource "aws_secretsmanager_secret" "aurora_messaging_password" {
  name_prefix             = "${var.project_name}-${var.environment}-aurora-messaging-"
  description             = "Aurora messaging user password (CRUD on messaging schema only)"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-messaging-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "aurora_messaging_password" {
  secret_id = aws_secretsmanager_secret.aurora_messaging_password.id
  secret_string = jsonencode({
    username = "portfolio_messaging"
    password = random_password.aurora_messaging.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Redis AUTH Token
resource "aws_secretsmanager_secret" "redis_auth_token" {
  name_prefix             = "${var.project_name}-${var.environment}-redis-auth-"
  description             = "ElastiCache Redis AUTH token"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-auth-token"
    }
  )
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = jsonencode({
    token = random_password.redis_auth.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name_prefix             = "${var.project_name}-${var.environment}-jwt-secret-"
  description             = "JWT signing secret for authentication"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-jwt-secret"
    }
  )
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    secret = random_password.jwt_secret.result
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Random passwords (temporary, must be replaced)
resource "random_password" "aurora_master" {
  length  = 32
  special = true
}

resource "random_password" "aurora_owner" {
  length  = 32
  special = true
}

resource "random_password" "aurora_admin" {
  length  = 32
  special = true
}

resource "random_password" "aurora_public" {
  length  = 32
  special = true
}

resource "random_password" "aurora_messaging" {
  length  = 32
  special = true
}

resource "random_password" "redis_auth" {
  length  = 32
  special = true
  # ElastiCache auth tokens cannot contain @, ", or /
  override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

# CloudWatch Log Group for secret rotation Lambda (if rotation enabled)
resource "aws_cloudwatch_log_group" "rotation" {
  count = var.enable_rotation ? 1 : 0

  name              = "/aws/lambda/${var.project_name}-${var.environment}-secret-rotation"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.secrets.arn

  tags = var.tags
}
