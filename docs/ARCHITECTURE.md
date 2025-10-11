# Portfolio Project Architecture

## Overview

This document describes the architecture of the portfolio project, a microservices-based application with separate public and admin portals.

## System Architecture Diagram

```
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
│ (Vue.js)        │      │  (Vue.js + Auth)   │    │  (Swagger)           │
│ Port: :8080     │      │  Port: :8081       │    │  Port: :82           │
└────────┬────────┘      └─────────┬──────────┘    └──────────────────────┘
         │                         │
         │ /api/v1/*               │ /api/v1/* & /auth/v1/*
         │                         │
┌────────▼────────────────┬────────▼──────────────────┐
│  Public API (Go)        │  Admin API (Go)           │
│  Internal: :8082        │  Internal: :8083          │
│  + Read-only            │  + Full CRUD + Auth       │
│  + Swagger Docs         │  + Swagger Docs           │
└────────┬────────────────┴────────┬──────────────────┘
         │                         │
         │              ┌──────────▼───────────────┐
         │              │  Auth Service (Go)       │
         │              │  Internal: :8084         │
         │              │  + JWT Tokens            │
         │              │  + Refresh Tokens        │
         │              └──────────┬───────────────┘
         │                         │
┌────────▼─────────────────────────▼───────────────────┐
│              Data & Cache Layer                      │
├──────────────────────────┬───────────────────────────┤
│  PostgreSQL 18           │  Redis 7.4                │
│  Port: :5432             │  Port: :6379              │
│  + Flyway Migrations     │  + Session Storage        │
│  + Auto Schema Mgmt      │  + Token Blacklist        │
└──────────────────────────┴───────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────┐
│              Storage Layer                           │
│  MinIO (S3-compatible)                               │
│  Port: :9000 (API), :9001 (Console)                  │
│  + Image Storage                                     │
│  + Project Assets                                    │
└──────────────────────────────────────────────────────┘
```

## Component Details

### Reverse Proxy Layer

#### Traefik
- **Ports**: 80 (HTTP), 443 (HTTPS), 81 (Admin HTTP), 8443 (Admin HTTPS), 82 (Swagger), 9002 (Dashboard)
- **Purpose**: Reverse proxy, load balancer, SSL/TLS termination
- **Features**:
  - Path-based routing
  - Automatic service discovery via Docker labels
  - Multiple entrypoints (public, admin, docs)
  - Self-signed certificates (dev) / Let's Encrypt (prod)
  - Dashboard for monitoring

### Frontend Layer

#### Public Web
- **Technology**: Vue 3, Vite, TailwindCSS, DaisyUI, Pinia, Vue Router, Axios
- **Port**: 8080 (internal), 80/443 (external via Traefik)
- **Purpose**: Public-facing portfolio website
- **Features**:
  - Browse projects
  - View skills, experience, certifications
  - Responsive design
  - Static content display

#### Admin Web
- **Technology**: Vue 3, Vite, TailwindCSS, DaisyUI, Pinia, Vue Router, Axios
- **Port**: 8081 (internal), 81/8443 (external via Traefik)
- **Purpose**: Admin panel for content management
- **Features**:
  - User authentication (login/logout)
  - Protected routes with navigation guards
  - Full CRUD operations
  - Image upload
  - Token refresh handling

### Backend Layer

#### Public API
- **Technology**: Go 1.25, Gin, GORM
- **Port**: 8082
- **Purpose**: Serve public portfolio content (read-only)
- **Authentication**: None
- **Endpoints**:
  - GET /health
  - GET /api/v1/projects
  - GET /api/v1/projects/:id
  - GET /api/v1/skills
  - GET /api/v1/experience
  - GET /api/v1/certifications
- **Integration**: PostgreSQL for data, MinIO for images

#### Admin API
- **Technology**: Go 1.25, Gin, GORM
- **Port**: 8083
- **Purpose**: Manage portfolio content (full CRUD)
- **Authentication**: JWT validation via middleware
- **Endpoints**:
  - GET /health
  - Full CRUD for projects, skills, experience, certifications
  - POST /api/v1/images/upload
- **Integration**: PostgreSQL for data, MinIO for uploads, Auth Service for validation

#### Auth Service
- **Technology**: Go 1.25, Gin, GORM, JWT, bcrypt
- **Port**: 8084
- **Purpose**: User authentication and token management
- **Endpoints**:
  - POST /api/v1/auth/register
  - POST /api/v1/auth/login
  - POST /api/v1/auth/refresh
  - POST /api/v1/auth/logout
- **Features**:
  - JWT access tokens (15min expiry)
  - JWT refresh tokens (7 days expiry)
  - Bcrypt password hashing
  - Redis session storage
  - Token blacklisting

### Data Layer

#### PostgreSQL
- **Version**: 18-alpine
- **Port**: 5432
- **Purpose**: Primary relational database
- **Tables**:
  - users (authentication)
  - profile (portfolio info)
  - work_experience
  - certifications
  - miniature_projects
  - images (metadata)
- **Migration**: Flyway (automatic on startup)

#### Redis
- **Version**: 7.4-alpine
- **Port**: 6379
- **Purpose**: Cache and session store
- **Usage**:
  - Auth tokens and sessions
  - Token blacklist (logout)
  - Future: API response caching

#### MinIO
- **Port**: 9000 (API), 9001 (Console)
- **Purpose**: S3-compatible object storage
- **Usage**:
  - Project images
  - Avatar images
  - Static assets
- **Credentials**: minioadmin / minioadmin (change in production)

## Data Flow Diagrams

### Public Content Access Flow
```
┌──────┐      ┌─────────┐      ┌────────┐      ┌──────────┐      ┌──────────┐
│ User │─────►│ Traefik │─────►│ Public │─────►│ Public   │─────►│PostgreSQL│
│      │      │         │      │  Web   │      │   API    │      │          │
└──────┘      └─────────┘      └────────┘      └────┬─────┘      └──────────┘
                                                     │
                                                     │ (images)
                                                     ▼
                                               ┌──────────┐
                                               │  MinIO   │
                                               └──────────┘
```

### Admin Content Management Flow
```
┌──────┐   ┌─────────┐   ┌────────┐   ┌──────────┐   ┌──────────┐
│Admin │──►│ Traefik │──►│ Admin  │──►│   Auth   │──►│  Redis   │
│ User │   │         │   │  Web   │   │ Service  │   │(sessions)│
└──────┘   └─────────┘   └────┬───┘   └──────────┘   └──────────┘
                              │            │
                              │ (JWT)      │ (validates)
                              ▼            │
                         ┌──────────┐      │
                         │  Admin   │◄─────┘
                         │   API    │
                         └────┬─────┘
                              │
                ┌─────────────┴──────────────┐
                ▼                            ▼
          ┌──────────┐                 ┌──────────┐
          │PostgreSQL│                 │  MinIO   │
          │  (CRUD)  │                 │(uploads) │
          └──────────┘                 └──────────┘
```

### Authentication Flow
```
1. Login Request
   Admin Web → Auth Service → PostgreSQL (verify user)
                            → Redis (create session)
                            → Admin Web (return JWT tokens)

2. API Request with Auth
   Admin Web → Admin API (with JWT header)
              → (JWT validation via middleware)
              → PostgreSQL (perform operation)
              → Admin Web (response)

3. Token Refresh
   Admin Web → Auth Service (refresh token)
              → Redis (verify session)
              → Admin Web (new access token)

4. Logout
   Admin Web → Auth Service → Redis (blacklist token)
```

## Network Architecture

All services run in a Docker bridge network named `network`.

### Port Mapping

| Service | Internal | External | Access |
|---------|----------|----------|--------|
| **Public Facing** |
| Public Web | 80 | 80 | HTTP |
| Public Web | 443 | 443 | HTTPS |
| Admin Web | 80 | 81 | HTTP |
| Admin Web | 443 | 8443 | HTTPS |
| Swagger Docs | - | 82 | HTTP |
| **Internal Services** |
| Public API | 8082 | 8082 | Direct (dev) |
| Admin API | 8083 | 8083 | Direct (dev) |
| Auth Service | 8084 | 8084 | Direct (dev) |
| **Infrastructure** |
| PostgreSQL | 5432 | 5432 | TCP |
| Redis | 6379 | 6379 | TCP |
| MinIO API | 9000 | 9000 | HTTP |
| MinIO Console | 9001 | 9001 | HTTP |
| Traefik Dashboard | 8080 | 9002 | HTTP |

## Security Architecture

### Authentication & Authorization
- **JWT-based authentication**
  - Access tokens: 15 minutes expiry
  - Refresh tokens: 7 days expiry
  - Signed with configurable secret
- **Password security**
  - Bcrypt hashing with automatic salt
  - No plain text storage
- **Session management**
  - Redis-based session store
  - Token blacklist on logout
- **Route protection**
  - Admin API middleware validates JWT
  - Admin Web navigation guards
  - 401 responses for unauthorized access

### Network Security
- Internal service communication via Docker network
- External access only through Traefik
- SSL/TLS termination at reverse proxy
- Environment-based secrets

### Data Security
- Database credentials in environment variables
- S3/MinIO access keys configurable
- Secrets must be changed for production

## Service Dependencies

Startup order and dependencies:

```
1. Infrastructure Layer
   ├── PostgreSQL (no dependencies)
   ├── Redis (no dependencies)
   └── MinIO (no dependencies)

2. Migration Layer
   └── Flyway (waits for PostgreSQL health check)

3. Backend Services
   ├── Auth Service (depends on PostgreSQL, Redis)
   ├── Public API (depends on PostgreSQL, MinIO, Flyway)
   └── Admin API (depends on PostgreSQL, MinIO, Auth Service, Flyway)

4. Frontend Services
   ├── Public Web (depends on Public API)
   └── Admin Web (depends on Admin API, Auth Service)

5. Reverse Proxy
   └── Traefik (depends on all services)
```

## Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Frontend** | Vue 3, Vite, TailwindCSS, DaisyUI, Axios, Pinia, Vue Router |
| **Backend** | Go 1.25, Gin, GORM, JWT, bcrypt |
| **Database** | PostgreSQL 18 |
| **Cache** | Redis 7.4 |
| **Storage** | MinIO (S3-compatible) |
| **Proxy** | Traefik (latest) |
| **Migrations** | Flyway 11 |
| **Container** | Docker, Docker Compose |
| **Task Runner** | Task (Taskfile) |
| **Documentation** | Swagger/OpenAPI |

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
- API rate limiting (Traefik middleware)
- Response caching layer (Redis)
- CDN for static assets
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
- Rate limiting enabled
- Health checks and monitoring
- Automated backups
- Log aggregation
- CDN for static content

## API Documentation

Swagger UI available for all backend services:

- **Public API**: http://localhost:82/public/
- **Admin API**: http://localhost:82/admin/
- **Auth Service**: http://localhost:82/auth/

Each service generates its own OpenAPI 3.0 specification.

## Health Checks

All services implement health endpoints:

- **Endpoint**: `GET /health`
- **Response**: `200 OK` if healthy

Docker Compose health checks:
- PostgreSQL: `pg_isready -U portfolio_user -d portfolio`
- Redis: `redis-cli ping`
- MinIO: HTTP probe to `/minio/health/live`

## License

MIT
