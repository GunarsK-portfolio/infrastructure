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

# CloudWatch Log Groups for App Runner services
resource "aws_cloudwatch_log_group" "app_runner" {
  for_each = var.app_runner_service_arns

  name              = "/aws/apprunner/${var.project_name}-${var.environment}-${each.key}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Aurora CPU
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "Aurora CPU Utilization"
        }
      },
      # Aurora ACU
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "ACUUtilization", { stat = "Average" }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "Aurora ACU Utilization"
        }
      },
      # ElastiCache CPU
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "EngineCPUUtilization", { stat = "Average" }]
          ]
          period = 300
          region = data.aws_region.current.id
          title  = "ElastiCache CPU"
        }
      },
      # CloudFront Requests
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", { stat = "Sum" }]
          ]
          period = 300
          region = "us-east-1"
          title  = "CloudFront Requests"
        }
      },
      # CloudFront Error Rate
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "5xxErrorRate", { stat = "Average" }]
          ]
          period = 300
          region = "us-east-1"
          title  = "CloudFront 5xx Error Rate"
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
