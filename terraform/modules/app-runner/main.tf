# App Runner Module
# AWS App Runner services with VPC connector

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

locals {
  # Service-specific environment variables
  service_env_vars = {
    "auth-service" = {
      ENVIRONMENT        = var.environment
      SERVICE_NAME       = "auth-service"
      LOG_LEVEL          = "info"
      LOG_FORMAT         = "json"
      DB_HOST            = var.aurora_endpoint
      DB_PORT            = "5432"
      DB_NAME            = "portfolio"
      DB_USER            = "portfolio_admin"
      REDIS_HOST         = var.elasticache_endpoint
      REDIS_PORT         = "6379"
      JWT_ACCESS_EXPIRY  = "15m"
      JWT_REFRESH_EXPIRY = "168h"
      ALLOWED_ORIGINS    = "https://admin.gk.codes"
    }
    "admin-api" = {
      ENVIRONMENT     = var.environment
      SERVICE_NAME    = "admin-api"
      LOG_LEVEL       = "info"
      LOG_FORMAT      = "json"
      DB_HOST         = var.aurora_endpoint
      DB_PORT         = "5432"
      DB_NAME         = "portfolio"
      DB_USER         = "portfolio_admin"
      ALLOWED_ORIGINS = "https://admin.gk.codes"
      # Note: AUTH_SERVICE_URL and FILES_API_URL must be set via AWS Secrets Manager after deployment
      # These cannot be known at service creation time due to circular dependency
    }
    "public-api" = {
      ENVIRONMENT     = var.environment
      SERVICE_NAME    = "public-api"
      LOG_LEVEL       = "info"
      LOG_FORMAT      = "json"
      DB_HOST         = var.aurora_endpoint
      DB_PORT         = "5432"
      DB_NAME         = "portfolio"
      DB_USER         = "portfolio_public"
      ALLOWED_ORIGINS = "https://gk.codes"
      # Note: FILES_API_URL must be set via AWS Secrets Manager after deployment
      # This cannot be known at service creation time due to circular dependency
    }
    "files-api" = {
      ENVIRONMENT        = var.environment
      SERVICE_NAME       = "files-api"
      LOG_LEVEL          = "info"
      LOG_FORMAT         = "json"
      DB_HOST            = var.aurora_endpoint
      DB_PORT            = "5432"
      DB_NAME            = "portfolio"
      DB_USER            = "portfolio_admin"
      S3_USE_SSL         = "true"
      MAX_FILE_SIZE      = "10485760"
      ALLOWED_FILE_TYPES = "image/jpeg,image/jpg,image/png,image/gif,image/webp,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/msword"
      ALLOWED_ORIGINS    = "https://gk.codes,https://admin.gk.codes"
      # Note: AUTH_SERVICE_URL must be set via AWS Secrets Manager after deployment
      # This cannot be known at service creation time due to circular dependency
    }
    "admin-web" = {
      ENVIRONMENT  = var.environment
      SERVICE_NAME = "admin-web"
      LOG_LEVEL    = "info"
      LOG_FORMAT   = "json"
    }
    "public-web" = {
      ENVIRONMENT  = var.environment
      SERVICE_NAME = "public-web"
      LOG_LEVEL    = "info"
      LOG_FORMAT   = "json"
    }
  }

  # Service-specific secrets from AWS Secrets Manager
  service_secrets = {
    "auth-service" = {
      DB_PASSWORD    = var.secrets_arns["aurora_admin"]
      REDIS_PASSWORD = var.secrets_arns["redis_auth"]
      JWT_SECRET     = var.secrets_arns["jwt_secret"]
    }
    "admin-api" = {
      DB_PASSWORD = var.secrets_arns["aurora_admin"]
    }
    "public-api" = {
      DB_PASSWORD = var.secrets_arns["aurora_public"]
    }
    "files-api" = {
      DB_PASSWORD = var.secrets_arns["aurora_admin"]
    }
    "admin-web"  = {}
    "public-web" = {}
  }
}

# VPC Connector (shared across all services)
resource "aws_apprunner_vpc_connector" "main" {
  vpc_connector_name = "${var.project_name}-${var.environment}-vpc-connector"
  subnets            = var.private_subnet_ids
  security_groups    = [var.app_runner_security_group_id]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-connector"
    }
  )
}

# IAM Role for App Runner
resource "aws_iam_role" "app_runner" {
  for_each = var.services

  name_prefix = "${var.project_name}-${var.environment}-${each.key}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_access" {
  for_each = var.services

  name_prefix = "secrets-access-"
  role        = aws_iam_role.app_runner[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [for arn in var.secrets_arns : arn]
      }
    ]
  })
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "s3_access" {
  for_each = var.services

  name_prefix = "s3-access-"
  role        = aws_iam_role.app_runner[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          for bucket in var.s3_bucket_names : "arn:aws:s3:::${bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          for bucket in var.s3_bucket_names : "arn:aws:s3:::${bucket}"
        ]
      }
    ]
  })
}

# IAM Role for ECR Access (for App Runner to pull images)
resource "aws_iam_role" "ecr_access" {
  name_prefix = "${var.project_name}-${var.environment}-ecr-access-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# App Runner Services
resource "aws_apprunner_service" "main" {
  for_each = var.services

  service_name = "${var.project_name}-${var.environment}-${each.key}"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.ecr_access.arn
    }

    image_repository {
      image_identifier      = "${var.ecr_repository_urls[each.key]}:latest"
      image_repository_type = "ECR"

      image_configuration {
        port = each.value.port

        runtime_environment_variables = local.service_env_vars[each.key]
        runtime_environment_secrets   = local.service_secrets[each.key]
      }
    }

    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu               = each.value.cpu
    memory            = each.value.memory
    instance_role_arn = aws_iam_role.app_runner[each.key].arn
  }

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.main.arn
    }
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = each.value.health_check_path
    interval            = 5
    timeout             = 2
    healthy_threshold   = 1
    unhealthy_threshold = 3
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main[each.key].arn

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-${each.key}"
      Service = each.value.name
    }
  )
}

# Auto Scaling Configuration
resource "aws_apprunner_auto_scaling_configuration_version" "main" {
  for_each = var.services

  auto_scaling_configuration_name = "${var.project_name}-${var.environment}-${each.key}-asg"
  max_concurrency                 = each.value.max_concurrency
  max_size                        = each.value.max_instances
  min_size                        = each.value.min_instances

  tags = var.tags
}
