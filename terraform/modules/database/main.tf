# Database Module
# Aurora Serverless v2 PostgreSQL cluster

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

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-aurora-"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for Aurora Serverless v2"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-subnet-group"
    }
  )
}

# Data source to fetch master password from Secrets Manager
data "aws_secretsmanager_secret_version" "master_password" {
  secret_id = var.master_password_secret_arn
}

locals {
  master_credentials = jsondecode(data.aws_secretsmanager_secret_version.master_password.secret_string)

  # Validate credentials exist and are non-empty
  username = coalesce(try(local.master_credentials.username, null), "")
  password = coalesce(try(local.master_credentials.password, null), "")
}

# Validate username is present
resource "null_resource" "validate_username" {
  lifecycle {
    precondition {
      condition     = local.username != ""
      error_message = "Database username must be non-empty. Check the master_password_secret_arn secret in Secrets Manager."
    }
  }
}

# Validate password is present
resource "null_resource" "validate_password" {
  lifecycle {
    precondition {
      condition     = local.password != ""
      error_message = "Database password must be non-empty. Check the master_password_secret_arn secret in Secrets Manager."
    }
  }
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project_name}-${var.environment}-aurora"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = local.username
  master_password    = local.password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_security_group_id]

  # Backup configuration
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Deletion protection for production and staging (dev only allows easier teardown)
  deletion_protection       = var.environment != "dev"
  skip_final_snapshot       = var.environment == "dev"
  final_snapshot_identifier = var.environment != "dev" ? "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Performance Insights
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = var.enable_performance_insights ? var.kms_key_id : null
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  # Point-in-time recovery
  enable_http_endpoint = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-cluster"
    }
  )

  lifecycle {
    ignore_changes = [master_password]
  }
}

# Aurora Serverless v2 Instance (Writer)
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.project_name}-${var.environment}-aurora-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  # Performance Insights
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_id : null

  # Enhanced Monitoring
  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.enhanced_monitoring[0].arn : null

  publicly_accessible = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-writer"
      Role = "writer"
    }
  )
}

# Aurora Serverless v2 Instance (Reader)
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.project_name}-${var.environment}-aurora-reader"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  # Performance Insights
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_kms_key_id = var.enable_performance_insights ? var.kms_key_id : null

  # Enhanced Monitoring
  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.enhanced_monitoring[0].arn : null

  publicly_accessible = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-reader"
      Role = "reader"
    }
  )
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "enhanced_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-aurora-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms for Aurora
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU utilization above 80%"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 400 # Adjust based on ACU capacity
  alarm_description   = "Aurora database connections above threshold"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "aurora_acu_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-high-acu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ACUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora ACU utilization above 80%"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.id
  }

  tags = var.tags
}
