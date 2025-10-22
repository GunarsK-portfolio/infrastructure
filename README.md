# Portfolio Infrastructure

Docker Compose orchestration for the portfolio project microservices.

## Overview

This repository contains the Docker Compose configuration and Traefik reverse proxy setup for running all portfolio services together.

## Services

- **Traefik** - Reverse proxy and load balancer
- **PostgreSQL** - Main database
- **Redis** - Session and cache store
- **MinIO** - S3-compatible object storage
- **Flyway** - Database migrations
- **auth-service** - JWT authentication service
- **public-api** - Public API service (read-only)
- **admin-api** - Admin API service (full CRUD)
- **files-api** - File upload/download service
- **public-web** - Public frontend (Vue.js + Naive UI)
- **admin-web** - Admin frontend (Vue.js + Naive UI)

## Prerequisites

- Docker and Docker Compose
- [Task](https://taskfile.dev/) (optional, for Taskfile commands)
- Clone all service repositories in the parent directory

## Repository Structure

Expected directory layout:
```
portfolio/
├── infrastructure/     # This repo
├── auth-service/       # Auth service repo
├── public-api/         # Public API repo
├── admin-api/          # Admin API repo
├── public-web/         # Public web repo
├── admin-web/          # Admin web repo
└── database/           # Database repo
```

## Quick Start

1. Ensure all service repositories are cloned in the parent directory

2. **Generate secure secrets** (recommended):
```bash
task generate-secrets
```
This creates a `.env` file with cryptographically secure passwords.

Alternatively, manually copy and edit the environment file:
```bash
cp .env.example .env
# Edit .env with your own passwords
```

3. Start all services:
```bash
task up
```

Or combine steps 2-3 with:
```bash
task init  # Generate secrets and start services
```

4. Access the applications:

| Service | URL | Credentials |
|---------|-----|-------------|
| Public Website | http://localhost | - |
| Public Website (HTTPS) | https://localhost | - |
| Admin Panel | http://localhost:81 | - |
| Admin Panel (HTTPS) | https://localhost:8443 | - |
| Swagger Docs | http://localhost:82 | - |
| - Public API Docs | http://localhost:82/public/ | - |
| - Admin API Docs | http://localhost:82/admin/ | - |
| - Auth API Docs | http://localhost:82/auth/ | - |
| - Files API Docs | http://localhost:82/files/ | - |
| Traefik Dashboard | http://localhost:9002 | - |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |

## Available Commands

### Using Task (Recommended)

```bash
# Setup and initialization
task generate-secrets    # Generate secure passwords and secrets
task init                # Generate secrets and start all services

# Service management
task up                  # Start all services
task down                # Stop all services
task build               # Build and start all services
task logs                # View all logs
task ps                  # List running services
task restart             # Restart all services
task clean               # Stop and remove volumes
```

View logs for specific services:
```bash
task logs-auth
task logs-public-api
task logs-admin-api
task logs-public-web
task logs-admin-web
task logs-db
```

Rebuild individual services:
```bash
task rebuild-auth
task rebuild-public-api
task rebuild-admin-api
task rebuild-public-web
task rebuild-admin-web
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

| Port | Service |
|------|---------|
| 80 | Public web (HTTP) |
| 443 | Public web (HTTPS) |
| 81 | Admin web (HTTP) |
| 8443 | Admin web (HTTPS) |
| 82 | Swagger documentation |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 8082 | Public API |
| 8083 | Admin API |
| 8084 | Auth Service |
| 8085 | Files API |
| 9000 | MinIO API |
| 9001 | MinIO Console |
| 9002 | Traefik Dashboard |

## Configuration

### Environment Variables

**Important**: All environment variables are required. The docker-compose.yml file has **no default values** - you must configure all variables in the `.env` file.

#### Automatic Generation (Recommended)

Use the secret generation script to automatically create secure credentials:

```bash
task generate-secrets
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

2. Review and update `.env` with your settings. The example file contains development-safe defaults:

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
- `TRAEFIK_CERT_DIR` - Directory containing certificates (default: `./docker/traefik/certs`)
- `TLS_CERT_FILE` - Certificate filename (default: `localhost.crt`)
- `TLS_KEY_FILE` - Private key filename (default: `localhost.key`)

For local development, self-signed certificates are in `docker/traefik/certs/`. See [docker/traefik/certs/README.md](docker/traefik/certs/README.md) for generation instructions.

For production, configure Let's Encrypt in [docker-compose.yml](docker-compose.yml) or point `TRAEFIK_CERT_DIR` to your production certificates.

### Database Migrations
Migrations run automatically on startup via Flyway from `../database/migrations/` and `../database/seeds/`.

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

The public-web service can use mock data for development, controlled via the `VITE_PUBLIC_USE_MOCK_DATA` environment variable in `.env`:

```env
VITE_PUBLIC_USE_MOCK_DATA=false  # Use real API
VITE_PUBLIC_USE_MOCK_DATA=true   # Use mock data (doesn't require backend)
```

**To toggle between mock and real data:**
1. Update `VITE_PUBLIC_USE_MOCK_DATA` in `.env`
2. Rebuild the public-web service: `task rebuild-public-web` or `docker-compose up -d --build public-web`

**Note**: Mock data mode is useful for frontend development without running the backend services.

### Local Development Without Docker

For local development without Docker:

1. Start only infrastructure services:
```bash
docker-compose up -d postgres redis minio flyway
```

2. Run each application service locally (see individual service READMEs)

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
docker-compose down -v  # Remove volumes
docker-compose up -d
```

## Persistent Data

Volumes:
- `postgres_data` - Database
- `redis_data` - Cache
- `minio_data` - Object storage

## License

MIT
