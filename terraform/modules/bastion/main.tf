# Bastion Module
# SSM-enabled bastion host for database access via port forwarding

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.21"
    }
  }
}

# Get latest Amazon Linux 2023 AMI (standard variant only)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# IAM Role for Bastion
resource "aws_iam_role" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-bastion-role"
    }
  )
}

# Attach SSM managed policy
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Policy for KMS decrypt (required for encrypted EBS root volume)
resource "aws_iam_role_policy" "bastion_kms" {
  name_prefix = "kms-decrypt-"
  role        = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# IAM Policy for CloudWatch Logs (for user-data troubleshooting)
resource "aws_iam_role_policy" "bastion_cloudwatch" {
  name_prefix = "cloudwatch-logs-"
  role        = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/ec2/bastion/${var.project_name}-${var.environment}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  role        = aws_iam_role.bastion.name

  tags = var.tags
}

# Security Group for Bastion
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-sg-"
  description = "Security group for SSM bastion (egress only)"
  vpc_id      = var.vpc_id

  # Allow HTTPS to SSM endpoints and package repositories (443)
  # Note: 0.0.0.0/0 required for SSM service endpoints and dnf repositories
  # TODO: Restrict HTTPS egress to VPC endpoint for SSM service once PrivateLink is configured.
  # Currently uses 0.0.0.0/0 for Session Manager, SSM agent downloads, and dnf repositories.
  # See: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-privatelink.html
  egress {
    description = "HTTPS to SSM endpoints and dnf repos"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow PostgreSQL to Aurora
  egress {
    description     = "PostgreSQL to Aurora"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.database_security_group_id]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-bastion-sg"
    }
  )
}

# Update Aurora security group to allow bastion
resource "aws_security_group_rule" "aurora_from_bastion" {
  type                     = "ingress"
  description              = "PostgreSQL from bastion"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.database_security_group_id
  source_security_group_id = aws_security_group.bastion.id
}

# Bastion Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # Prevent accidental termination in production
  disable_api_termination = var.environment == "prod" ? true : false

  # Enable detailed monitoring
  monitoring = true

  # EBS optimization
  ebs_optimized = true

  # Root volume encryption with customer-managed KMS key
  root_block_device {
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  # Metadata service v2 (IMDSv2) required
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # User data to install PostgreSQL client and CloudWatch agent
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e  # Exit on error

    # Log output
    exec > >(tee /var/log/user-data.log)
    exec 2>&1

    echo "Starting bastion initialization..."

    # Install CloudWatch agent
    dnf install -y amazon-cloudwatch-agent || { echo "CloudWatch agent install failed"; exit 1; }

    # Configure CloudWatch agent to stream user-data logs
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/bastion/${var.project_name}-${var.environment}",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CWCONFIG

    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s || \
      { echo "CloudWatch agent start failed"; exit 1; }

    # Update system
    dnf update -y || { echo "dnf update failed"; exit 1; }

    # Install PostgreSQL 17 client
    dnf install -y postgresql17 || { echo "PostgreSQL install failed"; exit 1; }

    # Verify installation
    psql --version || { echo "PostgreSQL verification failed"; exit 1; }

    echo "Bastion initialization complete"
  EOF
  )

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-bastion"
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}
