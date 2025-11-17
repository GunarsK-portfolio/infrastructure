# Terraform Infrastructure

AWS serverless infrastructure deployed in eu-west-1 (Ireland).

## Architecture

### Compute

- AWS App Runner: 6 services (auth, admin-api, public-api, files-api, webs)
- Auto-scaling: 1-10 instances per service
- Instance config: 1 vCPU, 2 GB RAM
- VPC connector for private resource access

### Database

- Aurora Serverless v2 PostgreSQL 15+
- Scaling: 1-16 ACU (configurable)
- Multi-AZ deployment
- Encryption: KMS at rest, TLS in transit
- Backups: 7-day retention, automated snapshots

### Cache

- ElastiCache Serverless Redis 7.x
- Dual endpoints: write (6379), read (6380)
- Cluster mode enabled
- Encryption at rest and in transit

### Storage

- S3 buckets: images, documents, miniatures
- Versioning enabled
- Lifecycle policies: transition to Standard-IA (30d), Glacier (90d)
- Block public access enforced

### CDN & Security

- CloudFront distribution with path-based routing
- WAF: rate limiting, AWS Managed Rules (Core, Known Bad Inputs)
- ACM certificates: *.gk.codes (us-east-1)
- Route53: DNS hosting, CAA records

### Monitoring

- CloudWatch: log groups per service, 7-day retention
- Alarms: error rates, latency, resource utilization
- SNS notifications for critical events
- Dashboard: unified metrics view

### Secrets & Registry

- Secrets Manager: database passwords, Redis auth, JWT secret
- KMS encryption for secrets
- ECR: 6 repositories with enhanced scanning
- Lifecycle policy: keep last 10 images

## Module Structure

```text
modules/
├── networking/     VPC, subnets (2 public, 2 private), security groups
├── secrets/        Secrets Manager with KMS encryption
├── database/       Aurora Serverless v2, subnet groups, security groups
├── cache/          ElastiCache Serverless, subnet groups
├── storage/        S3 buckets with versioning and lifecycle policies
├── ecr/            Container registries with image scanning
├── certificates/   ACM certificates (us-east-1 for CloudFront)
├── dns/            Route53 hosted zone and records
├── waf/            WAF Web ACL with rate limiting rules
├── cdn/            CloudFront distribution with origins and behaviors
├── app-runner/     6 App Runner services with VPC connector
└── monitoring/     CloudWatch log groups, alarms, dashboard, SNS topic
```

## Configuration

### Backend Setup (One-Time)

State stored in S3 with DynamoDB locking:

```bash
aws s3 mb s3://portfolio-terraform-state-prod --region eu-west-1

aws s3api put-bucket-versioning \
  --bucket portfolio-terraform-state-prod \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket portfolio-terraform-state-prod \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

aws dynamodb create-table \
  --table-name portfolio-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1
```

### Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored) and configure:

```hcl
aws_region              = "eu-west-1"
environment             = "prod"
project_name            = "portfolio"
domain_name             = "gk.codes"
admin_domain_name       = "admin.gk.codes"
aurora_min_capacity     = 1
aurora_max_capacity     = 16
enable_enhanced_monitoring    = true
enable_performance_insights   = true
enable_ecr_enhanced_scanning  = true
enable_waf                    = true
```

## Deployment

### Local

```bash
terraform init
terraform plan
terraform apply
```

### CI/CD

GitHub Actions workflows in infrastructure repo:

- `terraform-plan.yml`: runs on PR, validates configuration
- `terraform-apply.yml`: runs on tags (v*), applies changes

Application deployments handled in separate repos with their own workflows
that build images, push to ECR, and trigger App Runner deployments.

Uses OIDC authentication (no long-lived credentials).

## Outputs

```bash
terraform output              # View all outputs
terraform output -json        # JSON format
```

Key outputs:

- Aurora endpoints (sensitive)
- ElastiCache endpoints (sensitive)
- CloudFront distribution domain
- Route53 nameservers (update domain registrar)
- ECR repository URLs
- App Runner service URLs

## Security Notes

### Secrets

- Stored in Secrets Manager, never in code
- Referenced via data sources in Terraform
- Accessed by services via IAM roles
- State file contains sensitive data, never commit to git

### ACM Certificates

CloudFront requires certs in us-east-1, handled by aws.us_east_1 alias.

### IAM

- Least privilege roles for App Runner services
- OIDC for GitHub Actions
- No long-lived access keys

## Maintenance

### State Lock

If operation fails with lock error:

```bash
aws dynamodb scan --table-name portfolio-terraform-locks --region eu-west-1
terraform force-unlock <LOCK_ID>
```

### Resource Import

```bash
terraform import <resource_type>.<resource_name> <resource_id>
```

### Secrets Rotation

Database credentials rotate automatically every 90 days via Lambda.
JWT secret rotates manually.

## Dependencies

Module dependencies (applied in order):

1. networking (VPC, subnets, security groups)
2. secrets (Secrets Manager)
3. database (requires: networking, secrets)
4. cache (requires: networking, secrets)
5. storage (independent)
6. ecr (independent)
7. dns (independent)
8. certificates (requires: dns for validation)
9. waf (independent)
10. app-runner (requires: networking, ecr, secrets, database, cache, storage)
11. cdn (requires: app-runner, certificates, waf)
12. monitoring (requires: app-runner, database, cache, cdn)

## Post-Apply Steps

1. Update domain nameservers to Route53 values from output
2. Verify ACM certificate validation (DNS propagation: 24-48h)
3. Configure DNSSEC signing for Route53 hosted zone:
   - Create KMS key for DNSSEC signing in us-east-1
   - Enable DNSSEC signing on the hosted zone
   - Add DS records to parent domain registrar
4. Configure WAF logging:
   - Create Kinesis Data Firehose delivery stream or S3 bucket
   - Associate logging configuration with WAF Web ACL
   - Set up log retention and analysis tools
5. Connect to Aurora and run Flyway migrations
6. Update Secrets Manager with production values (generated with placeholders)
7. Build and push Docker images to ECR
8. Update App Runner services with inter-service URLs via Secrets Manager:
   - AUTH_SERVICE_URL for admin-api and files-api
   - FILES_API_URL for admin-api and public-api
9. Verify App Runner deployments and health checks
10. Test application via CloudFront URLs

## References

- [AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/)
