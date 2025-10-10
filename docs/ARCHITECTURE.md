# Portfolio Microservices Architecture

## System Overview

This is a microservices-based portfolio management system with separate public-facing and admin portals.

## Services Architecture

```
                         ┌─────────────────────┐
                         │   Traefik Proxy     │
                         │   Port: 80, 81, 82  │
                         │   + Rate Limiting   │
                         │   + Path Routing    │
                         └──────────┬──────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                           │
┌────────▼────────┐      ┌─────────▼──────────┐    ┌──────────▼───────────┐
│ Public Web      │      │  Admin Web         │    │  API Documentation   │
│ (Vue.js)        │      │  (Vue.js + Auth)   │    │  (Swagger)           │
│ Port: 80        │      │  Port: 81          │    │  Port: 82            │
└────────┬────────┘      └─────────┬──────────┘    └──────────────────────┘
         │                         │
         │ /api/v1/*               │ /api/v1/* & /auth/*
         │                         │
┌────────▼────────────────┬────────▼──────────────────┐
│  Public API (Go)        │  Admin API (Go)           │
│  Internal: 8082         │  Internal: 8083           │
│  + Swagger Docs         │  + Swagger Docs + Auth    │
└────────┬────────────────┴────────┬──────────────────┘
         │                         │
         │              ┌──────────▼───────────────┐
         │              │  Auth Service (Go)       │
         │              │  Internal: 8084          │
         │              │  + JWT Token Management  │
         │              └──────────┬───────────────┘
         │                         │
┌────────▼─────────────────────────▼───────────────────┐
│              Data & Cache Layer                      │
├──────────────────────────┬───────────────────────────┤
│  PostgreSQL 18           │  Redis 7.4                │
│  Port: 5432              │  Port: 6379               │
│  + Flyway Migrations     │  + Session Storage        │
└──────────────────────────┴───────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────┐
│              Storage Layer                           │
│  MinIO (Local) / S3 (AWS)                            │
│  Port: 9000 (MinIO API), 9001 (Console)              │
│  + Image Storage                                     │
└──────────────────────────────────────────────────────┘
```

## Repository Structure

All repositories under organization: **GunarsK-portfolio**

1. **public-web** - Public Vue.js portfolio
2. **public-api** - Public-facing REST API (Go)
3. **admin-web** - Admin content management portal (Vue.js)
4. **admin-api** - Admin REST API with auth (Go)
5. **auth-service** - Authentication provider (Go)
6. **database** - Database migrations, schemas, and seed data (Flyway)
7. **infrastructure** - Infrastructure as Code, docs, docker-compose

## Technology Stack

### Frontend
- **Framework**: Vue.js 3 (Composition API)
- **Build Tool**: Vite
- **HTTP Client**: Axios
- **State Management**: Pinia
- **Router**: Vue Router
- **UI Framework**: Tailwind CSS + DaisyUI

### Backend
- **Language**: Go 1.25+
- **Web Framework**: Gin
- **ORM**: GORM
- **Auth**: JWT tokens (golang-jwt/jwt)
- **API Docs**: Swagger (swaggo/swag)
- **Database Driver**: pgx
- **Task Runner**: Task (Taskfile)

### Data Layer
- **Database**: PostgreSQL 18+
- **Migration Tool**: Flyway (timestamp-based migrations)
- **Cache**: Redis 7.4+
- **Object Storage**: MinIO (local) / AWS S3 (production)

### Infrastructure
- **Container Runtime**: Docker / Docker Compose
- **Reverse Proxy**: Traefik v3.5+ (auto-discovery, rate limiting)
- **Cloud Provider**: AWS
- **CI/CD**: GitHub Actions

## Port Allocation

### External Access (via Traefik)

| Service | Port | Routes | Description |
|---------|------|--------|-------------|
| **Public Portfolio** | 80 | `/` → public-web<br>`/api/v1/*` → public-api | Main website + API |
| **Admin Portal** | 81 | `/` → admin-web<br>`/api/v1/*` → admin-api<br>`/auth/*` → auth-service | Admin dashboard + APIs |
| **API Documentation** | 82 | `/public/` → public-api/swagger<br>`/admin/` → admin-api/swagger<br>`/auth/` → auth-service/swagger | Swagger docs |

### Internal Services (Direct Access)

| Service | Port | Description |
|---------|------|-------------|
| Public Web | 8080 | Vue.js public portfolio (direct) |
| Admin Web | 8081 | Vue.js admin portal (direct) |
| Public API | 8082 | Go public REST API (direct) |
| Admin API | 8083 | Go admin REST API (direct) |
| Auth Service | 8084 | Go authentication service (direct) |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |
| MinIO | 9000 | Object storage (local) |
| MinIO Console | 9001 | MinIO admin console |

## Data Models

### User
```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Profile
```sql
CREATE TABLE profile (
    id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    title VARCHAR(100),
    bio TEXT,
    email VARCHAR(100),
    phone VARCHAR(20),
    location VARCHAR(100),
    avatar_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Work Experience
```sql
CREATE TABLE work_experience (
    id BIGSERIAL PRIMARY KEY,
    company VARCHAR(100) NOT NULL,
    position VARCHAR(100) NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Certifications
```sql
CREATE TABLE certifications (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    issuer VARCHAR(100) NOT NULL,
    issue_date DATE NOT NULL,
    expiry_date DATE,
    credential_id VARCHAR(100),
    credential_url VARCHAR(255),
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Miniature Projects
```sql
CREATE TABLE miniature_projects (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    completed_date DATE,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Images
```sql
CREATE TABLE images (
    id BIGSERIAL PRIMARY KEY,
    miniature_project_id BIGINT REFERENCES miniature_projects(id) ON DELETE CASCADE,
    title VARCHAR(200),
    description TEXT,
    s3_key VARCHAR(500) NOT NULL,
    s3_bucket VARCHAR(100) NOT NULL,
    url VARCHAR(500) NOT NULL,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Authentication Flow

1. Admin logs in via Admin Web → Auth Service
2. Auth Service validates credentials against PostgreSQL
3. On success, generates JWT token
4. Stores session in Redis with TTL
5. Returns JWT to client
6. Client includes JWT in Authorization header for subsequent requests
7. Admin API validates JWT with Auth Service before processing requests

## API Endpoints

### Public API (public-api)
```
GET  /api/v1/profile              - Get profile info
GET  /api/v1/experience           - List work experience
GET  /api/v1/certifications       - List certifications
GET  /api/v1/miniatures           - List miniature projects
GET  /api/v1/miniatures/:id       - Get miniature project details
GET  /api/v1/health               - Health check
GET  /swagger/*                   - Swagger documentation
```

### Admin API (admin-api)
```
POST   /api/v1/profile            - Update profile
POST   /api/v1/experience         - Create work experience
PUT    /api/v1/experience/:id     - Update work experience
DELETE /api/v1/experience/:id     - Delete work experience
POST   /api/v1/certifications     - Create certification
PUT    /api/v1/certifications/:id - Update certification
DELETE /api/v1/certifications/:id - Delete certification
POST   /api/v1/miniatures         - Create miniature project
PUT    /api/v1/miniatures/:id     - Update miniature project
DELETE /api/v1/miniatures/:id     - Delete miniature project
POST   /api/v1/images             - Upload image
DELETE /api/v1/images/:id         - Delete image
GET    /api/v1/health             - Health check
GET    /swagger/*                 - Swagger documentation
```

### Auth API (auth-service)
```
POST /api/v1/auth/login           - Login
POST /api/v1/auth/logout          - Logout
POST /api/v1/auth/refresh         - Refresh token
POST /api/v1/auth/validate        - Validate token
GET  /api/v1/health               - Health check
GET  /swagger/*                   - Swagger documentation
```

## Local Development

### Prerequisites
- Docker Desktop
- [Task](https://taskfile.dev/installation/) (task runner)
- Git
- Node.js 18+ (for local web development)
- Go 1.25+ (for local API development)

### Running Everything
```bash
# Clone infrastructure repo
git clone git@github.com:GunarsK-portfolio/infrastructure.git
cd infrastructure

# Start all services
task up

# View logs
task logs

# Stop all services
task down
```

### Running Individual Services
```bash
# Stop a service for local debugging
task stop-auth

# Rebuild and restart after code changes
task rebuild-auth

# View logs for specific service
task logs-auth
```

Each repository also has its own Taskfile.yml for local development:
```bash
cd ../auth-service
cp .env.example .env
task run  # or press F5 in VS Code to debug
```

## AWS Deployment Architecture

### Services
- **ECS/Fargate** - Container orchestration for Go APIs and Vue.js apps
- **RDS PostgreSQL** - Managed database
- **ElastiCache Redis** - Managed cache
- **S3** - Image storage
- **CloudFront** - CDN for web apps
- **Application Load Balancer** - Traffic distribution
- **Route 53** - DNS management
- **ACM** - SSL/TLS certificates
- **ECR** - Container registry
- **VPC** - Network isolation

### CI/CD Pipeline
- GitHub Actions for build and test
- Push Docker images to ECR
- Deploy to ECS via AWS CLI/Terraform

## Security Considerations

1. **JWT Tokens**: Short-lived access tokens (15 min) with refresh tokens (7 days)
2. **HTTPS Only**: All production traffic over TLS
3. **CORS**: Properly configured for web apps
4. **SQL Injection**: Use parameterized queries (GORM)
5. **Rate Limiting**: Implement on all APIs
6. **Environment Variables**: Never commit secrets
7. **S3 Bucket**: Private with signed URLs for images
8. **Database**: Encrypt at rest, secure credentials in AWS Secrets Manager

## Development Workflow

1. Create feature branch in respective repository
2. Develop and test locally with Docker Compose
3. Commit and push to GitHub
4. Open Pull Request
5. CI/CD runs tests and builds
6. Merge to main after review
7. Auto-deploy to AWS (main branch only)

## Next Steps

1. Set up GitHub organization and repositories
2. Initialize each service with proper structure
3. Set up local docker-compose for development
4. Implement core services
5. Deploy to AWS
6. Set up monitoring and logging
