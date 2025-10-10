# Portfolio Infrastructure

This repository contains infrastructure configuration, documentation, and orchestration for the portfolio microservices system.

## Overview

The portfolio system is built with a microservices architecture consisting of:

- **Public Web** - Vue.js portfolio site
- **Admin Web** - Vue.js admin portal with authentication
- **Public API** - Go REST API for public data
- **Admin API** - Go REST API for content management
- **Auth Service** - Go authentication & authorization service
- **Database** - PostgreSQL with Flyway migrations
- **Cache** - Redis for sessions
- **Storage** - MinIO (local) / S3 (AWS) for images
- **Reverse Proxy** - Traefik for unified routing and load balancing

## Quick Start

### Prerequisites

- Docker Desktop installed and running
- [Task](https://taskfile.dev/installation/) (task runner)
- Git
- At least 4GB RAM available for Docker

### Run All Services

```bash
# Clone this repository
git clone git@github.com:GunarsK-portfolio/infrastructure.git
cd infrastructure

# Clone all service repositories (adjacent to this repo)
cd ..
git clone git@github.com:GunarsK-portfolio/public-web.git
git clone git@github.com:GunarsK-portfolio/public-api.git
git clone git@github.com:GunarsK-portfolio/admin-web.git
git clone git@github.com:GunarsK-portfolio/admin-api.git
git clone git@github.com:GunarsK-portfolio/auth-service.git
git clone git@github.com:GunarsK-portfolio/database.git

# Return to infrastructure directory
cd infrastructure

# Start all services
task up

# View logs
task logs

# Check status
task ps
```

### Access Services

Once all services are running:

**Primary Access (via Traefik Reverse Proxy):**

| Service | URL | Description |
|---------|-----|-------------|
| **Public Portfolio** | http://localhost | Public website |
| Public API | http://localhost/api/v1/* | Public REST API |
| **Admin Portal** | http://localhost:81 | Content management |
| Admin API | http://localhost:81/api/v1/* | Admin REST API |
| Auth API | http://localhost:81/auth/* | Authentication endpoints |
| **API Docs** | http://localhost:82 | Swagger documentation |
| - Public API Docs | http://localhost:82/public/ | Public API Swagger |
| - Admin API Docs | http://localhost:82/admin/ | Admin API Swagger |
| - Auth API Docs | http://localhost:82/auth/ | Auth API Swagger |

**Direct Service Access (for debugging):**

| Service | URL | Description |
|---------|-----|-------------|
| Public Web | http://localhost:8080 | Direct access to website |
| Admin Web | http://localhost:8081 | Direct access to admin portal |
| Public API | http://localhost:8082 | Direct access to public API |
| Admin API | http://localhost:8083 | Direct access to admin API |
| Auth Service | http://localhost:8084 | Direct access to auth service |
| MinIO Console | http://localhost:9001 | Object storage UI |

### Default Credentials

**Admin Portal:**
- Username: `admin`
- Password: `admin123` (set via database seed)

**MinIO:**
- Access Key: `minioadmin`
- Secret Key: `minioadmin`

**Database:**
- Host: `localhost:5432`
- Database: `portfolio`
- Username: `portfolio_user`
- Password: `portfolio_pass`

**Redis:**
- Host: `localhost:6379`
- No password (local development)

## Repository Structure

```
infrastructure/
├── docker/                     # Docker configurations
│   ├── nginx/                 # Nginx configs for web apps
│   └── postgres/              # PostgreSQL init scripts
├── docs/                      # Documentation
│   ├── ARCHITECTURE.md        # System architecture
│   ├── API.md                 # API documentation
│   └── DEPLOYMENT.md          # Deployment guide
├── terraform/                 # AWS infrastructure as code
│   ├── modules/              # Terraform modules
│   ├── environments/         # Environment configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── main.tf
├── docker-compose.yml         # Main compose file (all services)
├── docker-compose.dev.yml     # Development overrides
├── Taskfile.yml              # Task runner configuration
├── .env.example              # Environment variables template
└── README.md                 # This file
```

## Development

### Managing Individual Services

Stop/start/rebuild individual services:

```bash
# Stop a service (for local debugging)
task stop-auth
task stop-public-api
task stop-admin-api

# Rebuild and restart after code changes
task rebuild-auth
task rebuild-public-api
task rebuild-admin-api

# View logs for specific service
task logs-auth
task logs-public-api
```

### Running Services Locally (Outside Docker)

Each service has a `.env.example` file:

```bash
# In any service directory (auth-service, public-api, etc.)
cd ../auth-service

# Copy environment file
cp .env.example .env

# Edit .env with your settings

# Run locally with Task
task run

# Or debug in VS Code (F5)
```

**Note:** Make sure Docker services (postgres, redis, minio) are still running for local development.

### Database Migrations

Migrations are managed in the `database` repository using Flyway.

```bash
# Run migrations manually
docker-compose run flyway migrate

# Check migration status
docker-compose run flyway info

# Rollback last migration
docker-compose run flyway undo
```

### Stopping Services

```bash
# Stop all services
task down

# Stop and remove volumes (WARNING: deletes all data)
task clean
```

## Deployment

### AWS Deployment

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed AWS deployment instructions.

Quick overview:
1. Configure AWS credentials
2. Update Terraform variables
3. Run Terraform to provision infrastructure
4. Push Docker images to ECR
5. Deploy services to ECS

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### CI/CD

Each service repository has GitHub Actions workflows for:
- Running tests
- Building Docker images
- Pushing to ECR
- Deploying to ECS (on merge to main)

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed system architecture.

## Monitoring

### Local Development

```bash
# View logs for all services
task logs

# View logs for specific service
task logs-auth

# Check service health
curl http://localhost:8084/api/v1/health
```

### Production

- **CloudWatch** - Logs and metrics
- **AWS X-Ray** - Distributed tracing
- **Application Load Balancer** - Health checks

## Troubleshooting

### Services won't start

```bash
# Check Docker is running
docker info

# Check available resources
docker stats

# Restart Docker Desktop
```

### Database connection errors

```bash
# Check PostgreSQL is healthy
docker-compose ps postgres

# Check logs
docker-compose logs postgres

# Connect to database
docker-compose exec postgres psql -U portfolio_user -d portfolio
```

### Port conflicts

If ports are already in use, edit `docker-compose.yml` to use different ports.

### Clean slate

```bash
# Stop everything and remove volumes
task clean

# Remove all portfolio images
docker images | grep portfolio | awk '{print $3}' | xargs docker rmi -f

# Start fresh
task up
```

## Contributing

1. Create feature branch
2. Make changes
3. Test locally with Docker Compose
4. Submit Pull Request
5. Wait for CI/CD to pass
6. Merge after review

## Related Repositories

- [public-web](https://github.com/GunarsK-portfolio/public-web)
- [public-api](https://github.com/GunarsK-portfolio/public-api)
- [admin-web](https://github.com/GunarsK-portfolio/admin-web)
- [admin-api](https://github.com/GunarsK-portfolio/admin-api)
- [auth-service](https://github.com/GunarsK-portfolio/auth-service)
- [database](https://github.com/GunarsK-portfolio/database)

## License

MIT