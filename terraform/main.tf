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
  tags               = local.common_tags
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

  enable_enhanced_monitoring  = var.enable_enhanced_monitoring
  enable_performance_insights = var.enable_performance_insights

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

# Storage Module - S3 Buckets
module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment
  account_id   = local.account_id
  bucket_names = var.s3_buckets

  tags = local.common_tags
}

# ECR Module - Container Registry
module "ecr" {
  source = "./modules/ecr"

  project_name             = var.project_name
  service_names            = keys(var.app_runner_services)
  enable_enhanced_scanning = var.enable_ecr_enhanced_scanning

  tags = local.common_tags
}

# ACM Certificate Module (us-east-1 for CloudFront)
module "certificates" {
  source = "./modules/certificates"

  providers = {
    aws = aws.us_east_1
  }

  domain_name = var.domain_name
  zone_id     = module.dns.zone_id

  tags = local.common_tags
}

# Route53 DNS Module
module "dns" {
  source = "./modules/dns"

  domain_name            = var.domain_name
  admin_domain_name      = var.admin_domain_name
  cloudfront_domain_name = module.cdn.distribution_domain_name
  cloudfront_zone_id     = module.cdn.distribution_zone_id

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
  enable_waf   = var.enable_waf

  tags = local.common_tags
}

# CloudFront CDN Module
module "cdn" {
  source = "./modules/cdn"

  project_name      = var.project_name
  environment       = var.environment
  domain_name       = var.domain_name
  admin_domain_name = var.admin_domain_name
  certificate_arn   = module.certificates.certificate_arn
  waf_web_acl_id    = module.waf.web_acl_id

  # App Runner service URLs as origins
  app_runner_service_urls = module.app_runner.service_urls

  tags = local.common_tags
}

# App Runner Module
module "app_runner" {
  source = "./modules/app-runner"

  project_name = var.project_name
  environment  = var.environment
  services     = var.app_runner_services

  # VPC connector for private resource access
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

  tags = local.common_tags
}

# Monitoring Module - CloudWatch
module "monitoring" {
  source = "./modules/monitoring"

  project_name       = var.project_name
  environment        = var.environment
  log_retention_days = var.log_retention_days

  # Resources to monitor
  app_runner_service_arns    = module.app_runner.service_arns
  cloudfront_distribution_id = module.cdn.distribution_id

  tags = local.common_tags
}
