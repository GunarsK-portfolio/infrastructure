# Message Queue Module Outputs

output "broker_id" {
  description = "Amazon MQ broker ID"
  value       = aws_mq_broker.main.id
}

output "broker_arn" {
  description = "Amazon MQ broker ARN"
  value       = aws_mq_broker.main.arn
}

output "amqp_endpoint" {
  description = "AMQP endpoint for RabbitMQ connections"
  value       = aws_mq_broker.main.instances[0].endpoints[0]
  sensitive   = true
}

output "console_url" {
  description = "RabbitMQ management console URL"
  value       = aws_mq_broker.main.instances[0].console_url
  sensitive   = true
}
