# Message Queue Module
# Amazon MQ for RabbitMQ - Single broker

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

# Data source to fetch credentials from Secrets Manager
data "aws_secretsmanager_secret_version" "rabbitmq" {
  secret_id = var.credentials_secret_arn
}

locals {
  # Parse credentials from Secrets Manager (created by secrets module)
  # Expected format: {"username": "...", "password": "..."}
  credentials = try(
    jsondecode(data.aws_secretsmanager_secret_version.rabbitmq.secret_string),
    { username = "", password = "" }
  )
}

# Validate credentials are present
resource "null_resource" "validate_credentials" {
  lifecycle {
    precondition {
      condition     = local.credentials.username != "" && local.credentials.password != ""
      error_message = "RabbitMQ credentials must be non-empty. Check the credentials_secret_arn secret in Secrets Manager."
    }
  }
}

# Amazon MQ Broker for RabbitMQ
resource "aws_mq_broker" "main" {
  broker_name = "${var.project_name}-${var.environment}-rabbitmq"

  engine_type         = "RabbitMQ"
  engine_version      = var.engine_version
  host_instance_type  = var.instance_type
  deployment_mode     = "SINGLE_INSTANCE"
  publicly_accessible = false

  # Authentication
  user {
    username = local.credentials.username
    password = local.credentials.password
  }

  # Network configuration
  subnet_ids      = [var.private_subnet_ids[0]] # Single instance only needs one subnet
  security_groups = [var.mq_security_group_id]

  # Encryption
  encryption_options {
    use_aws_owned_key = false
    kms_key_id        = var.kms_key_arn
  }

  # Maintenance window (Sunday 3-4 AM UTC)
  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "03:00"
    time_zone   = "UTC"
  }

  # Logging
  logs {
    general = true
  }

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rabbitmq"
    }
  )

  depends_on = [null_resource.validate_credentials]
}

# CloudWatch Alarms for Amazon MQ
resource "aws_cloudwatch_metric_alarm" "rabbitmq_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rabbitmq-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "SystemCpuUtilization"
  namespace           = "AWS/AmazonMQ"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RabbitMQ CPU utilization above 80%"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    Broker = aws_mq_broker.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rabbitmq_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-rabbitmq-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RabbitMQMemUsed"
  namespace           = "AWS/AmazonMQ"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RabbitMQ memory usage above 80%"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    Broker = aws_mq_broker.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rabbitmq_queue_depth" {
  alarm_name          = "${var.project_name}-${var.environment}-rabbitmq-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MessageCount"
  namespace           = "AWS/AmazonMQ"
  period              = 300
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "RabbitMQ queue depth exceeds 10 messages - indicates consumer lag or failure"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    Broker = aws_mq_broker.main.id
  }

  tags = var.tags
}
