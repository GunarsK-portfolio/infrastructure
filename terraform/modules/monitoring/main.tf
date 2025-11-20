# Monitoring Module
# CloudWatch logs, alarms, and dashboards

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# -------------------------------
# SNS Topic for alarms
# -------------------------------
resource "aws_sns_topic" "alarms" {
  name_prefix       = "${var.project_name}-${var.environment}-alarms-"
  kms_master_key_id = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alarms"
    }
  )
}

# SNS Email Subscriptions for alarms
resource "aws_sns_topic_subscription" "alarm_emails" {
  for_each = toset(var.alarm_email_addresses)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

# -------------------------------
# CloudWatch Log Groups for App Runner
# -------------------------------
resource "aws_cloudwatch_log_group" "app_runner" {
  for_each = var.app_runner_service_arns

  name              = "/aws/apprunner/${var.project_name}-${var.environment}-${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# -------------------------------
# Data source for current region
# -------------------------------
data "aws_region" "current" {}

# -------------------------------
# CloudWatch Dashboard
# -------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: App Runner - All Services Error Rates (4xx + 5xx)
      {
        type = "metric"
        properties = {
          metrics = flatten([
            for service_name, _ in var.app_runner_service_arns : [
              ["AWS/AppRunner", "4xxStatusResponses", "ServiceName", "${var.project_name}-${var.environment}-${service_name}", { stat = "Average", label = "${service_name} 4xx" }],
              ["AWS/AppRunner", "5xxStatusResponses", "ServiceName", "${var.project_name}-${var.environment}-${service_name}", { stat = "Average", label = "${service_name} 5xx" }]
            ]
          ])
          period = 300
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "App Runner - All Services Error Rates"
          yAxis  = { left = { label = "Error Rate %", min = 0 } }
        }
      },
      # Widget 2: App Runner - All Services Latency (p99)
      {
        type = "metric"
        properties = {
          metrics = flatten([
            for service_name, _ in var.app_runner_service_arns : [
              ["AWS/AppRunner", "RequestLatency", "ServiceName", "${var.project_name}-${var.environment}-${service_name}", { stat = "p99", label = service_name }]
            ]
          ])
          period = 300
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "App Runner - p99 Latency (All Services)"
          yAxis  = { left = { label = "Latency (seconds)", min = 0 } }
        }
      },
      # Widget 3: App Runner - All Services Request Count
      {
        type = "metric"
        properties = {
          metrics = flatten([
            for service_name, _ in var.app_runner_service_arns : [
              ["AWS/AppRunner", "Requests", "ServiceName", "${var.project_name}-${var.environment}-${service_name}", { stat = "Sum", label = service_name }]
            ]
          ])
          period = 300
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "App Runner - Request Count (All Services)"
          yAxis  = { left = { label = "Requests", min = 0 } }
        }
      },
      # Widget 4: Aurora - ACU Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "ACUUtilization", "DBClusterIdentifier", var.db_cluster_id, { stat = "Average", label = "ACU Utilization" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "Aurora ACU Utilization"
          yAxis  = { left = { label = "Utilization %", min = 0, max = 100 } }
        }
      },
      # Widget 5: Aurora - Database Connections
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.db_cluster_id, { stat = "Average", label = "Connections" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "Aurora Database Connections"
          yAxis  = { left = { label = "Connections", min = 0 } }
        }
      },
      # Widget 6: ElastiCache - Memory Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "BytesUsedForCache", "CacheClusterId", var.cache_id, { stat = "Average", label = "Memory Used" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "ElastiCache Memory Utilization"
          yAxis  = { left = { label = "Bytes", min = 0 } }
        }
      },
      # Widget 7: ElastiCache - Evictions
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "Evictions", "CacheClusterId", var.cache_id, { stat = "Sum", label = "Evictions" }]
          ]
          period = 60
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "ElastiCache Evictions"
          yAxis  = { left = { label = "Evictions", min = 0 } }
        }
      },
      # Widget 8: CloudFront - Total Requests (All Distributions)
      {
        type = "metric"
        properties = {
          metrics = flatten([
            for dist_name, dist_id in var.cloudfront_distribution_ids : [
              ["AWS/CloudFront", "Requests", "DistributionId", dist_id, "Region", "Global", { stat = "Sum", label = dist_name }]
            ]
          ])
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "CloudFront - Requests (All Distributions)"
          yAxis  = { left = { label = "Requests", min = 0 } }
        }
      },
      # Widget 9: CloudFront - 5xx Error Rate (All Distributions)
      {
        type = "metric"
        properties = {
          metrics = flatten([
            for dist_name, dist_id in var.cloudfront_distribution_ids : [
              ["AWS/CloudFront", "5xxErrorRate", "DistributionId", dist_id, "Region", "Global", { stat = "Average", label = dist_name }]
            ]
          ])
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "CloudFront - 5xx Error Rate (All Distributions)"
          yAxis  = { left = { label = "Error Rate %", min = 0 } }
        }
      }
    ]
  })
}

# -------------------------------
# CloudWatch Alarms
# -------------------------------

# CloudFront 5xx errors
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  for_each = var.cloudfront_distribution_ids

  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-${each.key}-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "CloudFront ${each.key} 5xx error rate above 5%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DistributionId = each.value
    Region         = "Global"
  }

  tags = var.tags
}

# WAF high block rate (potential attack)
resource "aws_cloudwatch_metric_alarm" "waf_high_blocks" {
  for_each = var.enable_waf_alarms ? toset(["enabled"]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-waf-high-blocks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "WAF blocked more than 100 requests in 5 minutes - potential attack"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    Rule   = "ALL"
    WebACL = var.waf_web_acl_name
    Region = "us-east-1"
  }

  tags = var.tags
}

# App Runner 4xx
resource "aws_cloudwatch_metric_alarm" "app_runner_4xx" {
  for_each = var.app_runner_service_arns

  alarm_name          = "${var.project_name}-${var.environment}-apprunner-${each.key}-4xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxStatusResponses"
  namespace           = "AWS/AppRunner"
  period              = 300
  statistic           = "Average"
  threshold           = var.app_runner_4xx_threshold
  alarm_description   = "App Runner ${each.key} 4xx error rate above ${var.app_runner_4xx_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { ServiceName = "${var.project_name}-${var.environment}-${each.key}" }
  tags       = var.tags
}

# App Runner 5xx
resource "aws_cloudwatch_metric_alarm" "app_runner_5xx" {
  for_each = var.app_runner_service_arns

  alarm_name          = "${var.project_name}-${var.environment}-apprunner-${each.key}-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxStatusResponses"
  namespace           = "AWS/AppRunner"
  period              = 300
  statistic           = "Average"
  threshold           = var.app_runner_5xx_threshold
  alarm_description   = "App Runner ${each.key} 5xx error rate above ${var.app_runner_5xx_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { ServiceName = "${var.project_name}-${var.environment}-${each.key}" }
  tags       = var.tags
}

# App Runner p99 latency
resource "aws_cloudwatch_metric_alarm" "app_runner_latency" {
  for_each = var.app_runner_service_arns

  alarm_name          = "${var.project_name}-${var.environment}-apprunner-${each.key}-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestLatency"
  namespace           = "AWS/AppRunner"
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.app_runner_latency_threshold
  alarm_description   = "App Runner ${each.key} p99 latency above ${var.app_runner_latency_threshold}s"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { ServiceName = "${var.project_name}-${var.environment}-${each.key}" }
  tags       = var.tags
}

# App Runner low requests
resource "aws_cloudwatch_metric_alarm" "app_runner_low_requests" {
  for_each = var.app_runner_service_arns

  alarm_name          = "${var.project_name}-${var.environment}-apprunner-${each.key}-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Requests"
  namespace           = "AWS/AppRunner"
  period              = 300
  statistic           = "Sum"
  threshold           = var.app_runner_request_count_threshold
  alarm_description   = "App Runner ${each.key} received less than ${var.app_runner_request_count_threshold} requests in 5 min - service may be down"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "breaching"

  dimensions = { ServiceName = "${var.project_name}-${var.environment}-${each.key}" }
  tags       = var.tags
}

# Aurora Database Connections
resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  for_each = var.enable_db_alarms ? toset(["enabled"]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-aurora-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.db_connection_threshold
  alarm_description   = "Aurora database connections above ${var.db_connection_threshold} - approaching connection limit"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { DBClusterIdentifier = var.db_cluster_id }
  tags       = var.tags
}

# ElastiCache memory utilization
resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  for_each = var.enable_cache_alarms ? toset(["enabled"]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.cache_memory_threshold
  alarm_description   = "ElastiCache memory utilization above ${var.cache_memory_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  metric_query {
    id          = "memory_percent"
    expression  = "(m1 / ${var.cache_max_data_storage_gb * 1073741824}) * 100"
    label       = "Memory Utilization %"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "BytesUsedForCache"
      namespace   = "AWS/ElastiCache"
      period      = 300
      stat        = "Average"
      dimensions  = { CacheClusterId = var.cache_id }
    }
    return_data = false
  }

  tags = var.tags
}

# ElastiCache evictions
resource "aws_cloudwatch_metric_alarm" "elasticache_evictions" {
  for_each = var.enable_cache_alarms ? toset(["enabled"]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = 60
  statistic           = "Sum"
  threshold           = var.cache_evictions_threshold
  alarm_description   = "ElastiCache evictions above ${var.cache_evictions_threshold} per minute - memory pressure"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { CacheClusterId = var.cache_id }
  tags       = var.tags
}
