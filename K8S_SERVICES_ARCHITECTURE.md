# Kubernetes Services Architecture for Nautobot

## 📦 Overview

This Helm chart deploys **4 core services** in your Kubernetes cluster:

1. **nautobot-web** - Web UI and API service
2. **nautobot-worker** - Celery background workers (optional service for metrics)
3. **postgresql** - Database service
4. **redis** - Cache and message broker service

## 🏗️ Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Kubernetes Cluster                         │
│                                                                  │
│  ┌────────────────┐          ┌──────────────────┐              │
│  │  Ingress       │          │   Service        │              │
│  │  (nginx)       │─────────▶│   nautobot       │              │
│  │  :30080/:30443 │          │   :8000          │              │
│  └────────────────┘          └────────┬─────────┘              │
│                                       │                          │
│                                       ▼                          │
│                          ┌─────────────────────┐                │
│                          │  Deployment         │                │
│                          │  nautobot-web       │                │
│                          │  (2 replicas)       │                │
│                          └─────────┬───────────┘                │
│                                    │                             │
│       ┌────────────────────────────┼────────────────┐           │
│       │                            │                │           │
│       ▼                            ▼                ▼           │
│  ┌─────────┐              ┌─────────────┐    ┌─────────────┐  │
│  │ Service │              │  Service    │    │  Service    │  │
│  │ redis   │              │  postgres   │    │  worker     │  │
│  │ :6379   │              │  :5432      │    │  :9090      │  │
│  └────┬────┘              └──────┬──────┘    └──────┬──────┘  │
│       │                          │                   │          │
│       ▼                          ▼                   ▼          │
│  ┌─────────┐              ┌─────────────┐    ┌─────────────┐  │
│  │Deploy   │              │StatefulSet  │    │  Deployment │  │
│  │redis    │              │postgresql   │    │  worker     │  │
│  │(1 pod)  │              │(1 pod)      │    │  (2 pods)   │  │
│  └─────────┘              └─────────────┘    └─────────────┘  │
│      │                          │                              │
│      ▼                          ▼                              │
│  ┌─────────┐              ┌─────────────┐                     │
│  │  PVC    │              │     PVC     │                     │
│  │  5Gi    │              │    20Gi     │                     │
│  └─────────┘              └─────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Service Details

### 1. nautobot-web Service

**Purpose:** Exposes the Nautobot web UI and REST API

**Configuration:**
```yaml
Name: nautobot
Type: ClusterIP
Port: 8000
Target: web deployment pods
```

**Manifest:** `templates/service.yaml`

**Key Features:**
- Load balances across 2 web pods
- Accessed via Ingress controller
- HTTP health checks enabled
- Auto-scaling capable (HPA)

**Access:**
```bash
# Internal cluster access
curl http://nautobot.nautobot.svc.cluster.local:8000

# External access (via Ingress)
http://nautobot.local:30080
```

---

### 2. nautobot-worker Service

**Purpose:** (Optional) Exposes metrics endpoint for Celery workers

**Configuration:**
```yaml
Name: nautobot-worker
Type: ClusterIP
Port: 9090
Target: worker deployment pods
```

**Manifest:** `templates/worker-service.yaml`

**Key Features:**
- Metrics endpoint for monitoring
- Disabled by default (workers don't need external access)
- Can be enabled for Prometheus scraping

**Enable in values.yaml:**
```yaml
worker:
  service:
    enabled: true  # Set to true to expose metrics
    port: 9090
```

---

### 3. postgresql Service

**Purpose:** Database service for Nautobot

**Configuration:**
```yaml
Name: nautobot-postgresql
Type: ClusterIP (Headless - clusterIP: None)
Port: 5432
Target: PostgreSQL StatefulSet
```

**Manifest:** `templates/postgres-service.yaml`

**Key Features:**
- StatefulSet for stable storage
- 20GB persistent volume
- Automatic backups via StatefulSet
- Health checks (pg_isready)
- Password authentication via secrets

**StatefulSet:** `templates/postgres-statefulset.yaml`

**Storage:**
- PVC: 20Gi (ReadWriteOnce)
- Mount: `/var/lib/postgresql/data`
- Backup strategy: StatefulSet snapshots

**Access:**
```bash
# Connection string
postgresql://nautobot:password@nautobot-postgresql.nautobot.svc.cluster.local:5432/nautobot

# Direct connection
kubectl exec -it nautobot-postgresql-0 -n nautobot -- psql -U nautobot
```

---

### 4. redis Service

**Purpose:** Cache and Celery message broker

**Configuration:**
```yaml
Name: nautobot-redis
Type: ClusterIP
Port: 6379
Target: Redis Deployment
```

**Manifest:** `templates/redis-service.yaml`

**Key Features:**
- Single replica (can scale if needed)
- 5GB persistent storage (optional)
- Password authentication
- Max memory: 512MB with LRU eviction
- Health checks (redis-cli ping)

**Deployment:** `templates/redis-deployment.yaml`

**Storage:**
- PVC: 5Gi (optional, for persistence)
- Mount: `/data`
- AOF persistence: configurable

**Access:**
```bash
# Connection string
redis://:password@nautobot-redis.nautobot.svc.cluster.local:6379/0

# Direct connection
kubectl exec -it <redis-pod> -n nautobot -- redis-cli -a <password>
```

---

## 🚀 Deployment Options

### Option 1: All Services in Kubernetes (Recommended)

**Configuration:**
```yaml
# values.yaml
postgresql:
  enabled: true  # Run PostgreSQL in K8s
  
redis:
  enabled: true  # Run Redis in K8s
```

**Benefits:**
- ✅ Everything in one cluster
- ✅ Easy management with Helm
- ✅ Automatic scaling
- ✅ Integrated monitoring
- ✅ Simplified networking

**Deploy:**
```bash
helm install nautobot ./helm/nautobot \
  --namespace nautobot \
  --create-namespace
```

---

### Option 2: External Database/Redis

**Configuration:**
```yaml
# values.yaml
postgresql:
  enabled: false  # Use external PostgreSQL

database:
  host: "192.168.1.16"  # External DB host
  port: 5432

redis:
  enabled: false  # Use external Redis
  host: "192.168.1.17"  # External Redis host
  port: 6379
```

**Benefits:**
- ✅ Use existing database infrastructure
- ✅ Managed database services (RDS, etc.)
- ✅ Separate scaling of DB and app

**Deploy:**
```bash
helm install nautobot ./helm/nautobot \
  --namespace nautobot \
  --create-namespace \
  --set postgresql.enabled=false \
  --set redis.enabled=false
```

---

## 🔐 Service Discovery

All services use Kubernetes DNS for service discovery:

### Internal DNS Names

```bash
# Nautobot Web
nautobot.nautobot.svc.cluster.local:8000

# PostgreSQL
nautobot-postgresql.nautobot.svc.cluster.local:5432

# Redis
nautobot-redis.nautobot.svc.cluster.local:6379

# Worker (if enabled)
nautobot-worker.nautobot.svc.cluster.local:9090
```

### Short Names (within namespace)

```bash
nautobot:8000
nautobot-postgresql:5432
nautobot-redis:6379
```

---

## 📊 Service Health Checks

### Nautobot Web
```bash
kubectl get svc nautobot -n nautobot
curl http://nautobot.nautobot.svc.cluster.local:8000/health/
```

### PostgreSQL
```bash
kubectl get svc nautobot-postgresql -n nautobot
kubectl exec -it nautobot-postgresql-0 -n nautobot -- pg_isready -U nautobot
```

### Redis
```bash
kubectl get svc nautobot-redis -n nautobot
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/component=cache -n nautobot -o name | head -1) -n nautobot -- redis-cli -a password ping
```

### Worker
```bash
kubectl get pods -l app.kubernetes.io/component=worker -n nautobot
kubectl logs -l app.kubernetes.io/component=worker -n nautobot --tail=20
```

---

## 🎛️ Service Configuration

### Modify Service Types

**Change to NodePort (for external access):**
```yaml
# values.yaml
service:
  type: NodePort
  port: 8000
  nodePort: 30800  # Optional: specify port
```

**Change to LoadBalancer (cloud environments):**
```yaml
# values.yaml
service:
  type: LoadBalancer
  port: 8000
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

---

## 🔧 Troubleshooting

### Service Not Reachable

```bash
# Check service exists
kubectl get svc -n nautobot

# Check endpoints (pods backing the service)
kubectl get endpoints nautobot -n nautobot

# Check pod status
kubectl get pods -n nautobot

# Check service selector matches pod labels
kubectl describe svc nautobot -n nautobot
kubectl get pods --show-labels -n nautobot
```

### Database Connection Issues

```bash
# Test from web pod
kubectl exec -it <nautobot-web-pod> -n nautobot -- \
  nc -zv nautobot-postgresql 5432

# Check PostgreSQL logs
kubectl logs nautobot-postgresql-0 -n nautobot

# Verify credentials
kubectl get secret nautobot-secrets -n nautobot -o yaml
```

### Redis Connection Issues

```bash
# Test from web pod
kubectl exec -it <nautobot-web-pod> -n nautobot -- \
  nc -zv nautobot-redis 6379

# Check Redis logs
kubectl logs -l app.kubernetes.io/component=cache -n nautobot

# Test Redis connection
kubectl exec -it <redis-pod> -n nautobot -- redis-cli -a password ping
```

---

## 📈 Service Monitoring

### View Service Endpoints

```bash
# List all services
kubectl get svc -n nautobot

# Watch service status
kubectl get svc -n nautobot -w

# Describe service details
kubectl describe svc nautobot -n nautobot
```

### Check Service Connections

```bash
# Show active connections to PostgreSQL
kubectl exec -it nautobot-postgresql-0 -n nautobot -- \
  psql -U nautobot -c "SELECT * FROM pg_stat_activity;"

# Show Redis info
kubectl exec -it <redis-pod> -n nautobot -- \
  redis-cli -a password INFO clients
```

---

## 🎯 Quick Reference

| Service | Type | Port | Pods | Purpose |
|---------|------|------|------|---------|
| `nautobot` | ClusterIP | 8000 | 2 web pods | Web UI/API |
| `nautobot-worker` | ClusterIP | 9090 | 2 worker pods | Metrics (optional) |
| `nautobot-postgresql` | ClusterIP | 5432 | 1 StatefulSet | Database |
| `nautobot-redis` | ClusterIP | 6379 | 1 Deployment | Cache/Broker |

---

## ✅ Verification Commands

```bash
# 1. Check all services are running
kubectl get svc -n nautobot

# 2. Verify all pods are ready
kubectl get pods -n nautobot

# 3. Test web service
kubectl port-forward svc/nautobot 8000:8000 -n nautobot
curl http://localhost:8000/health/

# 4. Test database connectivity
kubectl exec -it deploy/nautobot-web -n nautobot -- \
  python -c "import psycopg2; conn=psycopg2.connect('postgresql://nautobot:password@nautobot-postgresql:5432/nautobot'); print('DB Connected!')"

# 5. Test Redis connectivity
kubectl exec -it deploy/nautobot-web -n nautobot -- \
  python -c "import redis; r=redis.Redis(host='nautobot-redis', port=6379, password='password'); print(r.ping())"
```

---

**All 4 services are now properly configured and ready for deployment!** 🚀
