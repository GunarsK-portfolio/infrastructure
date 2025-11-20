# Main Terraform Configuration
# Orchestrates all infrastructure modules

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    },
    var.additional_tags
  )

  # Account ID will be fetched dynamically
  account_id = data.aws_caller_identity.current.account_id

  # Use first 2 available AZs when using default value
  # If custom AZs provided, validation ensures they match the region
  availability_zones = var.availability_zones == ["eu-west-1a", "eu-west-1b"] ? slice(data.aws_availability_zones.available.names, 0, 2) : var.availability_zones
}

# Data source to get AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones

  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  kms_key_arn          = module.secrets.kms_key_arn # Use secrets KMS key for flow logs

  tags = local.common_tags

  # Ensure KMS key is created before CloudWatch log groups for VPC Flow Logs
  depends_on = [module.secrets]
}

# Secrets Manager Module
# IMPORTANT: This must be created BEFORE database and cache modules
module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# Database Module - Aurora Serverless v2
module "database" {
  source = "./modules/database"

  project_name               = var.project_name
  environment                = var.environment
  private_subnet_ids         = module.networking.private_subnet_ids
  database_security_group_id = module.networking.database_security_group_id

  min_capacity          = var.aurora_min_capacity
  max_capacity          = var.aurora_max_capacity
  engine_version        = var.aurora_engine_version
  backup_retention_days = var.aurora_backup_retention_days

  # Reference secrets from Secrets Manager (no hardcoded passwords)
  master_password_secret_arn = module.secrets.aurora_master_password_arn

  # Use customer-managed KMS key for encryption
  kms_key_arn = module.secrets.kms_key_arn

  enable_enhanced_monitoring  = var.enable_enhanced_monitoring
  enable_performance_insights = var.enable_performance_insights
  enable_http_endpoint        = var.enable_http_endpoint

  tags = local.common_tags
}

# Cache Module - ElastiCache Serverless
module "cache" {
  source = "./modules/cache"

  project_name            = var.project_name
  environment             = var.environment
  private_subnet_ids      = module.networking.private_subnet_ids
  cache_security_group_id = module.networking.cache_security_group_id

  # Reference auth token from Secrets Manager
  auth_token_secret_arn = module.secrets.redis_auth_token_arn

  tags = local.common_tags
}

# Bastion Module - SSM-enabled database access
module "bastion" {
  source = "./modules/bastion"

  project_name  = var.project_name
  environment   = var.environment
  vpc_id        = module.networking.vpc_id
  subnet_id     = module.networking.public_subnet_ids[0]
  instance_type = var.bastion_instance_type

  database_security_group_id = module.networking.database_security_group_id
  kms_key_arn                = module.secrets.kms_key_arn

  tags = local.common_tags
}

# Storage Module - S3 Buckets
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment
  account_id   = local.account_id
  bucket_names = var.s3_buckets

  # Use customer-managed KMS key for encryption
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags
}

# ECR Module - Container Registry
module "ecr" {
  source = "./modules/ecr"

  project_name  = var.project_name
  service_names = keys(var.app_runner_services)

  # Use customer-managed KMS key for encryption
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags
}

# Data source to look up existing Route53 hosted zone
data "aws_route53_zone" "existing" {
  name         = var.domain_name
  private_zone = false
}

# Route53 DNS Module - Use existing Route 53 registrar-created hosted zone
module "dns" {
  source = "./modules/dns"

  domain_name = var.domain_name
  create_zone = false
  zone_id     = data.aws_route53_zone.existing.zone_id

  # KMS encryption for logs
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags
}

# ACM Certificate Module (us-east-1 for CloudFront)
# Note: zone_id reference creates implicit dependency on dns.zone creation
# The dns module's A/AAAA records depend on CloudFront, but zone creation doesn't
module "certificates" {
  source = "./modules/certificates"

  providers = {
    aws = aws.us_east_1
  }

  domain_name = var.domain_name
  zone_id     = module.dns.zone_id

  tags = local.common_tags
}

# WAF Module
module "waf" {
  source = "./modules/waf"

  providers = {
    aws = aws.us_east_1 # WAF for CloudFront must be in us-east-1
  }

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  tags = local.common_tags

  # Ensure KMS key is created before CloudWatch log groups
  depends_on = [module.secrets]
}

# App Runner Module
module "app_runner" {
  source = "./modules/app-runner"

  project_name       = var.project_name
  environment        = var.environment
  services           = var.app_runner_services
  service_image_tags = var.service_image_tags

  # VPC configuration for private resource access and ingress
  vpc_id                       = module.networking.vpc_id
  private_subnet_ids           = module.networking.private_subnet_ids
  app_runner_security_group_id = module.networking.app_runner_security_group_id

  # ECR repository URLs
  ecr_repository_urls = module.ecr.repository_urls

  # Database and cache endpoints (injected via Secrets Manager)
  aurora_endpoint      = module.database.cluster_endpoint
  elasticache_endpoint = module.cache.primary_endpoint

  # S3 bucket names
  s3_bucket_names = module.storage.bucket_names

  # Secrets Manager ARNs
  secrets_arns = module.secrets.secret_arns

  # KMS key for decrypting secrets
  kms_key_arn = module.secrets.kms_key_arn

  # Domain name for service URLs
  domain_name = var.domain_name

  # Observability
  enable_xray_tracing = var.enable_xray_tracing

  tags = local.common_tags
}

# CloudFront CDN Module
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name    = var.project_name
  environment     = var.environment
  domain_name     = var.domain_name
  certificate_arn = module.certificates.certificate_arn

  # App Runner service URLs as origins (without https://)
  app_runner_urls = {
    for key, value in module.app_runner.service_urls :
    key => replace(value, "https://", "")
  }

  # WAF Web ACL ARN for security protection
  web_acl_arn = module.waf.web_acl_arn

  tags = local.common_tags

  # Ensure certificate is validated before creating CloudFront distributions
  depends_on = [module.certificates]
}

# DNS Records Module - Create CloudFront A/AAAA records after distributions exist
module "dns_records" {
  source = "./modules/dns"

  domain_name = var.domain_name
  create_zone = false              # Don't recreate the hosted zone
  zone_id     = module.dns.zone_id # Use existing zone from first module call

  # CloudFront distributions - explicit dependency ensures CloudFront is created first
  cloudfront_distributions = {
    public = module.cloudfront.public_distribution_domain_name
    admin  = module.cloudfront.admin_distribution_domain_name
    auth   = module.cloudfront.auth_distribution_domain_name
    files  = module.cloudfront.files_distribution_domain_name
  }

  # KMS encryption for logs (not needed in records-only mode, but required variable)
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags

  depends_on = [module.cloudfront, module.dns]
}

# Monitoring Module - CloudWatch
module "monitoring" {
  source = "./modules/monitoring"

  project_name       = var.project_name
  environment        = var.environment
  log_retention_days = var.log_retention_days

  # Resources to monitor
  app_runner_service_arns = module.app_runner.service_arns
  cloudfront_distribution_ids = {
    public = module.cloudfront.public_distribution_id
    admin  = module.cloudfront.admin_distribution_id
    auth   = module.cloudfront.auth_distribution_id
    files  = module.cloudfront.files_distribution_id
  }
  waf_web_acl_name          = module.waf.web_acl_name
  db_cluster_id             = module.database.cluster_id
  cache_id                  = module.cache.cache_id
  cache_max_data_storage_gb = var.elasticache_data_storage_gb
  alarm_email_addresses     = var.alarm_email_addresses

  # KMS encryption for logs
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags
}

# CloudTrail Module - API Audit Logging
module "cloudtrail" {
  source = "./modules/cloudtrail"

  project_name = var.project_name
  environment  = var.environment
  account_id   = local.account_id

  cloudtrail_log_retention_days = var.cloudtrail_log_retention_days
  enable_cloudtrail_alarms      = var.enable_cloudtrail_alarms
  sns_topic_arn                 = module.monitoring.sns_topic_arn

  # Use same customer-managed KMS key as other resources
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags

  # Ensure KMS key is created before CloudWatch log groups
  depends_on = [module.secrets]
}

# GuardDuty Module - Threat Detection
module "guardduty" {
  source = "./modules/guardduty"

  project_name = var.project_name
  environment  = var.environment

  enable_guardduty = var.enable_guardduty

  # KMS encryption for logs
  kms_key_arn = module.secrets.kms_key_arn

  tags = local.common_tags

  # Ensure KMS key is created before CloudWatch log groups
  depends_on = [module.secrets]
}

# Budgets Module - Cost Control
module "budgets" {
  count  = var.enable_budgets && length(var.budget_alert_emails) > 0 ? 1 : 0
  source = "./modules/budgets"

  project_name         = var.project_name
  environment          = var.environment
  enable_budgets       = var.enable_budgets
  monthly_budget_limit = var.monthly_budget_limit
  alert_emails         = var.budget_alert_emails
}
