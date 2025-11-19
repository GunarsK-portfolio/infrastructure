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

# DB Cluster Parameter Group for PostgreSQL extensions
resource "aws_rds_cluster_parameter_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-aurora-pg-"
  family      = "aurora-postgresql17"
  description = "Custom parameter group for Aurora PostgreSQL 17 with extensions"

  # Enable pg_cron, pg_partman, and pgaudit extensions
  # pgaudit provides advanced database audit logging capabilities
  # NOTE: shared_preload_libraries is a static parameter requiring restart
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_cron,pgaudit"
    apply_method = "pending-reboot"
  }

  # Force replacement when static parameters change (can't modify in-place)
  lifecycle {
    create_before_destroy = true
  }

  # pgaudit configuration
  # Log all DDL, DCL, and security-relevant operations
  # Options: READ, WRITE, FUNCTION, ROLE, DDL, MISC, MISC_SET, ALL
  parameter {
    name         = "pgaudit.log"
    value        = "ddl,role"
    apply_method = "pending-reboot"
  }

  # Log catalog queries (system table access) for security monitoring
  parameter {
    name         = "pgaudit.log_catalog"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Log full parameter values in audit logs
  parameter {
    name         = "pgaudit.log_parameter"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Include statement text in audit logs
  parameter {
    name         = "pgaudit.log_statement_once"
    value        = "0"
    apply_method = "pending-reboot"
  }

  # pg_cron configuration
  parameter {
    name         = "cron.database_name"
    value        = var.database_name
    apply_method = "pending-reboot"
  }

  # pg_stat_statements configuration
  parameter {
    name         = "pg_stat_statements.track"
    value        = "all"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "pg_stat_statements.max"
    value        = "10000"
    apply_method = "pending-reboot"
  }

  # Connection pooling limits
  # Set max_connections based on Aurora Serverless v2 ACU capacity
  # Formula: LEAST({DBInstanceClassMemory/9531392}, 5000)
  # For 0.5-16 ACU range: ~87-2782 connections
  # Set conservative limit to prevent connection exhaustion
  parameter {
    name         = "max_connections"
    value        = var.max_connections
    apply_method = "pending-reboot"
  }

  # Security: TLS/SSL enforcement
  # Force all connections to use SSL/TLS encryption
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Audit logging: Connection events
  # Log all connection attempts and disconnections for security auditing
  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Audit logging: SQL statement logging
  # Log all DDL statements (CREATE, ALTER, DROP) for compliance
  # Options: none, ddl, mod (INSERT/UPDATE/DELETE), all
  # Use 'ddl' for production to reduce log volume while maintaining security audit trail
  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "pending-reboot"
  }

  # Audit logging: Query duration
  # Log query execution time for performance monitoring
  parameter {
    name         = "log_duration"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Audit logging: Slow query threshold
  # Log queries taking longer than 1000ms (1 second)
  parameter {
    name         = "log_min_duration_statement"
    value        = "1000"
    apply_method = "pending-reboot"
  }

  # Query timeout protection
  # Terminate queries running longer than 5 minutes (300000ms)
  # Prevents long-running queries from exhausting database resources
  parameter {
    name         = "statement_timeout"
    value        = "300000"
    apply_method = "pending-reboot"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-parameter-group"
    }
  )
}

# Data source to fetch master password from Secrets Manager
data "aws_secretsmanager_secret_version" "master_password" {
  secret_id = var.master_password_secret_arn
}

locals {
  # Parse database credentials from Secrets Manager
  # Expected JSON format: {"username": "admin_user", "password": "secure_password"}
  # Mark as sensitive to prevent exposure in Terraform state and logs
  master_credentials = sensitive(jsondecode(data.aws_secretsmanager_secret_version.master_password.secret_string))

  # Performance Insights KMS key (used across cluster and instances)
  performance_insights_kms_key = var.kms_key_arn
}

# Validate username is present and non-empty
resource "null_resource" "validate_username" {
  lifecycle {
    precondition {
      condition     = can(local.master_credentials.username) && local.master_credentials.username != ""
      error_message = "Database username must be non-empty. Check the master_password_secret_arn secret in Secrets Manager."
    }
  }
}

# Validate password is present and non-empty
resource "null_resource" "validate_password" {
  lifecycle {
    precondition {
      condition     = can(local.master_credentials.password) && local.master_credentials.password != ""
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
  master_username    = local.master_credentials.username
  master_password    = local.master_credentials.password

  db_subnet_group_name            = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  vpc_security_group_ids          = [var.database_security_group_id]

  # Backup configuration
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # IAM Database Authentication (recommended for production)
  # Provides centralized access management and eliminates long-lived credentials
  iam_database_authentication_enabled = true

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Deletion protection enabled for all environments
  deletion_protection       = true
  skip_final_snapshot       = var.environment == "dev"
  final_snapshot_identifier = var.environment != "dev" ? "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Performance Insights
  # Retention increased to 31 days for better trend analysis and troubleshooting
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = local.performance_insights_kms_key
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention_days : null

  # Point-in-time recovery
  enable_http_endpoint = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-cluster"
    }
  )

  depends_on = [
    null_resource.validate_username,
    null_resource.validate_password
  ]

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
  performance_insights_kms_key_id = local.performance_insights_kms_key

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
