# Monitoring Module

CloudWatch monitoring with alarms, dashboard, and email notifications.

## What's Included

### Dashboard (9 widgets)

<!-- markdownlint-disable MD013 MD058 -->
| Service | Metrics | Details |
| --------- | --------- | --------- |
| **App Runner** | Error rates, Latency (p99), Request count | All 6 services combined on single widgets with color-coded lines |
| **Aurora** | ACU utilization, Database connections | Serverless capacity and connection pool monitoring |
| **ElastiCache** | Memory utilization, Evictions | Cache memory pressure and eviction rate tracking |
| **CloudFront** | Total requests, 5xx error rate | All 4 distributions (public, admin, auth, files) combined |
<!-- markdownlint-enable MD013 MD058 -->

### Alarms (32 total, email notifications via SNS)

<!-- markdownlint-disable MD013 MD058 -->
| Service | Alarm Type | Threshold | Evaluation | Action |
| --------- | ----------- | ----------- | ------------ | -------- |
| **App Runner** (24) | 4xx error rate | >5% | 2 periods of 5min | Email alert |
| | 5xx error rate | >1% | 2 periods of 5min | Email alert |
| | Request latency (p99) | >3s | 2 periods of 5min | Email alert |
| | Low request count | <1 req/5min | 1 period of 5min | Email alert (service down) |
| **Aurora** (1) | Database connections | >400 | 2 periods of 5min | Email alert |
| **ElastiCache** (2) | Memory utilization | >80% | 2 periods of 5min | Email alert |
| | Evictions | >100/min | 2 periods of 1min | Email alert |
| **CloudFront** (4) | 5xx error rate | >5% | 2 periods of 5min | Email per distribution |
| **WAF** (1) | High block rate | >100 req/5min | 1 period of 5min | Email alert (attack) |
<!-- markdownlint-enable MD013 MD058 -->

### Log Groups

<!-- markdownlint-disable MD013 MD058 -->
| Type | Retention | Purpose |
| ------ | ----------- | --------- |
| **App Runner** | 7 days | Application logs for all 6 services |
| **VPC Flow Logs** | 90 days | Network traffic analysis, security forensics |
| **Route53 Query Logs** | 30 days | DNS query monitoring, attack detection |
<!-- markdownlint-enable MD013 MD058 -->

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name = "portfolio"
  environment  = "prod"

  # Email notifications
  alarm_email_addresses = ["ops@example.com", "oncall@example.com"]

  # Resources to monitor
  app_runner_service_arns      = module.app_runner.service_arns
  cloudfront_distribution_ids  = module.cloudfront.distribution_ids
  db_cluster_id               = module.database.cluster_id
  cache_id                    = module.cache.cache_id
  waf_web_acl_name            = module.waf.web_acl_name

  # Optional: custom thresholds
  app_runner_4xx_threshold = 5
  app_runner_5xx_threshold = 1
  app_runner_latency_threshold = 3
  db_connection_threshold = 400
}
```

### Important: SNS Email Subscription Confirmation

After deploying this module, **recipients must manually confirm their SNS
subscriptions**:

1. Each email address in `alarm_email_addresses` receives a confirmation email
   from AWS
2. Recipients must click the "Confirm subscription" link in the email
3. Alarms will NOT send notifications until subscriptions are confirmed
4. Confirmation links expire after 3 days

**Security Note**: Email addresses are stored in Terraform state files. Ensure
state files are:

- Stored in encrypted S3 buckets (backend encryption enabled)
- Access-controlled via IAM policies
- Never committed to version control

## Outputs

| Output | Type | Description |
| -------- | ------ | ------------- |
| `sns_topic_arn` | string | SNS topic ARN for alarm notifications |
| `dashboard_name` | string | CloudWatch dashboard name |
| `log_group_arns` | map(string) | Map of log group ARNs keyed by service name |

## Alarm Customization

All thresholds are configurable:

```hcl
# App Runner thresholds
app_runner_4xx_threshold             = 5    # percent
app_runner_5xx_threshold             = 1    # percent
app_runner_latency_threshold         = 3    # seconds
app_runner_request_count_threshold   = 1    # per 5 minutes

# Database thresholds
db_connection_threshold = 400  # connections

# Cache thresholds
cache_memory_threshold     = 80   # percent
cache_evictions_threshold  = 100  # per minute
```
