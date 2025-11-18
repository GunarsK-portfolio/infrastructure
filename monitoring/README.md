# Portfolio Observability Stack

Monitoring, logging, and observability for Portfolio microservices
using Prometheus, Loki, Promtail, and Grafana.

## Components

| Component | Version | Port | Purpose |
|-----------|---------|------|---------|
| **Prometheus** | v3.7.3 | 9090 | Metrics collection (30d retention) |
| **Loki** | 3.6.0 | 3100 | Log aggregation (7d retention) |
| **Promtail** | 3.6.0 | 9080 | Log shipper (⚠️ EOL Mar 2026) |
| **Grafana** | 12.2.1 | 3000 | Dashboards & visualization |
| **OTel Collector** | 0.139.0 | 4317/4318 | OTLP receiver (Claude) |
| **Postgres Exporter** | v0.18.1 | 9187 | PostgreSQL metrics |
| **Redis Exporter** | v1.80.0 | 9121 | Redis metrics |

**Grafana Credentials**: Configurable via environment variables
(default: admin / admin)

**⚠️ Important**: Promtail is deprecated and will reach End-of-Life on
March 2, 2026. For new deployments, consider migrating to
[Grafana Alloy](https://grafana.com/docs/alloy/latest/).

---

## Quick Start

### Using Taskfile

```bash
task monitoring:up      # Start stack
task monitoring:down    # Stop stack
task monitoring:restart # Restart stack
task monitoring:logs    # View logs
task monitoring:open    # Open Grafana
```

### Manual

```bash
cd infrastructure
docker-compose -f docker-compose.monitoring.yml up -d
open http://localhost:3000
```

---

## Architecture

```text
Go Services → /metrics → Prometheus ┐
             ↓ JSON logs            │
          stdout/stderr             ├→ Grafana Dashboards
             ↓                      │
          Promtail → Loki ──────────┘
```

---

## Service Integration

### 1. Update Dependencies

```bash
cd your-service
go get github.com/GunarsK-portfolio/portfolio-common@v0.4.0
go mod tidy
```

### 2. Update main.go

```go
import (
    "os"
    "github.com/GunarsK-portfolio/portfolio-common/logger"
    "github.com/GunarsK-portfolio/portfolio-common/metrics"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
    // Logger (JSON → Loki)
    appLogger := logger.New(logger.Config{
        Level:       os.Getenv("LOG_LEVEL"),
        Format:      os.Getenv("LOG_FORMAT"),
        ServiceName: "your-service",
    })

    // Metrics (→ Prometheus)
    metricsCollector := metrics.New(metrics.Config{
        ServiceName: "your",
        Namespace:   "portfolio",
    })

    router := gin.New()
    router.Use(logger.Recovery(appLogger))
    router.Use(logger.RequestLogger(appLogger))
    router.Use(metricsCollector.Middleware())
    router.GET("/metrics", gin.WrapH(promhttp.Handler()))
}
```

### 3. Update .env

```env
LOG_LEVEL=info
LOG_FORMAT=json
LOG_SOURCE=false
ENVIRONMENT=development

# Optional: Customize Grafana credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
```

### 4. Update docker-compose.yml

```yaml
services:
  your-service:
    labels:
      logging: "promtail"        # Required for logs
      environment: "development"
```

### 5. Add to Prometheus Config

Edit `monitoring/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'your-service'
    static_configs:
      - targets: ['your-service:PORT']
```

### 6. Restart

```bash
task monitoring:restart
```

---

## Dashboards

### Service Overview

**Path**: Dashboards → Portfolio → Service Overview

- Request rate (req/sec)
- Latency (p50, p95)
- Error rate (4xx, 5xx)
- Requests in flight

### Logs Explorer

**Path**: Dashboards → Portfolio → Logs Explorer

- Filter by service, level
- Search by request_id, user_id
- Log volume histogram

---

## Configuration

### Environment Variables

| Variable | Values | Description |
|----------|--------|-------------|
| `LOG_LEVEL` | debug, info, warn, error | Log verbosity |
| `LOG_FORMAT` | json, text | Output format |
| `LOG_SOURCE` | true, false | Add file:line (dev only) |

### Retention

**Prometheus** (metrics): Edit `docker-compose.monitoring.yml`

```yaml
command:
  - '--storage.tsdb.retention.time=30d'
```

**Loki** (logs): Edit `monitoring/loki/loki.yml`

```yaml
limits_config:
  retention_period: 168h  # 7 days
```

---

## Troubleshooting

### Prometheus not scraping

```bash
# Check targets
open http://localhost:9090/targets

# Test endpoint
curl http://your-service:PORT/metrics
```

### Logs not in Loki

```bash
# Check Promtail
docker logs promtail

# Verify label
docker inspect your-service | grep logging

# Test Loki
curl http://localhost:3100/ready
```

### Empty dashboards

1. Check datasources: Grafana → Configuration → Data Sources
2. Test connection (should show "working")
3. Check time range (top-right)
4. Verify metrics exist: <http://localhost:9090>

---

## Useful Queries

### PromQL (Prometheus)

```promql
# Request rate
sum(rate(portfolio_auth_http_requests_total[5m])) by (service)

# Latency p95
histogram_quantile(0.95,
  sum(rate(portfolio_auth_http_request_duration_seconds_bucket[5m]))
  by (le))

# Error rate
sum(rate(portfolio_auth_http_requests_total{status=~"5.."}[5m])) / sum(rate(portfolio_auth_http_requests_total[5m]))
```

### LogQL (Loki)

```logql
# All logs from auth-service
{service="auth-service"} | json

# Errors only
{service=~".*"} | json | level="ERROR"

# Specific request
{service=~".*"} | json | request_id="abc-123"
```

---

## Resources

- [Prometheus Docs](https://prometheus.io/docs/)
- [Loki Docs](https://grafana.com/docs/loki/latest/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [LogQL Cheat Sheet](https://grafana.com/docs/loki/latest/logql/)
