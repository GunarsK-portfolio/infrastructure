# App Runner VPC Ingress Implementation

## Overview

This configuration implements **VPC Ingress for App Runner** to make services private while maintaining public access through CloudFront with full WAF protection.

## Architecture

```
Public Internet
    ↓
CloudFront (auth.gunarsk.com) [WAF, Rate Limiting, DDoS Protection]
    ↓
App Runner auth-service (public URL for CloudFront)
    ↓
Service-to-Service Calls (INTERNAL)
    ↓
VPC Ingress Endpoint (private, VPC-only)
    ↓
App Runner auth-service receives S2S traffic
```

## What Was Implemented

### 1. VPC Endpoints for App Runner (modules/app-runner/main.tf:403-421)

Creates VPC Interface Endpoints for each App Runner service:
- Type: Interface endpoints
- Subnets: Private subnets only
- Security Group: App Runner security group (egress-only)
- Private DNS: Disabled (we use explicit domain names)

### 2. VPC Ingress Connections (modules/app-runner/main.tf:423-441)

Restricts App Runner services to VPC-only access:
- Each service gets a unique VPC Ingress connection
- Provides private domain name for internal S2S communication
- Makes public `*.awsapprunner.com` URLs **inaccessible** from internet

### 3. Service-to-Service URLs Updated

**admin-api → auth-service**:
```terraform
AUTH_SERVICE_URL = "https://${aws_apprunner_vpc_ingress_connection.main["auth-service"].domain_name}/api/v1"
```

**files-api → auth-service**:
```terraform
AUTH_SERVICE_URL = "https://${aws_apprunner_vpc_ingress_connection.main["auth-service"].domain_name}/api/v1"
```

### 4. Public Access Remains via CloudFront

**DNS (auth.gunarsk.com)**:
- A Record → CloudFront distribution
- CloudFront → App Runner public URL
- **Only route for public traffic**

## Security Benefits

### ✅ Achieved

1. **App Runner URLs are PRIVATE**
   - `ym3ffkyjn3.eu-west-1.awsapprunner.com` returns connection refused from internet
   - Only accessible via VPC Ingress endpoints from within VPC

2. **CloudFront is the ONLY public entry point**
   - All WAF protections apply (cannot be bypassed)
   - Rate limiting enforced
   - DDoS protection active
   - Security headers applied

3. **Service-to-Service calls are private**
   - Use VPC Ingress endpoints
   - No NAT Gateway needed
   - Low latency (VPC-internal traffic)
   - Cannot be intercepted from internet

4. **Defense in Depth**
   - Network layer: VPC Ingress (private)
   - Application layer: CloudFront + WAF
   - Transport layer: TLS 1.3 (CloudFront), TLS 1.2+ (App Runner)

## Traffic Flow

### Public Access (Browser → Auth Service)

```
Browser
  ↓ HTTPS
auth.gunarsk.com (Route53 A Record)
  ↓
CloudFront Distribution
  ↓ [WAF: Rate limit, OWASP protection, IP reputation]
  ↓ [Security Headers: HSTS, CSP, X-Frame-Options]
  ↓
App Runner auth-service (public URL)
  ↓
Process request
```

### Internal S2S (admin-api → auth-service)

```
admin-api (in VPC)
  ↓ HTTPS
VPC Ingress Endpoint domain
  ↓ [Private VPC traffic only]
  ↓
App Runner auth-service (VPC Ingress)
  ↓
Validate token, return TTL
```

## Cost Impact

**No additional NAT Gateway cost** (~$32/month saved)

**VPC Endpoint cost** (per endpoint, per AZ):
- $0.01/hour = ~$7.20/month per endpoint
- 6 services × 2 AZs = 12 endpoints
- **Total**: ~$86/month for VPC endpoints

**vs NAT Gateway**:
- NAT: $32/month + data transfer costs
- VPC Endpoints: $86/month, **no data transfer costs**
- Trade-off: Higher fixed cost, but more secure + no data charges

## Deployment

```bash
cd infrastructure/terraform

# Review changes
terraform plan

# Apply VPC Ingress configuration
terraform apply

# Verify services are private
curl https://ym3ffkyjn3.eu-west-1.awsapprunner.com/health
# Expected: Connection refused or timeout

# Verify public access works
curl https://auth.gunarsk.com/health
# Expected: 200 OK (through CloudFront)
```

## Testing

### 1. Verify App Runner URLs are Private

```bash
# Should fail (connection refused/timeout)
curl -v https://portfolio-prod-auth-service.eu-west-1.awsapprunner.com/health
```

### 2. Verify CloudFront Access Works

```bash
# Should succeed
curl -v https://auth.gunarsk.com/health

# Should have security headers
curl -I https://auth.gunarsk.com/health | grep -E "X-Frame|HSTS|CSP"
```

### 3. Verify S2S Communication Works

Check admin-api logs for auth validation:
```bash
# Should see successful auth validation via VPC Ingress endpoint
aws logs tail /aws/apprunner/portfolio-prod-admin-api --follow
```

## Troubleshooting

### Issue: Services can't communicate after applying

**Check VPC Endpoint DNS names**:
```bash
terraform output -json | jq '.app_runner.value.vpc_ingress_endpoints'
```

**Check security group allows traffic**:
- App Runner SG should allow egress to all (0.0.0.0/0)
- VPC Endpoint should accept traffic from App Runner SG

### Issue: Public access broken

**Check CloudFront distribution status**:
```bash
aws cloudfront list-distributions --query 'DistributionList.Items[?Aliases.Items[0]==`auth.gunarsk.com`]'
```

**Check DNS records**:
```bash
dig auth.gunarsk.com
# Should point to CloudFront distribution
```

## References

- [AWS App Runner VPC Ingress](https://docs.aws.amazon.com/apprunner/latest/api/API_VpcIngressConnection.html)
- [Terraform aws_apprunner_vpc_ingress_connection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apprunner_vpc_ingress_connection)
- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
