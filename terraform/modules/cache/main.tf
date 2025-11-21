# Cache Module
# ElastiCache Valkey - Single node for cost optimization
# Valkey is Redis OSS fork, fully compatible but actively maintained

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for ElastiCache Valkey"

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
  # Parse auth token from Secrets Manager
  # Accepts two formats:
  #   1. JSON: {"token": "your-redis-token-here"}
  #   2. Plain text: "your-redis-token-here"
  # If JSON parsing fails, treats entire secret as the token value
  auth_token_data = try(
    jsondecode(data.aws_secretsmanager_secret_version.auth_token.secret_string),
    { token = data.aws_secretsmanager_secret_version.auth_token.secret_string }
  )

  # Extract and validate token exists and is non-empty
  auth_token = coalesce(
    try(local.auth_token_data.token, null),
    ""
  )
}

# Validate token is present
resource "null_resource" "validate_auth_token" {
  lifecycle {
    precondition {
      condition     = local.auth_token != ""
      error_message = "Redis auth token must be non-empty. Check the auth_token_secret_arn secret in Secrets Manager."
    }
  }
}

# Parameter group for Valkey 8.2
resource "aws_elasticache_parameter_group" "main" {
  name        = "${var.project_name}-${var.environment}-valkey82"
  family      = "valkey8"
  description = "Valkey 8.2 parameter group for ${var.project_name}"

  # Session-optimized settings
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  tags = var.tags
}

# ElastiCache Replication Group (single node for cost optimization)
# Using cache.t4g.micro: ~$12/month vs Serverless minimum ~$90/month
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-${var.environment}-valkey"
  description          = "Valkey for ${var.project_name} ${var.environment}"

  # Engine configuration - Valkey is Redis-compatible OSS fork
  engine               = "valkey"
  engine_version       = "8.2"
  node_type            = var.node_type
  parameter_group_name = aws_elasticache_parameter_group.main.name

  # Single node (no replicas) for cost optimization
  # Set num_cache_clusters = 2 for HA in production
  num_cache_clusters = var.num_cache_clusters
  port               = 6379

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.cache_security_group_id]

  # Security - encryption and authentication
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = local.auth_token

  # Maintenance and backups
  maintenance_window         = "sun:03:00-sun:04:00"
  snapshot_window            = "02:00-03:00"
  snapshot_retention_limit   = var.snapshot_retention_days
  auto_minor_version_upgrade = true

  # Apply changes immediately (for portfolio; use false for production)
  apply_immediately = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-valkey"
    }
  )

  depends_on = [null_resource.validate_auth_token]

  lifecycle {
    ignore_changes = [auth_token]
  }
}

# CloudWatch Alarms for ElastiCache
resource "aws_cloudwatch_metric_alarm" "valkey_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-valkey-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "EngineCPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Valkey CPU utilization above 80%"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.id}-001"
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "valkey_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-valkey-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Valkey memory usage above 80%"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.id}-001"
  }

  tags = var.tags
}
