# Portfolio Project Architecture

## Overview

This document describes the architecture of the portfolio project,
a microservices-based application with separate public and admin
portals.

## System Architecture Diagram

```text
                         ┌─────────────────────┐
                         │   Traefik Proxy     │
                         │   :80, :443, :81    │
                         │   :8443, :82, :9002 │
                         │   + SSL/TLS         │
                         │   + Path Routing    │
                         └──────────┬──────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                           │
┌────────▼────────┐      ┌─────────▼──────────┐    ┌──────────▼───────────┐
│ Public Web      │      │  Admin Web         │    │  API Documentation   │
│ (Vue 3)         │      │  (Vue 3 + Auth)    │    │  (Swagger)           │
│ Port: :8080     │      │  Port: :8081       │    │  Port: :82           │
└────────┬────────┘      └─────────┬──────────┘    └──────────────────────┘
         │                         │
         │ /api/v1/*               │ /api/v1/* & /auth/v1/* & /files/*
         │                         │
┌────────▼────────────────┬────────▼────────────┬─────────────────────────┐
│  Public API (Go)        │  Admin API (Go)     │  Files API (Go)         │
│  Internal: :8082        │  Internal: :8083    │  Internal: :8085        │
│  + Read-only (SELECT)   │  + Full CRUD        │  + File Upload/Download │
│  + Swagger Docs         │  + Validates JWT    │  + Validates JWT        │
└────────┬────────────────┴────────┬────────────┴─────────┬───────────────┘
         │                         │                       │
         │              ┌──────────▼───────────────────────▼────┐
         │              │  Auth Service (Go)                    │
         │              │  Internal: :8084                      │
         │              │  + JWT Signing & Validation           │
         │              │  + Access Tokens (15m)                │
         │              │  + Refresh Tokens (7d)                │
         │              └──────────┬────────────────────────────┘
         │                         │
┌────────▼─────────────────────────▼───────────────────┐
│              Data & Cache Layer                      │
├──────────────────────────┬───────────────────────────┤
│  PostgreSQL 18           │  Redis 8.2                │
│  Port: :5432             │  Port: :6379              │
│  + Flyway Migrations     │  + Session Storage        │
│  + Role-based Access:    │  + Token Blacklist        │
│    - portfolio_owner     │                           │
│    - portfolio_admin     │                           │
│    - portfolio_public    │                           │
└──────────────────────────┴───────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────┐
│              Storage Layer                           │
│  MinIO (S3-compatible)                               │
│  Port: :9000 (API), :9001 (Console)                  │
│  + File Storage (images, documents)                  │
│  + Bucket: images                                    │
└──────────────────────────────────────────────────────┘
```

## Component Details

### Reverse Proxy Layer

#### Traefik

- **Ports**: 80 (HTTP), 443 (HTTPS), 81 (Admin HTTP), 8443 (Admin
  HTTPS), 82 (Swagger), 9002 (Dashboard)
- **Purpose**: Reverse proxy, load balancer, SSL/TLS termination
- **Features**:
  - Path-based routing
  - Automatic service discovery via Docker labels
  - Multiple entrypoints (public, admin, docs)
  - Self-signed certificates (dev) / Let's Encrypt (prod)
  - Dashboard for monitoring

### Frontend Layer

#### Public Web

- **Technology**: Vue 3, Vite, Naive UI, Pinia, Vue Router, Axios
- **Port**: 8080 (internal), 80/443 (external via Traefik)
- **Purpose**: Public-facing portfolio website
- **Features**:
  - Browse projects and miniatures
  - View skills, experience, certifications
  - Responsive design
  - Mock data mode for development
  - Static content display

#### Admin Web

- **Technology**: Vue 3, Vite, Naive UI, Pinia, Vue Router, Axios
- **Port**: 8081 (internal), 81/8443 (external via Traefik)
- **Purpose**: Admin panel for content management
- **Features**:
  - User authentication (login/logout)
  - Protected routes with navigation guards
  - Full CRUD operations
  - File upload via Files API
  - Token refresh handling

### Backend Layer

#### Public API

- **Technology**: Go 1.25, Gin, GORM
- **Port**: 8082
- **Purpose**: Serve public portfolio content (read-only)
- **Database User**: portfolio_public (SELECT only)
- **Authentication**: None
- **Endpoints**:
  - GET /health
  - GET /api/v1/profile
  - GET /api/v1/projects
  - GET /api/v1/skills
  - GET /api/v1/experience
  - GET /api/v1/certifications
  - GET /api/v1/miniatures
- **Integration**: PostgreSQL for data, Files API for file URLs

#### Admin API

- **Technology**: Go 1.25, Gin, GORM
- **Port**: 8083
- **Purpose**: Manage portfolio content (full CRUD)
- **Database User**: portfolio_admin (full CRUD)
- **Authentication**: JWT validation via Auth Service
- **Endpoints**:
  - GET /health
  - Full CRUD for projects, skills, experience, certifications,
    miniatures
- **Integration**: PostgreSQL for data, MinIO for S3 uploads,
  Auth Service for JWT validation

#### Files API

- **Technology**: Go 1.25, Gin, GORM, MinIO SDK
- **Port**: 8085
- **Purpose**: File upload/download service
- **Database User**: portfolio_admin (write access to storage.files)
- **Authentication**: JWT validation via Auth Service (upload/delete only)
- **Endpoints**:
  - GET /api/v1/health
  - GET /api/v1/files/:fileType/*key (public download)
  - POST /api/v1/files (protected upload)
  - DELETE /api/v1/files/:id (protected delete)
- **File Types**: portfolio-image, miniature-image,
  document
- **Max Upload**: 10MB (configurable)
- **Allowed Types**: JPEG, PNG, GIF, WebP, PDF
- **Integration**: PostgreSQL for metadata, MinIO for storage,
  Auth Service for JWT validation

#### Auth Service

- **Technology**: Go 1.25, Gin, GORM, JWT, bcrypt
- **Port**: 8084
- **Purpose**: User authentication and token management
- **Database User**: portfolio_admin (access to auth.users)
- **Endpoints**:
  - POST /api/v1/auth/register
  - POST /api/v1/auth/login
  - POST /api/v1/auth/refresh
  - POST /api/v1/auth/logout
  - POST /api/v1/auth/validate (for other services)
- **Features**:
  - JWT access tokens (15min expiry, configurable)
  - JWT refresh tokens (168h/7 days expiry, configurable)
  - Bcrypt password hashing
  - Redis session storage
  - Token blacklisting
  - Centralized JWT validation endpoint

### Data Layer

#### PostgreSQL

- **Version**: 18-alpine
- **Port**: 5432
- **Purpose**: Primary relational database
- **Database Users (Role-based Access Control)**:
  - **postgres** - Superuser (database creation)
  - **portfolio_owner** - DDL operations (CREATE, ALTER, DROP) -
    used by Flyway
  - **portfolio_admin** - CRUD operations (SELECT, INSERT, UPDATE,
    DELETE) - used by APIs
  - **portfolio_public** - SELECT only - used by Public API
    (extra security)
- **Schemas**:
  - **auth** - User authentication (users table)
  - **portfolio** - Portfolio content (profile, work_experience,
    certifications, portfolio_projects, skills)
  - **miniatures** - Miniature painting projects (miniature_themes,
    miniature_projects, miniature_paints, etc.)
  - **storage** - File metadata (files table)
  - **audit** - Change tracking (change_log, query_stats)
- **Migration**: Flyway (automatic on startup, versioned + repeatable)

#### Redis

- **Version**: 8.2-alpine
- **Port**: 6379
- **Purpose**: Cache and session store
- **Usage**:
  - Auth tokens and sessions
  - Token blacklist (logout)
  - Future: API response caching

#### MinIO

- **Version**: Latest (S3-compatible)
- **Port**: 9000 (API), 9001 (Console)
- **Purpose**: S3-compatible object storage
- **Bucket**: images (for portfolio and miniature images)
- **Usage**:
  - Portfolio project images
  - Miniature painting photos
  - Document storage (PDFs, CVs)
- **Credentials**: Configurable via environment variables (change for production)

## Data Flow Diagrams

### Public Content Access Flow

```text
┌──────┐      ┌─────────┐      ┌────────┐      ┌──────────┐      ┌──────────┐
│ User │─────►│ Traefik │─────►│ Public │─────►│ Public   │─────►│PostgreSQL│
│      │      │         │      │  Web   │      │   API    │      │(SELECT)  │
└──────┘      └─────────┘      └────────┘      └────┬─────┘      └──────────┘
                                                     │
                                                     │ (file URLs)
                                                     ▼
                                               ┌──────────┐      ┌──────────┐
                                               │  Files   │─────►│  MinIO   │
                                               │   API    │      │(download)│
                                               └──────────┘      └──────────┘
```

### Admin Content Management Flow

```text
┌──────┐   ┌─────────┐   ┌────────┐   ┌──────────┐   ┌──────────┐
│Admin │──►│ Traefik │──►│ Admin  │──►│   Auth   │──►│  Redis   │
│ User │   │         │   │  Web   │   │ Service  │   │(sessions)│
└──────┘   └─────────┘   └────┬───┘   └────┬─────┘   └──────────┘
                              │            │
                              │ (JWT)      │ (returns JWT)
                              ▼            │
                         ┌──────────┐      │
                         │  Admin   │◄─────┘ (validates JWT)
                         │   API    │
                         └────┬─────┘
                              │
                              ▼
                        ┌──────────┐
                        │PostgreSQL│
                        │  (CRUD)  │
                        └──────────┘

### File Upload/Download Flow
┌──────┐   ┌─────────┐   ┌────────┐   ┌──────────┐   ┌──────────┐
│Admin │──►│ Traefik │──►│ Admin  │──►│  Files   │──►│   Auth   │
│ User │   │         │   │  Web   │   │   API    │   │ Service  │
└──────┘   └─────────┘   └────────┘   └────┬─────┘   └────┬─────┘
                                            │              │
                                            │◄─────────────┘ (validates JWT)
                                            │
                              ┌─────────────┴──────────────┐
                              ▼                            ▼
                        ┌──────────┐                 ┌──────────┐
                        │PostgreSQL│                 │  MinIO   │
                        │(metadata)│                 │(storage) │
                        └──────────┘                 └──────────┘
```

### Authentication Flow

```text
1. Login Request
   Admin Web → Auth Service → PostgreSQL (verify user)
                            → Redis (create session)
                            → Admin Web (return JWT access + refresh tokens)

2. API Request with Auth (Admin API or Files API)
   Admin Web → Admin/Files API (with JWT header)
              → Auth Service /api/v1/auth/validate (validate JWT)
              → Auth Service validates JWT signature
              → Admin/Files API (if valid, proceed)
              → PostgreSQL (perform operation)
              → Admin Web (response)

3. Token Refresh
   Admin Web → Auth Service (refresh token)
              → Redis (verify session)
              → Admin Web (new access token - 15min)

4. Logout
   Admin Web → Auth Service → Redis (blacklist)
                            → Admin Web (confirm)
```

**Note**: Admin API and Files API validate JWTs by calling Auth
Service's `/api/v1/auth/validate` endpoint, ensuring centralized
authentication logic.

## Network Architecture

All services run in a Docker bridge network named `network`.

### Port Mapping

| Service | Internal | External | Binding | Access |
|---------|----------|----------|---------|--------|
| **Public Facing** | | | | |
| Public Web | 80 | 80 | 0.0.0.0 | HTTP |
| Public Web | 443 | 443 | 0.0.0.0 | HTTPS |
| Admin Web | 80 | 81 | 0.0.0.0 | HTTP |
| Admin Web | 443 | 8443 | 0.0.0.0 | HTTPS |
| Swagger Docs | - | 82 | 0.0.0.0 | HTTP |
| **Internal Services** | | | | |
| Public API | 8082 | 8082 | 0.0.0.0 | Direct (dev) |
| Admin API | 8083 | 8083 | 0.0.0.0 | Direct (dev) |
| Auth Service | 8084 | 8084 | 0.0.0.0 | Direct (dev) |
| Files API | 8085 | 8085 | 0.0.0.0 | Direct (dev) |
| **Infrastructure** | | | | |
| PostgreSQL | 5432 | 5432 | 127.0.0.1 | TCP (localhost only) |
| Redis | 6379 | 6379 | 127.0.0.1 | TCP (localhost only) |
| MinIO API | 9000 | 9000 | 0.0.0.0 | HTTP |
| MinIO Console | 9001 | 9001 | 0.0.0.0 | HTTP |
| Traefik Dashboard | 8080 | 9002 | 0.0.0.0 | HTTP |

## Security Architecture

### Authentication & Authorization

- **JWT-based authentication**
  - Access tokens: 15 minutes expiry
    (configurable via JWT_ACCESS_EXPIRY)
  - Refresh tokens: 7 days/168h expiry
    (configurable via JWT_REFRESH_EXPIRY)
  - Signed with configurable JWT_SECRET
  - **Centralized validation**: Admin API and Files API validate
    tokens via Auth Service
- **Password security**
  - Bcrypt hashing with automatic salt
  - No plain text storage
- **Session management**
  - Redis-based session store
  - Token blacklist on logout
- **Route protection**
  - Admin API calls Auth Service `/api/v1/auth/validate` endpoint
  - Files API calls Auth Service `/api/v1/auth/validate` endpoint
  - Admin Web navigation guards
  - 401 responses for unauthorized access
- **Database security**
  - Role-based access control with 3 user levels:
    - portfolio_owner (DDL only)
    - portfolio_admin (CRUD operations)
    - portfolio_public (SELECT only)

### Network Security

- Internal service communication via Docker network
- External access only through Traefik
- SSL/TLS termination at reverse proxy
- PostgreSQL and Redis bound to localhost only (127.0.0.1) — inaccessible from
  external networks
- Container security hardening:
  - Traefik: no-new-privileges, capabilities dropped except
    NET_BIND_SERVICE
  - Redis: no-new-privileges, capabilities dropped except SETUID/SETGID/CHOWN
- Environment-based secrets

### Data Security

- Database credentials in environment variables
- S3/MinIO access keys configurable
- Secrets must be changed for production

## Service Dependencies

Startup order and dependencies:

```text
1. Infrastructure Layer
   ├── PostgreSQL (no dependencies)
   ├── Redis (no dependencies)
   └── MinIO (no dependencies)

2. Migration Layer
   └── Flyway (waits for PostgreSQL health check)

3. Backend Services
   ├── Auth Service (depends on PostgreSQL, Redis, Flyway)
   ├── Public API (depends on PostgreSQL, Flyway)
   ├── Admin API (depends on PostgreSQL, Auth Service, Flyway)
   └── Files API (depends on PostgreSQL, MinIO, Auth Service, Flyway)

4. Frontend Services
   ├── Public Web (depends on Public API)
   └── Admin Web (depends on Admin API, Auth Service)

5. Reverse Proxy
   └── Traefik (depends on all services)
```

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Frontend** | Vue 3.5, Vite 7, Naive UI 2, Axios, Pinia 3, Vue Router 4 |
| **Backend** | Go 1.24.5, Gin 1.11, GORM 1.31, JWT v5, bcrypt |
| **Database** | PostgreSQL 18-alpine |
| **Cache** | Redis 8.2-alpine |
| **Storage** | MinIO (S3-compatible, SDK v7) |
| **Proxy** | Traefik v3.6.1 |
| **Migrations** | Flyway 11.1.0 |
| **Observability** | Prometheus v3.7.3, Loki 3.6.0, Grafana 12.2.1, OTel |
| **Container** | Docker, Docker Compose |
| **Task Runner** | Task (Taskfile) |
| **Documentation** | Swagger/OpenAPI 3.0 |

## Scalability Considerations

### Current Architecture

- Stateless API services (horizontally scalable)
- Shared session store (Redis)
- Centralized object storage (MinIO)
- Single database instance

### Horizontal Scaling Options

- Multiple API service instances behind Traefik
- Load balancing via Traefik
- Redis cluster for session replication
- MinIO distributed mode

### Vertical Scaling Options

- Increase PostgreSQL resources
- Increase Redis memory
- Expand MinIO storage

### Future Improvements

- Database read replicas for read-heavy loads
- Response caching layer (Redis)
- Monitoring (Prometheus + Grafana)
- Centralized logging (ELK stack)
- Message queue for async operations
- Database connection pooling optimization

## Deployment Environments

### Development (Current)

- All services in Docker Compose
- Self-signed SSL certificates
- Hot reload for frontends
- Direct database access
- MinIO for local storage
- Default credentials

### Production Considerations

- Enable Let's Encrypt for SSL
- Use managed database (AWS RDS, etc.)
- Use managed Redis (AWS ElastiCache, etc.)
- Use S3 instead of MinIO
- Strong JWT secrets
- Secure passwords and credentials
- HTTP to HTTPS redirect
- WAF rate limiting (CloudFront + AWS WAF)
- Health checks and monitoring
- Automated backups
- Log aggregation
- CDN for static content

**AWS Production WAF Rate Limits** (per IP, per 5 minutes):

| Endpoint | Host | Path | Limit |
|----------|------|------|-------|
| Login | `auth.gunarsk.com` | `/login` | 20 |
| Token Refresh | `auth.gunarsk.com` | `/refresh` | 100 |
| Token Validation | `auth.gunarsk.com` | `/validate` | 300 |
| Logout | `auth.gunarsk.com` | `*/logout` | 60 |
| Admin API | `admin.gunarsk.com` | `/api/v1/*` | 1200 |
| Public API | `gunarsk.com` | `/api/v1/*` | 600 |
| Files API | `files.gunarsk.com` | `/api/v1/*` | 200 |

## API Documentation

Swagger UI available for all backend services:

- **Public API**: <http://localhost:82/public/>
- **Admin API**: <http://localhost:82/admin/>
- **Auth Service**: <http://localhost:82/auth/>
- **Files API**: <http://localhost:82/files/>

Each service generates its own OpenAPI 3.0 specification via Swaggo.

## Health Checks

All services implement health endpoints:

- **Endpoint**: `GET /api/v1/health`
- **Response**: `200 OK` if healthy

Docker Compose health checks:

- PostgreSQL: `pg_isready -U postgres -d portfolio`
- Redis: `redis-cli ping`
- MinIO: HTTP probe to `/minio/health/live`
- Auth Service: HTTP probe to `http://localhost:8084/api/v1/health`
- Public API: HTTP probe to `http://localhost:8082/api/v1/health`
- Admin API: HTTP probe to `http://localhost:8083/api/v1/health`
- Files API: HTTP probe to `http://localhost:8085/api/v1/health`

## License

MIT
