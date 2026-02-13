# Nautobot Kubernetes CI/CD Deployment Guide

## 🎯 Overview

This guide covers the complete production deployment of Nautobot on Kubernetes with:
- ✅ LoadBalancer service with MetalLB
- ✅ Nginx Ingress Controller
- ✅ HTTPS/TLS support
- ✅ Zero-downtime CI/CD pipeline
- ✅ Automatic deployment on configuration changes

## 🏗️ Architecture

```
Internet
    ↓
MetalLB LoadBalancer (172.17.152.200)
    ↓
Nginx Ingress Controller
    ↓ (TLS termination)
Nautobot Web Service (Rolling Updates)
    ↓
PostgreSQL + Redis (Persistent Storage)
```

## 📋 Deployed Components

### Infrastructure
- **Kubernetes Cluster**: 5 nodes (1 master, 4 workers)
- **MetalLB**: Bare-metal load balancer (IP pool: 172.17.152.200-210)
- **Nginx Ingress Controller**: HTTP/HTTPS routing
- **Local Path Provisioner**: Dynamic PV provisioning

### Application Stack
- **PostgreSQL**: StatefulSet with 20GB persistent storage
- **Redis**: Deployment with 5GB persistent storage
- **Nautobot Web**: 2 replicas (rolling updates enabled)
- **Nautobot Workers**: 2 replicas (background tasks)
- **Nautobot Scheduler**: 1 replica (cron jobs)

## 🌐 Access Information

### LoadBalancer Access
```bash
# HTTP
http://172.17.152.200/

# HTTPS (self-signed certificate)
https://172.17.152.200/
```

### NodePort Access (Fallback)
```bash
# Direct node access
http://172.17.152.109:31220/
http://172.17.152.103:31220/
http://172.17.152.104:31220/
http://172.17.152.105:31220/
http://172.17.152.106:31220/
```

### Ingress Access
```bash
# Add to /etc/hosts:
172.17.152.200 nautobot.local

# Access via hostname
http://nautobot.local/
https://nautobot.local/
```

### Login Credentials
```
Username: admin
Password: admin123
```

## 🔐 HTTPS/TLS Configuration

### Current Setup (Self-Signed Certificate)
```bash
# Certificate location on master node
/tmp/nautobot-tls.key
/tmp/nautobot-tls.crt

# Kubernetes secret
kubectl get secret nautobot-tls -n nautobot
```

### Using Custom Certificate
```bash
# Create TLS secret with your own certificate
kubectl create secret tls nautobot-tls \
  --cert=/path/to/your/cert.crt \
  --key=/path/to/your/cert.key \
  -n nautobot \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart ingress
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
```

### Let's Encrypt (Production)
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update ingress annotation
kubectl annotate ingress nautobot -n nautobot \
  cert-manager.io/cluster-issuer=letsencrypt-prod
```

## 🚀 CI/CD Pipeline

### Automatic Deployment Triggers

The CI/CD pipeline automatically triggers when you push changes to:
- `group_vars/dev/nautobot.yml`
- `group_vars/all/nautobot.yml`
- `helm/nautobot/**`

### Pipeline Stages

1. **Detect Changes**
   - Analyzes git diff for configuration changes
   - Detects plugin additions/modifications
   - Sets outputs for conditional stages

2. **Build Image** (if plugins changed)
   - Builds custom Docker image with new plugins
   - Pushes to container registry
   - Tags with build ID

3. **Deploy to Kubernetes**
   - Updates ConfigMap from `group_vars/dev/nautobot.yml`
   - Triggers rolling update with zero downtime
   - Waits for health checks
   - Runs post-deployment verification

4. **Rollback** (on failure)
   - Automatically reverts to previous version
   - Ensures service availability

### Zero-Downtime Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # 1 extra pod during update
    maxUnavailable: 0  # No pods taken down until new ones are ready
```

**How it works:**
1. New pod is created (total: 3 pods)
2. New pod passes readiness probe
3. New pod receives traffic
4. Old pod is terminated
5. Repeats for remaining pods

**Result:** No service interruption!

## 📝 Making Configuration Changes

### Example: Adding a Plugin

1. **Edit configuration**
```bash
# Edit group_vars/dev/nautobot.yml
vim group_vars/dev/nautobot.yml

# Add plugin configuration
nautobot_plugins:
  - name: nautobot_device_lifecycle_mgmt
    pip_name: nautobot-device-lifecycle-mgmt
  - name: nautobot_golden_config
    pip_name: nautobot-golden-config
```

2. **Commit and push**
```bash
git add group_vars/dev/nautobot.yml
git commit -m "Add device lifecycle management plugin"
git push origin main
```

3. **Pipeline automatically:**
   - Detects plugin changes
   - Builds new Docker image with plugins
   - Updates deployment
   - Performs rolling update
   - **No downtime!**

### Example: Updating Database Settings

1. **Edit configuration**
```bash
vim group_vars/dev/nautobot.yml

# Modify database settings
nautobot_db:
  conn_max_age: 600  # Changed from 300
```

2. **Push changes**
```bash
git add group_vars/dev/nautobot.yml
git commit -m "Increase database connection max age"
git push origin main
```

3. **Pipeline automatically:**
   - Regenerates ConfigMap
   - Triggers rolling restart
   - **Zero downtime!**

## 🔍 Monitoring Deployment

### Check Pipeline Status

**Azure DevOps:**
```bash
# View pipeline runs
https://dev.azure.com/your-org/your-project/_build

# Watch live logs
az pipelines runs show --id <run-id>
```

**GitHub Actions:**
```bash
# View workflow runs
https://github.com/your-org/your-repo/actions

# Check status via CLI
gh run list --workflow=k8s-deploy.yml
gh run watch <run-id>
```

### Monitor Kubernetes Rollout

```bash
# Watch rollout progress
kubectl rollout status deployment/nautobot-web -n nautobot

# View pod updates in real-time
kubectl get pods -n nautobot -w

# Check rollout history
kubectl rollout history deployment/nautobot-web -n nautobot

# View recent events
kubectl get events -n nautobot --sort-by='.lastTimestamp' | tail -20
```

### Verify Zero Downtime

```bash
# Run continuous health checks during deployment
while true; do
  curl -s -o /dev/null -w "%{http_code}\n" http://172.17.152.200/health/
  sleep 1
done

# Expected: All 200 responses, no errors!
```

## 🔄 Manual Deployment

### Update Configuration Only
```bash
# SSH to master node
ssh ubuntu@172.17.152.109

# Update ConfigMap manually
kubectl create configmap nautobot-config \
  --from-file=nautobot_config.py=/path/to/config.py \
  -n nautobot \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger rolling restart
kubectl rollout restart deployment/nautobot-web -n nautobot
kubectl rollout restart deployment/nautobot-worker -n nautobot
kubectl rollout restart deployment/nautobot-scheduler -n nautobot
```

### Full Helm Upgrade
```bash
# Update values
vim helm/nautobot/values.yaml

# Deploy with Helm
helm upgrade nautobot ./helm/nautobot \
  -n nautobot \
  --values ./helm/nautobot/values.yaml \
  --wait \
  --timeout 10m
```

## 🛠️ Troubleshooting

### Pipeline Fails

```bash
# Check pipeline logs for errors
# Common issues:
# 1. KUBECONFIG not set in secrets
# 2. Insufficient permissions
# 3. Configuration syntax errors

# Validate configuration locally
python3 -m yaml.safe_load group_vars/dev/nautobot.yml
ansible-playbook --syntax-check playbooks/deploy_k8s_all.yml
```

### Pods Not Ready

```bash
# Check pod status
kubectl get pods -n nautobot

# View pod logs
kubectl logs -f deployment/nautobot-web -n nautobot

# Describe pod for events
kubectl describe pod <pod-name> -n nautobot

# Check readiness probe
kubectl get pod <pod-name> -n nautobot -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/nautobot-web -n nautobot

# Rollback to previous version
kubectl rollout undo deployment/nautobot-web -n nautobot

# Rollback to specific revision
kubectl rollout undo deployment/nautobot-web -n nautobot --to-revision=3
```

### Load Balancer Issues

```bash
# Check MetalLB status
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb,component=controller

# Check IP pool
kubectl get ipaddresspool -n metallb-system
kubectl describe ipaddresspool nautobot-pool -n metallb-system

# Check service
kubectl get svc nautobot-lb -n nautobot
kubectl describe svc nautobot-lb -n nautobot
```

## 📊 Health Checks

### Application Health
```bash
# Health endpoint
curl http://172.17.152.200/health/

# Expected response:
{
  "status": "healthy",
  "version": "3.0.6",
  "database": "connected",
  "cache": "connected"
}
```

### Service Status
```bash
# All pods running
kubectl get pods -n nautobot

# All services available
kubectl get svc -n nautobot

# Ingress configured
kubectl get ingress -n nautobot
```

## 🔒 Security Considerations

### Production Checklist

- [ ] Replace self-signed certificate with CA-signed cert
- [ ] Enable TLS for all services (PostgreSQL, Redis)
- [ ] Set strong database passwords
- [ ] Enable RBAC and network policies
- [ ] Configure pod security policies
- [ ] Set resource limits and requests
- [ ] Enable audit logging
- [ ] Configure backup and disaster recovery
- [ ] Set up monitoring and alerting
- [ ] Implement secrets management (Vault, Sealed Secrets)

### Hardening Steps

```bash
# 1. Enable pod security standards
kubectl label namespace nautobot pod-security.kubernetes.io/enforce=restricted

# 2. Create network policies
kubectl apply -f k8s/network-policies/

# 3. Enable admission controllers
# Add to kube-apiserver flags:
# --enable-admission-plugins=PodSecurity,ResourceQuota,LimitRanger

# 4. Rotate secrets regularly
kubectl get secrets -n nautobot
```

## 📈 Scaling

### Horizontal Scaling
```bash
# Scale web pods
kubectl scale deployment nautobot-web -n nautobot --replicas=4

# Scale workers
kubectl scale deployment nautobot-worker -n nautobot --replicas=4

# Auto-scaling (HPA)
kubectl autoscale deployment nautobot-web -n nautobot \
  --cpu-percent=70 \
  --min=2 \
  --max=10
```

### Vertical Scaling
```bash
# Update resources in values.yaml
web:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi

# Apply changes
helm upgrade nautobot ./helm/nautobot -n nautobot
```

## 🎓 Next Steps

1. **Set up monitoring**: Prometheus + Grafana
2. **Enable logging**: ELK Stack or Loki
3. **Implement backups**: Velero
4. **Add alerting**: AlertManager
5. **Configure auto-scaling**: HPA/VPA
6. **Implement GitOps**: ArgoCD or Flux

## 📚 Additional Resources

- [Nautobot Documentation](https://docs.nautobot.com/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Helm Charts Guide](https://helm.sh/docs/)

## 🆘 Support

For issues or questions:
1. Check logs: `kubectl logs -n nautobot <pod-name>`
2. Review events: `kubectl get events -n nautobot`
3. Check pipeline logs in Azure DevOps/GitHub Actions
4. Consult this guide's troubleshooting section
