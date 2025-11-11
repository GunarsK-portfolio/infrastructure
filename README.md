# Portfolio Infrastructure

![CI](https://github.com/GunarsK-portfolio/infrastructure/workflows/CI/badge.svg)

Docker Compose orchestration for the portfolio project microservices.

## Overview

This repository contains the Docker Compose configuration and Traefik
reverse proxy setup for running all portfolio services together.

## Services

### Application Services

- **auth-service** - JWT authentication service
- **public-api** - Public API service (read-only)
- **admin-api** - Admin API service (full CRUD)
- **files-api** - File upload/download service
- **public-web** - Public frontend (Vue.js + Naive UI)
- **admin-web** - Admin frontend (Vue.js + Naive UI)

### Infrastructure Services

- **Traefik** - Reverse proxy and load balancer
- **PostgreSQL** - Main database
- **Redis** - Session and cache store
- **MinIO** - S3-compatible object storage
- **Flyway** - Database migrations

### Observability Stack (Optional)

- **OpenTelemetry Collector** - Receives telemetry from Claude Code
- **Prometheus** - Metrics collection and storage
- **Loki** - Log aggregation and indexing
- **Promtail** - Log shipping from containers
- **Grafana** - Metrics and logs visualization

> See [monitoring/README.md](monitoring/README.md) for observability
> stack setup and usage.
>
> **Claude Code telemetry** is automatically enabled via
> `.claude/settings.json`. View metrics at <http://localhost:3000>
> (Grafana dashboard: "Claude Code - Usage Dashboard")

## Prerequisites

- Docker and Docker Compose
- [Task](https://taskfile.dev/) (optional, for Taskfile commands)
- Clone all service repositories in the parent directory

## Repository Structure

Expected directory layout:

```text
portfolio/
├── infrastructure/     # This repo
├── auth-service/       # Auth service repo
├── public-api/         # Public API repo
├── admin-api/          # Admin API repo
├── files-api/          # Files API repo
├── public-web/         # Public web repo
├── admin-web/          # Admin web repo
├── database/           # Database repo
├── e2e-tests/          # E2E tests repo
└── portfolio-common/   # Shared models repo
```

## Quick Start

1. Ensure all service repositories are cloned in the parent directory

2. **Generate secure secrets** (recommended):

```bash
task secrets:generate
```

This creates a `.env` file with cryptographically secure passwords.

Alternatively, manually copy and edit the environment file:

```bash
cp .env.example .env
# Edit .env with your own passwords
```

1. Start all services:

```bash
task services:up
```

Or combine steps 2-3 with:

```bash
task init  # Generate secrets and start services
```

1. **Optional**: Start observability stack:

```bash
task monitoring:up
```

1. Access the applications:

| Service | URL | Credentials |
|---------|-----|-------------|
| Public Website | <http://localhost> | - |
| Public Website (HTTPS) | <https://localhost> | - |
| Admin Panel | <http://localhost:81> | - |
| Admin Panel (HTTPS) | <https://localhost:8443> | - |
| Swagger Docs | <http://localhost:82> | - |
| - Public API Docs | <http://localhost:82/public/> | - |
| - Admin API Docs | <http://localhost:82/admin/> | - |
| - Auth API Docs | <http://localhost:82/auth/> | - |
| - Files API Docs | <http://localhost:82/files/> | - |
| Traefik Dashboard | <http://localhost:9002> | - |
| MinIO Console | <http://localhost:9001> | minioadmin / minioadmin |
| **Grafana** | <http://localhost:3000> | admin / admin |
| **Prometheus** | <http://localhost:9090> | - |

## Available Commands

### Using Task (Recommended)

```bash
# Setup and initialization
task secrets:generate    # Generate secure passwords and secrets
task init                # Generate secrets and start all services

# Multi-service stack operations
task services:up         # Start all services with docker compose
task services:down       # Stop all services
task services:restart    # Restart all services
task services:ps         # List running services
task services:build      # Rebuild and start all services
task services:clean      # Stop portfolio services and remove volumes
                         # (preserves monitoring data)
task clean:all           # Clean everything - portfolio AND monitoring
                         # (removes all data)
task services:logs       # View logs from all services
task services:ci         # Run CI checks for all service repos

# Individual service operations
task admin-api:logs      # View admin API logs
task admin-api:stop      # Stop admin API service
task admin-api:restart   # Restart admin API service
task admin-api:rebuild   # Rebuild and restart admin API
task admin-api:ci        # Run CI checks in admin-api repo

task auth:logs           # View auth service logs
task auth:stop           # Stop auth service
task auth:restart        # Restart auth service
task auth:rebuild        # Rebuild and restart auth service
task auth:ci             # Run CI checks in auth-service repo

task files-api:logs      # View files API logs
task files-api:stop      # Stop files API service
task files-api:restart   # Restart files API service
task files-api:rebuild   # Rebuild and restart files API
task files-api:ci        # Run CI checks in files-api repo

task public-api:logs     # View public API logs
task public-api:stop     # Stop public API service
task public-api:restart  # Restart public API service
task public-api:rebuild  # Rebuild and restart public API
task public-api:ci       # Run CI checks in public-api repo

task admin-web:logs      # View admin web logs
task admin-web:stop      # Stop admin web service
task admin-web:restart   # Restart admin web service
task admin-web:rebuild   # Rebuild and restart admin web
task admin-web:ci        # Run CI checks in admin-web repo

task public-web:logs     # View public web logs
task public-web:stop     # Stop public web service
task public-web:restart  # Restart public web service
task public-web:rebuild  # Rebuild and restart public web
task public-web:ci       # Run CI checks in public-web repo

# Monitoring stack (optional)
task monitoring:up       # Start observability stack
                         # (Grafana, Prometheus, Loki, OTEL)
task monitoring:down     # Stop observability stack
task monitoring:restart  # Restart monitoring stack
task monitoring:ps       # List monitoring stack services
task monitoring:logs     # View monitoring stack logs
task monitoring:clean    # Stop monitoring and remove volumes (deletes metrics/logs)
task monitoring:status   # Check health of monitoring services
task monitoring:open     # Open Grafana in browser
task monitoring:targets  # Open Prometheus targets page

# E2E Testing
task e2e:setup           # Setup E2E testing environment (install dependencies)
task e2e:test            # Run all E2E tests (browser visible)
task e2e:test:headless   # Run all E2E tests in headless mode
task e2e:ci              # Run E2E tests for CI (headless + linting)

# CI/CD tasks
task ci:all              # Run all CI checks
task ci:validate         # Validate docker-compose configuration
task ci:lint-yaml        # Lint YAML files
task ci:lint-shell       # Lint shell scripts
task ci:lint-python      # Lint Python scripts
task ci:lint-markdown    # Lint Markdown files
task ci:install-tools    # Install CI/CD linting tools
```

### Using Docker Compose Directly

```bash
docker-compose up -d                    # Start services
docker-compose down                     # Stop services
docker-compose logs -f [service]        # View logs
docker-compose ps                       # List services
docker-compose restart [service]        # Restart service
docker-compose up -d --build [service]  # Rebuild service
```

## Port Mapping

### Application Ports

| Port | Service |
|------|---------|
| 80 | Public web (HTTP) |
| 443 | Public web (HTTPS) |
| 81 | Admin web (HTTP) |
| 8443 | Admin web (HTTPS) |
| 82 | Swagger documentation |
| 8082 | Public API |
| 8083 | Admin API |
| 8084 | Auth Service |
| 8085 | Files API |

### Infrastructure Ports

| Port | Service |
|------|---------|
| 5432 | PostgreSQL |
| 6379 | Redis |
| 9000 | MinIO API |
| 9001 | MinIO Console |
| 9002 | Traefik Dashboard |

### Observability Ports

| Port | Service |
|------|---------|
| 3000 | Grafana |
| 9090 | Prometheus |
| 3100 | Loki |
| 4317 | OTEL Collector (gRPC) |
| 4318 | OTEL Collector (HTTP) |
| 8888 | OTEL Collector Metrics |
| 9464 | OTEL Collector Prometheus Exporter |

## Configuration

### Environment Variables

**Important**: All environment variables are required. The
docker-compose.yml file has **no default values** - you must configure
all variables in the `.env` file.

#### Automatic Generation (Recommended)

Use the secret generation script to automatically create secure credentials:

```bash
task secrets:generate
```

This will:

- Read `.env.example` as a template
- Generate cryptographically secure passwords and secrets
- Create `.env` with all required variables
- Create `.secrets.txt` as a backup reference

#### Manual Configuration

1. Copy the example environment file:

```bash
cp .env.example .env
```

1. Review and update `.env` with your settings. The example file
   contains development-safe defaults:

```env
# Database Connection
POSTGRES_DB=portfolio
DB_HOST=postgres
DB_PORT=5432

# PostgreSQL Superuser (for database creation)
POSTGRES_SUPERUSER=postgres
POSTGRES_SUPERUSER_PASSWORD=postgres_pass

# Flyway Migration User (DDL rights - creates/alters tables)
FLYWAY_USER=portfolio_owner
FLYWAY_PASSWORD=portfolio_owner_dev_pass
FLYWAY_BASELINE_ON_MIGRATE=true
FLYWAY_LOCATIONS=filesystem:/flyway/sql,filesystem:/flyway/seeds

# Application API User (CRUD rights - used by services)
DB_USER=portfolio_admin
DB_PASSWORD=portfolio_admin_dev_pass

# Read-Only User (SELECT only - used by public API)
DB_USER_READONLY=portfolio_public
DB_PASSWORD_READONLY=portfolio_public_dev_pass

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis_dev_pass

# MinIO (S3-compatible storage)
# Root user for MinIO administration
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# Service account for files-api (limited to bucket operations only)
S3_ACCESS_KEY=files-api-user
S3_SECRET_KEY=files-api-secret-change-in-production

S3_ENDPOINT=http://minio:9000
S3_BUCKET=images
S3_USE_SSL=false

# JWT
JWT_SECRET=your-secret-key-change-in-production
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=168h

# SSL/TLS Certificates
TRAEFIK_CERT_DIR=./docker/traefik/certs
TLS_CERT_FILE=localhost.crt
TLS_KEY_FILE=localhost.key

# Environment
ENVIRONMENT=development

# Logging Configuration (for all services)
LOG_LEVEL=info              # debug, info, warn, error
LOG_FORMAT=json             # json (for Loki), text (human-readable)
LOG_SOURCE=false            # true = add file:line (dev only)

# Service Ports
AUTH_SERVICE_PORT=8084
PUBLIC_API_PORT=8082
ADMIN_API_PORT=8083
FILES_API_PORT=8085

# Service URLs (internal Docker network)
AUTH_SERVICE_URL=http://auth-service:8084
FILES_API_URL=http://files-api:8085

# File Upload Configuration
MAX_FILE_SIZE=10485760
ALLOWED_FILE_TYPES=image/jpeg,image/jpg,image/png,image/gif,image/webp,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/msword

# Web Frontend Build Args
# Public Web
VITE_PUBLIC_API_URL=https://localhost/api/v1
VITE_PUBLIC_USE_MOCK_DATA=false

# Admin Web
VITE_ADMIN_API_URL=https://localhost:8443/admin-api/v1
VITE_ADMIN_AUTH_URL=https://localhost:8443/auth/v1
```

**Important for Production**:

- Change all passwords and secrets
- Use strong random values for `JWT_SECRET`
- Update service URLs to production hostnames
- Enable SSL (`S3_USE_SSL=true`) for MinIO if using HTTPS
- Adjust JWT expiry times based on security requirements

### SSL/TLS Certificates

Certificate paths are configurable via environment variables:

- `TRAEFIK_CERT_DIR` - Directory containing certificates
  (default: `./docker/traefik/certs`)
- `TLS_CERT_FILE` - Certificate filename (default: `localhost.crt`)
- `TLS_KEY_FILE` - Private key filename
  (default: `localhost.key`)

For local development, self-signed certificates are in
`docker/traefik/certs/`. See
[docker/traefik/certs/README.md](docker/traefik/certs/README.md)
for generation instructions.

For production, configure Let's Encrypt in
[docker-compose.yml](docker-compose.yml) or point
`TRAEFIK_CERT_DIR` to your production certificates.

### Database Migrations

Migrations run automatically on startup via Flyway from
`../database/migrations/` and `../database/seeds/`.

### Resource Limits

All services have memory limits configured:

- **Infrastructure** (Traefik, Postgres, Redis, MinIO): 128M-512M
- **Go services** (APIs): 256M limit, 128M reserved
- **Web services** (Vue apps): 128M limit, 64M reserved

Adjust in `docker-compose.yml` if needed for your environment.

### Docker Compose Override

For personal development settings, create `docker-compose.override.yml`:

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
```

This file is gitignored and loaded automatically. Use it for:

- Custom port mappings
- Volume mounts for hot reload
- Debug settings
- Resource limit overrides

## Development

### Mock Data Mode (Public Web)

The public-web service can use mock data for development, controlled
via the `VITE_PUBLIC_USE_MOCK_DATA` environment variable in `.env`:

```env
VITE_PUBLIC_USE_MOCK_DATA=false  # Use real API
VITE_PUBLIC_USE_MOCK_DATA=true   # Use mock data (no backend needed)
```

**To toggle between mock and real data:**

1. Update `VITE_PUBLIC_USE_MOCK_DATA` in `.env`
1. Rebuild the public-web service: `task public-web:rebuild` or
   `docker-compose up -d --build public-web`

**Note**: Mock data mode is useful for frontend development without
running the backend services.

### Local Development Without Docker

For local development without Docker:

1. Start only infrastructure services:

```bash
docker-compose up -d postgres redis minio flyway
```

1. Run each application service locally (see individual service READMEs)

## E2E Testing

End-to-end tests are available in the `../e2e-tests/` directory using
Playwright with Python.

### Running E2E Tests

```bash
# First-time setup
task e2e:setup

# Start all services (if not already running)
task services:up

# Run tests (browser visible)
task e2e:test

# Run tests in headless mode (faster)
task e2e:test:headless
```

### Available Test Suites

- **Profile Management** - Profile CRUD operations
- **Skills CRUD** - Skills management
- **Work Experience CRUD** - Experience management
- **Certifications CRUD** - Certifications/education management
- **Miniatures CRUD** - Projects, themes, and paints management

### E2E Test Requirements

E2E tests require:

- Python 3.12+
- Running services (admin-web on port 81, admin-api on 8083)
- Valid admin credentials in `../e2e-tests/.env`

See [../e2e-tests/README.md](../e2e-tests/README.md) for detailed
documentation.

## Troubleshooting

### Access PostgreSQL

```bash
# As superuser
docker exec -it postgres psql -U postgres -d portfolio

# As admin user
docker exec -it postgres psql -U portfolio_admin -d portfolio

# As read-only user
docker exec -it postgres psql -U portfolio_public -d portfolio
```

### Access Redis CLI

```bash
docker exec -it redis redis-cli
```

### Clean restart

```bash
# Clean portfolio services only (preserves monitoring data)
task services:clean
task services:up

# Or clean everything including monitoring
task clean:all
task services:up
task monitoring:up
```

## Persistent Data

### Portfolio Service Volumes

- `postgres_data` - Database
- `redis_data` - Cache
- `minio_data` - Object storage

### Monitoring Volumes

- `prometheus_data` - Metrics history
- `grafana_data` - Dashboards and settings
- `loki_data` - Log aggregation data

**Note**: Use `task services:clean` to clean portfolio volumes while
preserving monitoring data. Use `task monitoring:clean` to clean monitoring
volumes separately.

## License

MIT
