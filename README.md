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
- **public-api** - Public API service
- **admin-api** - Admin API service
- **public-web** - Public frontend (Vue.js)
- **admin-web** - Admin frontend (Vue.js)

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

2. Start all services:
```bash
docker-compose up -d
```

Or using Task:
```bash
task up
```

3. Access the applications:

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
| Traefik Dashboard | http://localhost:9002 | - |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |

## Available Commands

### Using Task (Recommended)

```bash
task up              # Start all services
task down            # Stop all services
task build           # Build and start all services
task logs            # View all logs
task ps              # List running services
task restart         # Restart all services
task clean           # Stop and remove volumes
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
| 9000 | MinIO API |
| 9001 | MinIO Console |
| 9002 | Traefik Dashboard |

## Configuration

### SSL/TLS
Self-signed certificates are in `docker/traefik/certs/`. For production, configure Let's Encrypt in [docker-compose.yml](docker-compose.yml).

### Environment Variables
Key configurations in [docker-compose.yml](docker-compose.yml):
- **PostgreSQL**: `portfolio` database, `portfolio_user`, `portfolio_pass`
- **MinIO**: `minioadmin` / `minioadmin`
- **JWT Secret**: Change `JWT_SECRET` for production

### Database Migrations
Migrations run automatically on startup via Flyway from `../database/migrations/` and `../database/seeds/`.

## Development

For local development without Docker:

1. Start only infrastructure services:
```bash
docker-compose up -d postgres redis minio flyway
```

2. Run each application service locally (see individual service READMEs)

## Troubleshooting

### Access PostgreSQL
```bash
docker exec -it postgres psql -U portfolio_user -d portfolio
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
