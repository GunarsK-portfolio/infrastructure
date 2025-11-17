# GuardDuty Module Outputs

output "detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "sns_topic_arn" {
  description = "SNS topic ARN for GuardDuty alerts"
  value       = var.enable_guardduty && var.enable_sns_alerts ? aws_sns_topic.guardduty_alerts[0].arn : null
}

output "log_group_name" {
  description = "CloudWatch log group name for GuardDuty findings"
  value       = var.enable_guardduty ? aws_cloudwatch_log_group.guardduty[0].name : null
}
