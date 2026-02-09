# Production-Ready Kubernetes Deployment Guide

## 🎯 Overview

This is a **production-grade** Kubernetes deployment of Nautobot with:
- ✅ **Helm charts** for consistent deployments
- ✅ **Automated kubectl/kubeadm installation**
- ✅ **Master node as Load Balancer** (Nginx Ingress)  
- ✅ **High Availability** with multiple replicas
- ✅ **Auto-scaling** for workers
- ✅ **Health checks** and **rolling updates**
- ✅ **Node affinity** and **anti-affinity**
- ✅ **Resource limits** and **requests**
- ✅ **Persistent storage** for media/static files
- ✅ **Security contexts** and best practices

## 📦 Architecture

```
                   INTERNET
                      │
                      ↓
          ┌───────────────────────┐
          │   Master Node (VM #1)  │
          │   192.168.1.10        │
          │  - Nginx Ingress (LB)  │
          │  - K8s Control Plane   │
          │  - Ports: 30080, 30443 │
          └───────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        │                           │
┌───────▼───────┐         ┌────────▼────────┐
│  Web Workers  │         │ Celery Workers  │
│  (VMs #2-3)   │         │   (VMs #4-5)    │
│               │         │                 │
│ • Web Pod x2  │         │ • Worker Pod x2 │
│ • Label: web  │         │ • Label: worker │
└───────┬───────┘         └────────┬────────┘
        │                          │
        └────────┬──────────────────┘
                 │
    ┌────────────┴───────────────┐
    │                            │
┌───▼────────┐         ┌─────────▼──┐
│ PostgreSQL │         │   Redis    │
│  (VM #6)   │         │  (VM #7)   │
│ 192.168.1.16│        │192.168.1.17│
└────────────┘         └────────────┘

      GitHub Runner (VM #8)
      192.168.1.18
```

## 🖥️ VM Requirements

| VM # | Role | vCPU | RAM | Disk | IP |
|------|------|------|-----|------|-----|
| 1 | K8s Master + LB | 2 | 4GB | 50GB | 192.168.1.10 |
| 2 | K8s Worker (Web) | 2 | 4GB | 50GB | 192.168.1.11 |
| 3 | K8s Worker (Web) | 2 | 4GB | 50GB | 192.168.1.12 |
| 4 | K8s Worker (Celery) | 2 | 6GB | 50GB | 192.168.1.13 |
| 5 | K8s Worker (Celery) | 2 | 6GB | 50GB | 192.168.1.14 |
| 6 | PostgreSQL | 2 | 8GB | 100GB | 192.168.1.16 |
| 7 | Redis | 2 | 4GB | 20GB | 192.168.1.17 |
| 8 | GitHub Runner | 2 | 4GB | 50GB | 192.168.1.18 |

**Total: 8 VMs, 16 vCPUs, 42GB RAM**

## 🚀 Quick Start (Full Automation)

### 1. Configure Your VMs

Edit `inventory/k8s/onprem.yml`:
```bash
vim inventory/k8s/onprem.yml
```

Replace:
- All IP addresses with your actual VMs
- `your_username` with your SSH username

### 2. Configure Secrets

```bash
# Copy vault example
cp group_vars/onprem/vault.yml.example group_vars/onprem/vault.yml

# Edit and add your passwords
vim group_vars/onprem/vault.yml

# Generate secret key
python3 -c "import secrets; print(secrets.token_urlsafe(50))"

# Encrypt vault
ansible-vault encrypt group_vars/onprem/vault.yml
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass
```

### 3. Deploy Everything (One Command!)

```bash
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_production.yml \
  --vault-password-file .vault_pass
```

**This automated playbook will:**
1. ✅ Install and configure containerd on all nodes
2. ✅ Install kubectl, kubeadm, kubelet automatically
3. ✅ Initialize Kubernetes cluster on master
4. ✅ Join all worker nodes automatically
5. ✅ Label web and worker nodes
6. ✅ Install Helm 3 on master
7. ✅ Install Nginx Ingress Controller (Load Balancer)
8. ✅ Deploy PostgreSQL and Redis on VMs
9. ✅ Deploy Nautobot with Helm to K8s cluster
10. ✅ Configure persistent volumes, health checks, auto-scaling

**Duration:** ~25-30 minutes (one-time)

## 🌐 Access Nautobot

After deployment completes:

**Primary Access (via Master Node):**
```
HTTP:  http://192.168.1.10:30080
HTTPS: https://192.168.1.10:30443 (if SSL configured)
```

**Default Credentials:**
- Username: `admin`
- Password: (from `vault_nautobot_superuser_password`)

## 📊 Verify Deployment

```bash
# SSH to master node
ssh your_username@192.168.1.10

# Check cluster status
kubectl get nodes -o wide

# Check Nautobot pods
kubectl get pods -n nautobot -o wide

# Expected output:
# nautobot-web-xxxxx         1/1  Running  (on web nodes)
# nautobot-worker-xxxxx      1/1  Running  (on worker nodes)
# nautobot-scheduler-xxxxx   1/1  Running  (anywhere)

# Check services
kubectl get svc -n nautobot

# Check ingress
kubectl get ingress -n nautobot

# Check Helm release
helm list -n nautobot
```

## 🔧 Production Features Included

### 1. **High Availability**
- 2 web replicas with anti-affinity (different nodes)
- 2 worker replicas with anti-affinity
- 1 scheduler replica (uses Recreate strategy)

### 2. **Auto-Scaling (Workers)**
```yaml
HPA enabled:
- Min replicas: 2
- Max replicas: 6
- Target CPU: 70%
- Target Memory: 80%
```

Watch auto-scaling:
```bash
kubectl get hpa -n nautobot -w
```

### 3. **Resource Management**
```yaml
Web Pods:
  Requests: 500m CPU, 1Gi RAM
  Limits: 2 CPU, 2Gi RAM

Worker Pods:
  Requests: 500m CPU, 1Gi RAM
  Limits: 2 CPU, 3Gi RAM

Scheduler:
  Requests: 100m CPU, 256Mi RAM
  Limits: 500m CPU, 512Mi RAM
```

### 4. **Health Checks**
- **Liveness Probe:** `/health/` endpoint every 10s
- **Readiness Probe:** `/health/` endpoint every 5s
- Automatic pod restart on failure

### 5. **Persistent Storage**
- **Media:** 10Gi PVC (ReadWriteMany)
- **Static:** 2Gi PVC (ReadWriteMany)
- **Git:** 5Gi PVC (ReadWriteMany)

Check PVCs:
```bash
kubectl get pvc -n nautobot
```

### 6. **Rolling Updates**
- Zero-downtime deployments
- MaxSurge: 1, MaxUnavailable: 0
- Gradual pod replacement

### 7. **Node Affinity**
- Web pods → Nodes labeled `workload=web`
- Worker pods → Nodes labeled `workload=worker`
- Optimized resource distribution

### 8. **Security**
- Non-root containers (UID 999)
- Dropped capabilities
- Secrets for all credentials
- SecurityContext enabled

## 🔄 Day 2 Operations

### Scale Deployments

```bash
# Scale web pods
kubectl scale -n nautobot deployment/nautobot-web --replicas=4

# Scale workers
kubectl scale -n nautobot deployment/nautobot-worker --replicas=6

# Check status
kubectl get pods -n nautobot -l app.kubernetes.io/component=web -o wide
```

### Update Nautobot Version

```bash
# SSH to master
cd ~/nautobot-helm

# Update image tag in values.yaml
vim values.yaml
# Change: image.tag: "3.0.7-py3.11"

# Upgrade with Helm
helm upgrade nautobot . \
  --namespace nautobot \
  --set image.tag=3.0.7-py3.11 \
  --wait

# Watch rollout
kubectl rollout status -n nautobot deployment/nautobot-web
```

### Rollback Deployment

```bash
# View history
helm history nautobot -n nautobot

# Rollback to previous
helm rollback nautobot -n nautobot

# Rollback to specific revision
helm rollback nautobot 2 -n nautobot
```

### View Logs

```bash
# Web logs
kubectl logs -n nautobot -l app.kubernetes.io/component=web --tail=100 -f

# Worker logs
kubectl logs -n nautobot -l app.kubernetes.io/component=worker --tail=100 -f

# Scheduler logs
kubectl logs -n nautobot -l app.kubernetes.io/component=scheduler --tail=100 -f

# Single pod logs
kubectl logs -n nautobot nautobot-web-xxxxx -f
```

### Execute Commands in Pod

```bash
# Shell into web pod
kubectl exec -it -n nautobot deploy/nautobot-web -- bash

# Run Django management command
kubectl exec -it -n nautobot deploy/nautobot-web -- nautobot-server shell

# Create Django superuser
kubectl exec -it -n nautobot deploy/nautobot-web -- \
  nautobot-server createsuperuser --username newadmin --email admin@example.com
```

### Backup & Restore

```bash
# Backup PostgreSQL (from DB VM)
ssh your_username@192.168.1.16
pg_dump -U nautobot nautobot > /tmp/nautobot_backup.sql

# Backup PVCs
kubectl get pvc -n nautobot
# Use volume snapshots or rsync from mounted paths

# Restore database
psql -U nautobot nautobot < /tmp/nautobot_backup.sql
```

## 📈 Monitoring & Metrics

### Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n nautobot

# Detailed pod metrics
kubectl describe pod -n nautobot nautobot-web-xxxxx
```

### Events

```bash
# Cluster events
kubectl get events -n nautobot --sort-by='.lastTimestamp'

# Pod events
kubectl describe pod -n nautobot nautobot-web-xxxxx | grep -A 20 Events:
```

## 🔐 Security Best Practices

### 1. **Enable SSL/TLS**

Edit Helm values:
```yaml
ingress:
  tls:
    enabled: true
    secretName: nautobot-tls
```

Create TLS secret:
```bash
kubectl create secret tls nautobot-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n nautobot
```

### 2. **Network Policies**

```bash
# Create network policy (example)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nautobot-allow-ingress
  namespace: nautobot
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: nautobot
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
EOF
```

### 3. **RBAC Policies**

ServiceAccount is already created by Helm. Add additional RBAC as needed.

## 🤖 GitHub Actions Integration

The workflow supports automated deployments:

```yaml
# .github/workflows/deploy-onprem.yml already configured
```

**Trigger deployment:**
```bash
git add .
git commit -m "Update Nautobot config"
git push origin feat/onprem-deployment
```

## 🐛 Troubleshooting

### Pods not starting

```bash
# Describe pod
kubectl describe pod -n nautobot nautobot-web-xxxxx

# Check logs
kubectl logs -n nautobot nautobot-web-xxxxx

# Check events
kubectl get events -n nautobot
```

### Database connection issues

```bash
# Test from pod
kubectl exec -it -n nautobot deploy/nautobot-web -- bash
apt-get update && apt-get install -y postgresql-client
psql -h 192.168.1.16 -U nautobot -d nautobot
```

### Ingress not working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check ingress resource
kubectl describe ingress -n nautobot nautobot
```

### Worker pods crashing

```bash
# Check Redis connectivity
kubectl exec -it -n nautobot deploy/nautobot-worker -- bash
apt-get update && apt-get install -y redis-tools
redis-cli -h 192.168.1.17 ping
```

## 📚 Useful Commands Reference

```bash
# Get all resources
kubectl get all -n nautobot

# Restart deployment
kubectl rollout restart -n nautobot deployment/nautobot-web

# Patch deployment
kubectl patch deployment -n nautobot nautobot-web \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"nautobot","env":[{"name":"DEBUG","value":"true"}]}]}}}}'

# Port forward for local access
kubectl port-forward -n nautobot svc/nautobot 8000:8000

# Delete and redeploy
helm uninstall nautobot -n nautobot
# Then re-run deployment playbook

# Cluster info
kubectl cluster-info
kubectl api-resources
kubectl version
```

## 🎯 Production Checklist

Before going live:

- [ ] All VM IPs configured in inventory
- [ ] All passwords set in encrypted vault
- [ ] Database backups configured
- [ ] SSL/TLS certificates installed
- [ ] Monitoring solution deployed (Prometheus/Grafana)
- [ ] Log aggregation configured (ELK/Loki)
- [ ] Resource limits tested under load
- [ ] Disaster recovery plan documented
- [ ] Team trained on kubectl/helm basics
- [ ] CI/CD pipeline tested
- [ ] Security scan completed
- [ ] Performance testing done

## 📞 Support

For issues:
1. Check pod logs: `kubectl logs -n nautobot <pod-name>`
2. Check events: `kubectl get events -n nautobot`
3. Review Helm values: `helm get values nautobot -n nautobot`
4. Check Ansible logs during deployment

---

**Congratulations! You now have a production-ready, auto-scaling, highly-available Nautobot deployment on Kubernetes! 🎉**
