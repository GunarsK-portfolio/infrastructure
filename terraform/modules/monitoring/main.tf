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

# SNS Topic for alarms
resource "aws_sns_topic" "alarms" {
  name_prefix       = "${var.project_name}-${var.environment}-alarms-"
  kms_master_key_id = "alias/aws/sns"

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

# CloudWatch Log Groups for App Runner services
resource "aws_cloudwatch_log_group" "app_runner" {
  for_each = var.app_runner_service_arns

  name              = "/aws/apprunner/${var.project_name}-${var.environment}-${each.key}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Dashboard - Optimized for cost (9 widgets = $18/month)
# Consolidates per-service metrics into combined views
# Detailed per-service monitoring via alarms (no cost)
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: App Runner - All Services Error Rates (4xx + 5xx)
      {
        type = "metric"
        properties = {
          metrics = concat(
            [
              for service_name, _ in var.app_runner_service_arns :
              ["AWS/AppRunner", "4xxStatusResponses", {
                stat       = "Average"
                label      = "${service_name} 4xx"
                dimensions = { ServiceName = "${var.project_name}-${var.environment}-${service_name}" }
              }]
            ],
            [
              for service_name, _ in var.app_runner_service_arns :
              ["AWS/AppRunner", "5xxStatusResponses", {
                stat       = "Average"
                label      = "${service_name} 5xx"
                dimensions = { ServiceName = "${var.project_name}-${var.environment}-${service_name}" }
              }]
            ]
          )
          period = 300
          region = data.aws_region.current.id
          title  = "App Runner - All Services Error Rates"
          yAxis = {
            left = {
              label = "Error Rate %"
              min   = 0
            }
          }
        }
      },
      # Widget 2: App Runner - All Services Latency (p99)
      {
        type = "metric"
        properties = {
          metrics = [
            for service_name, _ in var.app_runner_service_arns :
            ["AWS/AppRunner", "RequestLatency", {
              stat       = "p99"
              label      = service_name
              dimensions = { ServiceName = "${var.project_name}-${var.environment}-${service_name}" }
            }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "App Runner - p99 Latency (All Services)"
          yAxis = {
            left = {
              label = "Latency (seconds)"
              min   = 0
            }
          }
        }
      },
      # Widget 3: App Runner - All Services Request Count
      {
        type = "metric"
        properties = {
          metrics = [
            for service_name, _ in var.app_runner_service_arns :
            ["AWS/AppRunner", "Requests", {
              stat       = "Sum"
              label      = service_name
              dimensions = { ServiceName = "${var.project_name}-${var.environment}-${service_name}" }
            }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "App Runner - Request Count (All Services)"
          yAxis = {
            left = {
              label = "Requests"
              min   = 0
            }
          }
        }
      },
      # Widget 4: Aurora - ACU Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "ACUUtilization", { stat = "Average", label = "ACU Utilization", dimensions = { DBClusterIdentifier = var.db_cluster_id } }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "Aurora ACU Utilization"
          yAxis = {
            left = {
              label = "Utilization %"
              min   = 0
              max   = 100
            }
          }
        }
      },
      # Widget 5: Aurora - Database Connections
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Average", label = "Connections", dimensions = { DBClusterIdentifier = var.db_cluster_id } }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "Aurora Database Connections"
          yAxis = {
            left = {
              label = "Connections"
              min   = 0
            }
          }
        }
      },
      # Widget 6: ElastiCache - Memory Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "BytesUsedForCache", { stat = "Average", label = "Memory Used" }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "ElastiCache Memory Utilization"
          yAxis = {
            left = {
              label = "Bytes"
              min   = 0
            }
          }
        }
      },
      # Widget 7: ElastiCache - Evictions
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "Evictions", { stat = "Sum", label = "Evictions" }]
          ]
          period = 60
          region = data.aws_region.current.id
          title  = "ElastiCache Evictions"
          yAxis = {
            left = {
              label = "Evictions"
              min   = 0
            }
          }
        }
      },
      # Widget 8: CloudFront - Total Requests (All Distributions)
      {
        type = "metric"
        properties = {
          metrics = [
            for dist_name, dist_id in var.cloudfront_distribution_ids :
            ["AWS/CloudFront", "Requests", {
              stat       = "Sum"
              label      = dist_name
              dimensions = { DistributionId = dist_id, Region = "Global" }
            }]
          ]
          period = 300
          region = "us-east-1"
          title  = "CloudFront - Requests (All Distributions)"
          yAxis = {
            left = {
              label = "Requests"
              min   = 0
            }
          }
        }
      },
      # Widget 9: CloudFront - 5xx Error Rate (All Distributions)
      {
        type = "metric"
        properties = {
          metrics = [
            for dist_name, dist_id in var.cloudfront_distribution_ids :
            ["AWS/CloudFront", "5xxErrorRate", {
              stat       = "Average"
              label      = dist_name
              dimensions = { DistributionId = dist_id, Region = "Global" }
            }]
          ]
          period = 300
          region = "us-east-1"
          title  = "CloudFront - 5xx Error Rate (All Distributions)"
          yAxis = {
            left = {
              label = "Error Rate %"
              min   = 0
            }
          }
        }
      }
    ]
  })
}

# Data source for current region
data "aws_region" "current" {}

# CloudWatch Alarm: CloudFront 5xx errors
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

# CloudWatch Alarm: WAF high block rate (potential attack)
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
    Region = "us-east-1" # WAF for CloudFront must be in us-east-1
  }

  tags = var.tags
}

# App Runner Alarms - 4xx Error Rate
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

  dimensions = {
    ServiceName = "${var.project_name}-${var.environment}-${each.key}"
  }

  tags = var.tags
}

# App Runner Alarms - 5xx Error Rate
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

  dimensions = {
    ServiceName = "${var.project_name}-${var.environment}-${each.key}"
  }

  tags = var.tags
}

# App Runner Alarms - Request Latency (p99)
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

  dimensions = {
    ServiceName = "${var.project_name}-${var.environment}-${each.key}"
  }

  tags = var.tags
}

# App Runner Alarms - Low Request Count (service down detection)
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

  dimensions = {
    ServiceName = "${var.project_name}-${var.environment}-${each.key}"
  }

  tags = var.tags
}

# Aurora Alarm - Database Connections
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

  dimensions = {
    DBClusterIdentifier = var.db_cluster_id
  }

  tags = var.tags
}

# ElastiCache Alarm - Memory Utilization
resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  for_each = var.enable_cache_alarms ? toset(["enabled"]) : toset([])

  alarm_name          = "${var.project_name}-${var.environment}-elasticache-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.cache_memory_threshold
  alarm_description   = "ElastiCache memory utilization above ${var.cache_memory_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  # Use metric math to calculate percentage from BytesUsedForCache
  # Convert max_data_storage_gb (GB) to bytes: GB * 1024^3
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
      dimensions = {
        CacheClusterId = var.cache_id
      }
    }
    return_data = false
  }

  tags = var.tags
}

# ElastiCache Alarm - Evictions
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

  dimensions = {
    CacheClusterId = var.cache_id
  }

  tags = var.tags
}
