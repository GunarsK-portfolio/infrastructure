# GuardDuty Module
# AWS threat detection service for monitoring malicious activity

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# Enable GuardDuty
resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency

  tags = var.tags
}

# Enable S3 Protection feature
resource "aws_guardduty_detector_feature" "s3_protection" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# CloudWatch Log Group for GuardDuty findings
resource "aws_cloudwatch_log_group" "guardduty" {
  count = var.enable_guardduty ? 1 : 0

  name              = "/aws/guardduty/${var.project_name}-${var.environment}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# SNS Topic for GuardDuty alerts
resource "aws_sns_topic" "guardduty_alerts" {
  count = var.enable_guardduty && var.enable_sns_alerts ? 1 : 0

  name = "${var.project_name}-${var.environment}-guardduty-alerts"

  tags = var.tags
}

# EventBridge rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = var.enable_guardduty ? 1 : 0

  name        = "${var.project_name}-${var.environment}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = var.alert_severity_levels
    }
  })

  tags = var.tags
}

# EventBridge target for CloudWatch Logs
resource "aws_cloudwatch_event_target" "guardduty_to_cloudwatch" {
  count = var.enable_guardduty ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToCloudWatchLogs"
  arn       = aws_cloudwatch_log_group.guardduty[0].arn
}

# EventBridge target for SNS (if enabled)
resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  count = var.enable_guardduty && var.enable_sns_alerts ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_alerts[0].arn
}

# CloudWatch Metric Alarm for high severity findings
resource "aws_cloudwatch_metric_alarm" "guardduty_high_severity" {
  count = var.enable_guardduty ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-guardduty-high-severity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HighSeverityFindings"
  namespace           = "AWS/GuardDuty"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert on any high severity GuardDuty findings"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.enable_sns_alerts ? [aws_sns_topic.guardduty_alerts[0].arn] : []

  tags = var.tags
}
