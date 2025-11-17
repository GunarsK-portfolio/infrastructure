# Cache Module
# ElastiCache Serverless for Redis

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for ElastiCache Serverless Redis"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-subnet-group"
    }
  )
}

# Data source to fetch auth token from Secrets Manager
data "aws_secretsmanager_secret_version" "auth_token" {
  secret_id = var.auth_token_secret_arn
}

locals {
  # Try to parse JSON, fallback to treating as plain string
  auth_token_data = try(
    jsondecode(data.aws_secretsmanager_secret_version.auth_token.secret_string),
    { password = data.aws_secretsmanager_secret_version.auth_token.secret_string }
  )
}

# ElastiCache Serverless Cache
resource "aws_elasticache_serverless_cache" "main" {
  name        = "${var.project_name}-${var.environment}-redis"
  description = "ElastiCache Serverless for Redis"
  engine      = "redis"

  # Security configuration
  security_group_ids = [var.cache_security_group_id]
  subnet_ids         = var.private_subnet_ids

  # Cache configuration
  cache_usage_limits {
    data_storage {
      maximum = var.max_data_storage_gb
      unit    = "GB"
    }

    ecpu_per_second {
      maximum = var.max_ecpu_per_second
    }
  }

  # Encryption and authentication
  # Note: ElastiCache Serverless automatically encrypts data at rest
  # TLS is required for all connections
  user_group_id = aws_elasticache_user_group.main.id

  # Daily snapshot time
  daily_snapshot_time = "03:00"

  # Maintenance window
  # Format: ddd:hh24:mi-ddd:hh24:mi
  snapshot_retention_limit = var.snapshot_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-serverless"
    }
  )
}

# Redis User (for authentication with restricted commands for security)
resource "aws_elasticache_user" "main" {
  user_id   = "${var.project_name}-${var.environment}-redis-user"
  user_name = "default"
  # Restrict to safe commands only (no dangerous commands like FLUSHALL, CONFIG, SHUTDOWN)
  access_string = "on ~* &* +@read +@write +@list +@set +@hash +@sortedset +@string +@connection +@keyspace -@dangerous"
  engine        = "redis"

  authentication_mode {
    type      = "password"
    passwords = [local.auth_token_data.token]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [authentication_mode]
  }
}

# Redis User Group
resource "aws_elasticache_user_group" "main" {
  user_group_id = "${var.project_name}-${var.environment}-redis-ug"
  engine        = "redis"
  user_ids      = [aws_elasticache_user.main.user_id]

  tags = var.tags
}

# CloudWatch Alarms for ElastiCache
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "EngineCPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis CPU utilization above 80%"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    CacheClusterId = aws_elasticache_serverless_cache.main.name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_throttled_commands" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-throttled-commands"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ThrottledCmds"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Redis throttled commands above threshold"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    CacheClusterId = aws_elasticache_serverless_cache.main.name
  }

  tags = var.tags
}
