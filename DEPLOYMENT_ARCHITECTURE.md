# Deployment Architecture

## Repository Structure

Infrastructure and applications are separated into independent repositories:

- **infrastructure**: Terraform modules, AWS infrastructure provisioning
- **public-web**: Vue 3 public website
- **admin-web**: Vue 3 admin panel
- **auth-service**: Go authentication service
- **admin-api**: Go admin API
- **public-api**: Go public API
- **files-api**: Go file management API

## Deployment Flow

### Infrastructure Changes (Terraform)

**Repository**: infrastructure
**Trigger**: Git tags matching `v*` (e.g., v1.0.0, v1.2.3)
**Workflow**: `.github/workflows/terraform-apply.yml`

1. Tag the infrastructure repo: `git tag v1.0.0 && git push origin v1.0.0`
2. GitHub Actions runs Terraform apply
3. Creates/updates AWS resources (VPC, Aurora, ElastiCache, App Runner services, etc.)
4. Outputs saved as artifacts

### Application Deployments

**Repository**: Each application repo (public-web, admin-web, etc.)
**Trigger**: Git tags matching `v*` (e.g., v1.0.0, v2.1.3)
**Workflow**: `.github/workflows/deploy.yml` (copy from template)

1. Tag the application repo: `git tag v1.0.0 && git push origin v1.0.0`
2. GitHub Actions workflow:
   - Builds Docker image
   - Runs Trivy security scan
   - Pushes image to ECR with version tag and `latest`
   - Triggers App Runner deployment for that specific service
3. App Runner pulls new image from ECR
4. Deploys with zero-downtime rolling update

## Setup Instructions

### 1. Infrastructure Repository Setup

Configure GitHub secrets in infrastructure repo:
- `AWS_ROLE_ARN`: IAM role for Terraform (OIDC)

Workflows:
- `terraform-plan.yml`: Validates on PR
- `terraform-apply.yml`: Deploys on version tags

### 2. Application Repository Setup

For each application repo (public-web, admin-web, auth-service, etc.):

**Step 1**: Copy deployment workflow
```bash
mkdir -p .github/workflows
cp ../infrastructure/.github/workflows/app-deploy-template.yml .github/workflows/deploy.yml
```

**Step 2**: Configure GitHub secrets
- `AWS_ROLE_ARN`: IAM role for ECR push and App Runner deployment (OIDC)

**Step 3**: Verify service naming
Ensure `APP_RUNNER_SERVICE` environment variable matches Terraform:
- Format: `portfolio-prod-{repo-name}`
- Examples: `portfolio-prod-public-web`, `portfolio-prod-auth-service`

### 3. OIDC Setup

Create IAM OIDC provider and roles:

**GitHub OIDC Provider** (one-time):
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Terraform Role** (infrastructure repo):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::{account}:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:{org}/infrastructure:*"
      }
    }
  }]
}
```

Attach policy: `AdministratorAccess` (or custom policy with Terraform permissions)

**Application Role** (application repos):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::{account}:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:{org}/*:*"
      }
    }
  }]
}
```

Attach custom policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apprunner:ListServices",
        "apprunner:StartDeployment",
        "apprunner:DescribeService"
      ],
      "Resource": "arn:aws:apprunner:eu-west-1:{account}:service/portfolio-prod-*"
    }
  ]
}
```

## Deployment Examples

### Deploy Infrastructure Changes
```bash
cd infrastructure
git add .
git commit -m "Add monitoring alarms"
git tag v1.1.0
git push origin main
git push origin v1.1.0  # Triggers terraform-apply.yml
```

### Deploy Application Update
```bash
cd public-web
git add .
git commit -m "Update homepage design"
git tag v2.3.1
git push origin main
git push origin v2.3.1  # Triggers deploy.yml
```

## Rollback Procedure

### Rollback Application
Deploy previous version by retagging:
```bash
# Find previous working version
git tag --sort=-v:refname

# Redeploy previous version
git tag -f v2.3.0 abc1234  # Force tag to previous commit
git push -f origin v2.3.0  # Triggers deployment
```

Or manually via AWS CLI:
```bash
# Get previous image SHA
IMAGE_SHA=sha256:...

# Update App Runner service
aws apprunner update-service \
  --service-arn arn:aws:apprunner:eu-west-1:{account}:service/portfolio-prod-public-web \
  --source-configuration ImageRepository={ImageIdentifier={account}.dkr.ecr.eu-west-1.amazonaws.com/portfolio/public-web@$IMAGE_SHA}
```

### Rollback Infrastructure
Use Terraform state management:
```bash
cd infrastructure
git checkout v1.0.0  # Previous working version
terraform plan
terraform apply
```

## Monitoring Deployments

### GitHub Actions
Monitor workflow runs in each repository's Actions tab.

### App Runner Deployments
```bash
# List services
aws apprunner list-services

# Check service status
aws apprunner describe-service --service-arn {service-arn}

# View logs
aws logs tail /aws/apprunner/portfolio-prod-{service} --follow
```

### CloudWatch
- Dashboard: `portfolio-prod-dashboard`
- Alarms: SNS notifications for failures
- Logs: `/aws/apprunner/portfolio-prod-*`

## CI/CD Best Practices

1. **Tag Naming**: Use semantic versioning (vMAJOR.MINOR.PATCH)
2. **Testing**: Run tests before tagging
3. **Security Scanning**: Trivy runs automatically, blocks HIGH/CRITICAL vulnerabilities
4. **Zero-Downtime**: App Runner performs rolling updates
5. **Monitoring**: Check CloudWatch logs after deployment
6. **Rollback Plan**: Keep previous tags for quick rollback

## Troubleshooting

### Deployment Fails - ECR Push Error
```bash
# Verify ECR repository exists
aws ecr describe-repositories --repository-names portfolio/{service}

# Check IAM permissions
aws sts get-caller-identity
```

### Deployment Fails - App Runner Not Found
```bash
# Verify service name matches Terraform output
aws apprunner list-services --query "ServiceSummaryList[*].ServiceName"
```

### Image Fails Security Scan
Review Trivy output in GitHub Actions, update dependencies, rebuild.
