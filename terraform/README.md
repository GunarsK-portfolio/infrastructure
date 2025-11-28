# Terraform Infrastructure

AWS serverless infrastructure for production deployment.

## AWS Services Used

<!-- markdownlint-disable MD013 -->

| Service | Type | Purpose |
|---------|------|---------|
| **App Runner** | Compute | Serverless container runtime for 7 microservices (auth-service, admin-api, public-api, files-api, messaging-api, admin-web, public-web). Auto-scales 1-10 instances per service. |
| **Aurora Serverless v2** | Database | PostgreSQL 17.4 with auto-scaling (1-16 ACU). Multi-AZ deployment with 30-day backups, encryption, and pg_cron/pg_stat_statements extensions. |
| **ElastiCache** | Cache | Valkey 8.2 (Redis-compatible) for session storage. Single cache.t4g.micro node (~$12/month). |
| **S3** | Storage | Object storage for images, documents, miniatures. Versioning enabled with lifecycle policies and access logging. |
| **CloudFront** | CDN | 5 distributions (public, admin, auth, files, message) with path-based routing, TLS 1.2+, HTTP/3, and global edge caching. |
| **WAF** | Security | Web Application Firewall protecting CloudFront with rate limiting, OWASP Top 10 rules, and Log4j protection. |
| **Route53** | DNS | DNS hosting with DNSSEC, CAA records, query logging, and automatic certificate validation. |
| **ACM** | Security | SSL/TLS certificates (*.gunarsk.com wildcard) with automatic DNS validation and renewal. |
| **CloudTrail** | Audit | API activity logging for all AWS services with CloudWatch integration and 6 security event alarms (console login failures, IAM/S3 policy changes, KMS operations, network changes, CloudTrail tampering). |
| **Secrets Manager** | Security | Encrypted storage for database passwords, Redis auth tokens, JWT secrets. Manual rotation required. |
| **KMS** | Security | Encryption key management for secrets, database, and S3 bucket encryption. |
| **ECR** | Registry | Container image registry with vulnerability scanning and lifecycle policies (keep last 10 images). |
| **VPC** | Network | Isolated network with 2 public and 2 private subnets across 2 AZs. VPC Flow Logs enabled. |
| **CloudWatch** | Monitoring | Log aggregation, metrics collection, dashboards, and alarms for error rates and performance monitoring. |
| **X-Ray** | Observability | Distributed tracing for App Runner services. Request latency analysis, service map visualization, error tracking across microservices. |
| **SNS** | Alerting | Email/SMS notifications for critical alarms (errors, latency spikes, resource limits). |
| **GuardDuty** | Security | Threat detection monitoring for suspicious activity, compromised credentials, and malicious IPs. |
| **IAM** | Security | Role-based access control with least privilege. OIDC for GitHub Actions, no long-lived credentials. |

<!-- markdownlint-enable MD013 -->

## Production URLs

| Domain | Purpose | Backend Services |
|--------|---------|-----------------|
| `gunarsk.com` | Public website | public-web (/) + public-api (/api/v1/*) |
| `admin.gunarsk.com` | Admin panel | admin-web (/) + admin-api (/api/v1/*) |
| `auth.gunarsk.com` | Authentication API | auth-service |
| `files.gunarsk.com` | File upload/download API | files-api |
| `message.gunarsk.com` | Contact form API | messaging-api |

**Note**: Public API is read-only (GET, HEAD, OPTIONS only).

## Architecture

### Compute

- AWS App Runner: 7 services (auth, admin-api, public-api, files-api,
  messaging-api, webs)
- Auto-scaling: 1-10 instances per service
- Instance config: 1 vCPU, 2 GB RAM
- VPC connector for private resource access

### Database

- Aurora Serverless v2 PostgreSQL 17.4
- Scaling: 1-16 ACU (configurable)
- Multi-AZ deployment
- Encryption: KMS at rest, TLS in transit
- Backups: 30-day retention, automated snapshots
- Extensions: pg_stat_statements, pg_cron

### Cache

- ElastiCache Valkey 8.2 (Redis-compatible OSS fork)
- Single cache.t4g.micro node (~$12/month vs $90+/month serverless)
- Port 6379
- Encryption at rest and in transit
- AUTH token authentication

### Storage

- S3 buckets: images, documents, miniatures
- Versioning enabled
- Lifecycle policies: transition to Standard-IA (30d), Glacier (90d)
- Block public access enforced

### CDN & Security

#### CloudFront

- **5 separate distributions**: public, admin, auth, files, message
- **Path-based routing**: / → frontend, /api/v1/* → backend
- **TLS**: TLS 1.3 only with post-quantum cryptography (TLSv1.3_2025), HTTP/3 enabled
- **IPv6**: Enabled
- **HTTPS redirect**: Enforced
- **Price class**: PriceClass_100 (North America + Europe)
- **Caching**: Frontend cached (3600s), APIs bypass cache (TTL 0)

#### Why CloudFront + App Runner?

**App Runner limitation**: Each service can only have one custom domain.
Cannot do path-based routing like `gunarsk.com/api/v1/*`.

**Solution**: CloudFront handles custom domains and path routing.
App Runner services use their default `.awsapprunner.com` URLs for
internal communication.

**External traffic**: Users → CloudFront (custom domains) → App Runner

**Internal traffic**: Backend-to-backend uses App Runner default URLs

#### WAF

- **Rate limiting** (per IP, per 5 minutes, filters by Host header + path):
  - Login (`auth.gunarsk.com/login`): 20 requests (brute-force protection)
  - Token Refresh (`auth.gunarsk.com/refresh`): 100 requests (token abuse prevention)
  - Token Validation (`auth.gunarsk.com/validate`): 300 requests (validation protection)
  - Logout (`auth.gunarsk.com/*/logout`): 60 requests (logout abuse prevention)
  - Admin API (`admin.gunarsk.com/api/v1/*`): 1200 requests total
    (DELETE: 60, POST: 300, PUT: 300, GET: 600)
  - Public API (`gunarsk.com/api/v1/*`): 600 requests (2 req/sec, reduced from 1800)
  - Files API (`files.gunarsk.com/api/v1/*`): 200 requests (file upload/download)
- **AWS Managed Rules**:
  - Core Rule Set (OWASP Top 10)
  - Known Bad Inputs (Log4Shell protection)
  - SQL Injection Rule Set
  - IP Reputation List (blocks known malicious IPs)
  - Linux Rule Set (OS-level exploit protection)
- **Logging**: CloudWatch Logs, 30-day retention for security forensics
- **Associated with**: All CloudFront distributions

#### Security Headers

- **HSTS**: Strict-Transport-Security (2 years, preload enabled)
- **X-Frame-Options**: DENY (prevents clickjacking)
- **X-Content-Type-Options**: nosniff (prevents MIME sniffing)
- **Referrer-Policy**: strict-origin-when-cross-origin
- **X-XSS-Protection**: 1; mode=block (legacy browser protection)
- **Content-Security-Policy**: Restricts script/style sources
- **Applied to**: All CloudFront distributions via response headers policy

#### ACM & DNS

- **ACM certificates**: `*.gunarsk.com` (wildcard, us-east-1 for CloudFront)
- **Validation**: DNS (automatic via Route53)
- **Route53**: DNS hosting, DNSSEC enabled, CAA records, query logging

### Monitoring & Observability

- **CloudWatch**: log groups per service
  - Application logs: 7-day retention
  - VPC Flow Logs: 90-day retention (forensic analysis)
  - Route53 Query Logs: 30-day retention (DNS attack analysis)
- **X-Ray Tracing**: distributed tracing for App Runner services
  - Service map: visualize dependencies (admin-api → auth-service → Aurora)
  - Request analysis: end-to-end latency breakdown per request
  - Error tracking: identify which service is causing failures
  - Configurable via `enable_xray_tracing` variable (default: enabled)
- **Alarms**: error rates, latency, resource utilization
- **SNS notifications** for critical events
- **Dashboard**: unified metrics view

### Secrets & Registry

- Secrets Manager: database passwords, Redis auth, JWT secret
- KMS encryption for secrets
- ECR: 7 repositories with enhanced scanning
- Lifecycle policy: keep last 10 images

## Module Structure

```text
modules/
├── networking/     VPC, subnets (2 public, 2 private), security groups
├── secrets/        Secrets Manager with KMS encryption
├── database/       Aurora Serverless v2, subnet groups, security groups
├── cache/          ElastiCache Valkey (single node), subnet groups
├── storage/        S3 buckets with versioning and lifecycle policies
├── ecr/            Container registries with image scanning
├── certificates/   ACM certificates (us-east-1 for CloudFront)
├── dns/            Route53 hosted zone and DNS records (A/AAAA for 5 distributions)
├── waf/            WAF Web ACL with rate limiting rules
├── cloudfront/     5 CloudFront distributions (public, admin, auth, files, message)
├── app-runner/     7 App Runner services with VPC connector
└── monitoring/     CloudWatch log groups, alarms, dashboard, SNS topic
```

## Configuration

### Backend Setup (One-Time)

State stored in S3 with DynamoDB locking:

```bash
aws s3 mb s3://gunarsk-portfolio-terraform-state-prod --region eu-west-1

aws s3api put-bucket-versioning \
  --bucket gunarsk-portfolio-terraform-state-prod \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket gunarsk-portfolio-terraform-state-prod \
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
domain_name             = "gunarsk.com"  # Subdomains: admin.*, auth.*, files.*
aurora_min_capacity     = 1
aurora_max_capacity     = 16
enable_enhanced_monitoring    = true
enable_performance_insights   = true
enable_ecr_enhanced_scanning  = true
enable_xray_tracing           = true  # AWS X-Ray distributed tracing
```

## Deployment

### Local

```bash
terraform init
terraform plan
terraform apply
```

### CI/CD

#### Infrastructure Workflows

GitHub Actions workflows in infrastructure repo:

- `terraform-plan.yml`: runs on PR, validates configuration
- `terraform-apply.yml`: runs on version tags (`v*`), applies infrastructure changes

Required GitHub secrets:

- `AWS_ROLE_ARN`: OIDC role for GitHub Actions
- `AWS_REGION`: `eu-west-1`
- `TF_VAR_domain_name`: `gunarsk.com`
- `TF_VAR_budget_alert_emails`: JSON array `["email@example.com"]`
  for budget alerts
- `TF_VAR_alarm_email_addresses`: JSON array
  `["ops@example.com","oncall@example.com"]` for alarm notifications

Optional GitHub secrets (defaults shown):

- `TF_VAR_enable_guardduty`: `true` - GuardDuty threat detection
- `TF_VAR_enable_budgets`: `true` - AWS Budgets cost control
- `TF_VAR_enable_vpc_flow_logs`: `true` - VPC network monitoring
- `TF_VAR_enable_http_endpoint`: `false` - Aurora Data API
- `TF_VAR_enable_xray_tracing`: `true` - X-Ray distributed tracing
- `TF_VAR_monthly_budget_limit`: `100` - Budget limit in USD

#### Application Deployments

Each service repository has its own GitHub Actions workflow that:

1. Builds Docker image
2. Pushes to ECR
3. Triggers App Runner deployment

Uses OIDC authentication (no long-lived credentials).

## Outputs

```bash
terraform output              # View all outputs
terraform output -json        # JSON format
```

Key outputs:

- `aurora_endpoint` (sensitive): Database connection endpoint
- `elasticache_primary_endpoint` (sensitive): Redis write endpoint
- `elasticache_reader_endpoint` (sensitive): Redis read endpoint
- `cloudfront_distribution_urls`: Map of all 4 CloudFront URLs
- `route53_nameservers`: Update these at your domain registrar
- `ecr_repository_urls`: Docker image repository URLs
- `app_runner_service_urls`: Internal service URLs (for backend-to-backend communication)

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

**Manual Rotation Required**: All secrets must be rotated manually.

Database passwords (portfolio_master, portfolio_owner, portfolio_admin, portfolio_public):

```bash
aws secretsmanager update-secret \
  --secret-id portfolio/prod/db/admin \
  --secret-string '{"username":"portfolio_admin","password":"NEW_PASSWORD"}'
```

Redis AUTH token:

```bash
aws secretsmanager update-secret \
  --secret-id portfolio/prod/redis/password \
  --secret-string 'NEW_REDIS_AUTH_TOKEN'
```

JWT secret:

```bash
aws secretsmanager update-secret \
  --secret-id portfolio/prod/jwt/secret \
  --secret-string 'NEW_JWT_SECRET'
```

**Rotation Schedule** (recommended):

- Database passwords: Every 90 days
- Redis AUTH token: Every 90 days
- JWT secret: Every 180 days or after security incident

**After rotation**: Restart affected App Runner services to pick up new secrets.

## Dependencies

Module dependencies (applied in order):

1. networking (VPC, subnets, security groups)
2. secrets (Secrets Manager)
3. database (requires: networking, secrets)
4. cache (requires: networking, secrets)
5. storage (independent)
6. ecr (independent)
7. dns (Route53 hosted zone)
8. certificates (requires: dns for validation)
9. waf (independent)
10. app-runner (requires: networking, ecr, secrets, database, cache, storage)
11. cloudfront (requires: app-runner, certificates, waf - creates 4 distributions)
12. monitoring (requires: app-runner, database, cache, cloudfront)

## Post-Apply Steps

### 1. Update Domain Nameservers

```bash
# Get Route53 nameservers
terraform output route53_nameservers
```

Update your domain registrar with these nameservers.
DNS propagation takes 24-48 hours.

### 2. Verify ACM Certificate

```bash
# Check certificate validation status
aws acm list-certificates --region us-east-1
aws acm describe-certificate --certificate-arn <ARN> --region us-east-1
```

Certificate auto-validates via DNS once nameservers propagate.

### 3. Enable DNSSEC (Optional)

DNSSEC signing is enabled via Terraform. Add DS record to your domain registrar:

```bash
# Get DS record from Route53
aws route53 get-dnssec --hosted-zone-id <ZONE_ID>
```

Add the DS record to your domain registrar's DNS settings.

### 4. Update Secrets Manager

Terraform creates secrets with placeholder values. Update them immediately:

```bash
# Database passwords (4 users: master, owner, admin, public)
aws secretsmanager update-secret \
  --secret-id portfolio/prod/db/master \
  --secret-string '{"username":"portfolio_master","password":"STRONG_PASSWORD"}'

aws secretsmanager update-secret \
  --secret-id portfolio/prod/db/owner \
  --secret-string '{"username":"portfolio_owner","password":"STRONG_PASSWORD"}'

aws secretsmanager update-secret \
  --secret-id portfolio/prod/db/admin \
  --secret-string '{"username":"portfolio_admin","password":"STRONG_PASSWORD"}'

aws secretsmanager update-secret \
  --secret-id portfolio/prod/db/public \
  --secret-string '{"username":"portfolio_public","password":"STRONG_PASSWORD"}'

# Redis AUTH token
aws secretsmanager update-secret \
  --secret-id portfolio/prod/redis/password \
  --secret-string '{"token":"REDIS_AUTH_TOKEN"}'

# JWT secret
aws secretsmanager update-secret \
  --secret-id portfolio/prod/jwt/secret \
  --secret-string '{"secret":"JWT_SECRET_KEY"}'
```

**Note**: Secrets do not auto-rotate. See [Secrets Rotation](#secrets-rotation)
section for manual rotation schedule.

### 5. Run Database Migrations

```bash
# Get Aurora endpoint
terraform output aurora_endpoint

# Run Flyway migrations (from database repo)
flyway migrate \
  -url=jdbc:postgresql://<AURORA_ENDPOINT>:5432/portfolio \
  -user=portfolio_owner \
  -password=<FLYWAY_PASSWORD> \
  -locations=filesystem:./migrations,filesystem:./seeds
```

### 6. Build and Push Docker Images

Each service repository has a workflow. Trigger by creating version tags:

```bash
# In each service repo (auth-service, admin-api, etc.)
git tag v0.1.0
git push origin v0.1.0
```

### 7. Configure Inter-Service Communication

Get App Runner service URLs:

```bash
terraform output app_runner_service_urls
```

Store these in Secrets Manager for backend-to-backend calls:

```bash
# FILES_API_URL (used by admin-api, public-api)
aws secretsmanager create-secret \
  --name portfolio/prod/app-runner/files-api-url \
  --secret-string 'https://yyyyy.eu-west-1.awsapprunner.com'
```

Note: admin-api and files-api use JWT_SECRET for local token validation instead of
calling auth-service. The JWT_SECRET is already stored in Secrets Manager.

Update App Runner environment variables to reference these secrets.

### 8. Verify Deployment

Test each CloudFront distribution:

```bash
# Get URLs
terraform output cloudfront_distribution_urls

# Test endpoints
curl -I https://gunarsk.com
curl -I https://gunarsk.com/api/v1/health
curl -I https://admin.gunarsk.com
curl -I https://auth.gunarsk.com/api/v1/health
curl -I https://files.gunarsk.com/api/v1/health
```

## Monitoring & Operations

### CloudWatch Dashboard

```bash
# Get dashboard URL
terraform output cloudwatch_dashboard_url
```

Or navigate to: CloudWatch → Dashboards → `portfolio-prod-dashboard`

### Email Alerts

Subscribe to SNS topic for alarm notifications:

```bash
# Get SNS topic ARN
terraform output sns_topic_arn

# Subscribe
aws sns subscribe \
  --topic-arn <SNS_TOPIC_ARN> \
  --protocol email \
  --notification-endpoint your-email@example.com
```

Confirm subscription via email.

### Log Queries

Query logs in CloudWatch Logs Insights:

```text
# Select log groups: /aws/apprunner/portfolio-prod-*

# Find errors in last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

### Expected Costs

Approximate monthly costs (low traffic):

- App Runner: $30-50 (6 services)
- Aurora Serverless v2: $40-60 (1-16 ACU)
- ElastiCache Valkey: ~$12 (cache.t4g.micro)
- CloudFront: $5-10
- WAF: $5-8 (web ACL + rules, no Bot Control)
- S3: $1-5
- Route53: $1
- Other (CloudWatch, Secrets, ECR): $5-10

**Total**: ~$100-150/month

## References

- [AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/)
