# Nautobot Kubernetes - Production-Ready Auto-Plugin Deployment

Complete production-grade setup with automated plugin installation from Git, CI/CD pipeline, and zero manual intervention.

## 🚀 Features

- ✅ **Fully Automated**: Push changes → Auto deploy
- ✅ **Git Plugin Installation**: Runtime installation of plugins from GitHub
- ✅ **Zero Downtime**: Rolling updates with health checks
- ✅ **Production Grade**: Migrations, static files, user creation automated
- ✅ **CI/CD Pipeline**: GitHub Actions with approval workflows
- ✅ **Rollback Ready**: One-command rollback to previous version
- ✅ **Multi-Environment**: Dev, Test, Prod with separate configs

## 📋 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│  group_vars/dev/nautobot.yml (Plugin Config)               │
└────────────┬────────────────────────────────────────────────┘
             │ Push/Merge
             ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions CI/CD Pipeline                   │
│  ✓ Validate YAML  ✓ Lint Helm  ✓ Deploy  ✓ Test            │
└────────────┬────────────────────────────────────────────────┘
             │ Ansible Playbook
             ▼
┌─────────────────────────────────────────────────────────────┐
│            Kubernetes Cluster (On-Prem/Cloud)               │
│  ┌─────────────────────────────────────────────────┐       │
│  │  Pre-Install Job (Helm Hook)                    │       │
│  │  1. Install Git                                 │       │
│  │  2. Install Plugins from GitHub URLs            │       │
│  │  3. Run Migrations                              │       │
│  │  4. Collect Static Files                        │       │
│  │  5. Create Superuser                            │       │
│  └─────────────────────────────────────────────────┘       │
│                      ▼                                       │
│  ┌───────────┬───────────┬────────────┬──────────┐         │
│  │ Web Pods  │  Worker   │ Scheduler  │ Postgres │         │
│  │ (2-3x)    │  Pods     │  Pod       │  Redis   │         │
│  └───────────┴───────────┴────────────┴──────────┘         │
│                      ▼                                       │
│               LoadBalancer                                   │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Quick Start

### 1. One-Time Setup

```bash
# Clone repository
git clone <your-repo>
cd nautobot_ansible_app

# Install dependencies
pip install ansible kubernetes
ansible-galaxy collection install kubernetes.core

# Configure GitHub Secrets (for CI/CD)
# Add these secrets to your GitHub repository:
# - K8S_SSH_KEY: SSH private key for K8s master
# - K8S_MASTER_IP: IP address of K8s master
# - ANSIBLE_VAULT_PASSWORD: Vault password
# - K8S_VERSION: Kubernetes version (e.g., "1.28.15")
```

### 2. Add Your First Plugin

Edit `group_vars/dev/nautobot.yml`:

```yaml
nautobot_git_packages:
  # Device Lifecycle Management
  - name: "git+https://github.com/nautobot/nautobot-app-device-lifecycle-mgmt.git@develop#egg=nautobot-device-lifecycle-mgmt"
    version: "develop"
    module_name: "nautobot_device_lifecycle_mgmt"
  
  # Add your plugin here:
  - name: "git+https://github.com/YOUR-ORG/your-plugin.git@main#egg=your-plugin"
    version: "main"
    module_name: "your_plugin"

# Plugin configuration
nautobot_plugins_config:
  nautobot_device_lifecycle_mgmt: {}
  your_plugin:
    api_url: "https://api.example.com"
    api_key: "{{ vault_your_plugin_api_key }}"
```

### 3. Deploy

#### Option A: Automatic (via Git Push)

```bash
git add group_vars/dev/nautobot.yml
git commit -m "feat: add new plugin"
git push origin develop
```

✅ **GitHub Actions automatically deploys to dev environment**

#### Option B: Manual (via Script)

```bash
# Deploy to dev
./scripts/deploy-production.sh deploy dev

# Check status
./scripts/deploy-production.sh status dev

# View logs
./scripts/deploy-production.sh logs dev web
```

## 📦 How Plugin Installation Works

### Before (Manual - Old Way):

```bash
kubectl exec -it nautobot-web-xxx -n nautobot -- bash
apt-get install git
pip install git+https://github.com/nautobot/plugin.git
# Edit config manually
# Run migrations manually
# Restart pods
```

### After (Automated - New Way):

1. **Edit `group_vars/dev/nautobot.yml`**:
   ```yaml
   nautobot_git_packages:
     - name: "git+https://github.com/..."
       module_name: "plugin_name"
   ```

2. **Push** or **Trigger Pipeline**

3. **Done!** Plugin installed automatically:
   - ✅ Git installed
   - ✅ Plugin installed from GitHub
   - ✅ Database migrations run
   - ✅ Static files collected
   - ✅ Superuser created
   - ✅ Health checks passed
   - ✅ Zero downtime deployment

## 🔄 Deployment Process (Under the Hood)

```bash
1. GitHub Actions Trigger
   ├─ Validate YAML syntax
   ├─ Lint Helm chart
   └─ Check plugin structure

2. Ansible Playbook Execute
   ├─ Generate Helm values from group_vars
   ├─ Sync Helm chart to K8s master
   └─ Run helm upgrade --atomic

3. Helm Pre-Install Job (Runs Once)
   ├─ Install Git + system dependencies
   ├─ Install all plugins from Git URLs
   ├─ Run database migrations
   ├─ Collect static files (1600+ files)
   └─ Create superuser if not exists

4. Rolling Update
   ├─ Deploy new web pods (1 at a time)
   ├─ Wait for readiness (health check)
   ├─ Deploy worker pods
   ├─ Deploy scheduler pod
   └─ Update service endpoints

5. Validation
   ├─ Check all pods ready
   ├─ Verify LoadBalancer IP
   ├─ Run health check (HTTP 200)
   └─ Report deployment URL
```

## 🛡️ Production Grade Features

### Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /health/
    port: 8080
  initialDelaySeconds: 120  # 2 min
  periodSeconds: 30
  
readinessProbe:
  httpGet:
    path: /health/
    port: 8080
  initialDelaySeconds: 60   # 1 min
  periodSeconds: 10
```

### Resource Management

```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2Gi
```

### Security

- Non-root containers (UID 999)
- Read-only root filesystem (where possible)
- Drop all capabilities
- Secret management via Kubernetes Secrets
- Vault integration for sensitive data

### High Availability

- Multiple replicas (web: 2-3x, worker: 2-3x)
- Anti-affinity rules
- Pod disruption budgets
- Rolling updates (zero downtime)

## 🎛️ Configuration Management

### Environment Structure

```
group_vars/
├── dev/
│   ├── nautobot.yml     ← Main configuration
│   └── vault.yml        ← Encrypted secrets
├── test/
│   ├── nautobot.yml
│  └── vault.yml
└── prod/
    ├── nautobot.yml
    └── vault.yml
```

### Key Variables

```yaml
# Version
nautobot_version: "3.0.6"

# Plugins (Auto-install from Git)
nautobot_git_packages:
  - name: "git+https://github.com/..."
    version: "develop"
    module_name: "plugin_name"

# Plugin Configuration
nautobot_plugins_config:
  plugin_name:
    setting: "value"

# Database
nautobot_db:
  host: "nautobot-postgresql"  # or external DB
  port: 5432
  name: "nautobot"
  user: "nautobot"
  password: "{{ vault_nautobot_db_password }}"

# LoadBalancer
loadbalancer_ip: "172.17.152.200"
```

## 🔧 Common Operations

### Add a New Plugin

```bash
# Interactive
./scripts/deploy-production.sh add-plugin dev

# Or edit manually
vim group_vars/dev/nautobot.yml
git commit -am "feat: add firewall plugin"
git push
```

### Check Deployment Status

```bash
./scripts/deploy-production.sh status dev
```

### View Logs

```bash
# Web logs
./scripts/deploy-production.sh logs dev web

# Worker logs
./scripts/deploy-production.sh logs dev worker

# Scheduler logs
./scripts/deploy-production.sh logs dev scheduler
```

### Rollback Deployment

```bash
./scripts/deploy-production.sh rollback dev
```

### Scale Replicas

```bash
ssh ubuntu@<master-ip>
kubectl scale deployment nautobot-web -n nautobot --replicas=5
```

## 🚨 Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n nautobot

# Check logs
kubectl logs -n nautobot <pod-name>

# Check events
kubectl get events -n nautobot --sort-by='.lastTimestamp'
```

### Plugin Installation Failed

```bash
# Check pre-install Job logs
kubectl logs -n nautobot -l app.kubernetes.io/component=pre-install

# Common issues:
# - Invalid Git URL
# - Plugin dependencies missing
# - Database connection failed
```

### 503 Error

```bash
# Check readiness probe
kubectl describe pod -n nautobot nautobot-web-xxx

# Usually means:
# - Initial delay not reached (wait 1-2 min)
# - Static files not collected (check Job logs)
# - Database migration failed
```

### Static Files Not Loading

```bash
# Verify static files PVC
kubectl get pvc -n nautobot nautobot-static

# Check collectstatic ran
kubectl logs -n nautobot -l app.kubernetes.io/component=pre-install | grep "static files"

# Expected: "✓ Collected 1634 static files"
```

## 📊 Monitoring

### Check Health Endpoint

```bash
curl http://<loadbalancer-ip>:8000/health/
```

### View Helm History

```bash
helm history nautobot -n nautobot
```

### Deployment Metrics

```bash
kubectl top pods -n nautobot
```

## 🔐 Security Best Practices

1. **Secrets Management**:
   ```bash
   # Encrypt sensitive data
   ansible-vault encrypt_string 'my-secret' --name 'vault_db_password'
   ```

2. **RBAC**:
   - ServiceAccount with minimal permissions
   - NetworkPolicies for pod-to-pod communication

3. **Image Security**:
   - Use specific version tags (not `latest`)
   - Scan images for vulnerabilities

4. **Resource Limits**:
   - Set CPU/memory limits
   - Prevent resource exhaustion

## 📝 CI/CD Pipeline

### GitHub Actions Workflow

```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - 'group_vars/**/*.yml'
      - 'helm/**'

jobs:
  deploy:
    - Validate configuration
    - Lint Helm chart
    - Deploy to environment
    - Run health checks
    - Notify team
```

### Manual Trigger

```bash
# GitHub UI: Actions → Deploy K8s → Run workflow
# Select environment: dev/test/prod
```

## 🎓 Learning Resources

- [Nautobot Plugins](https://docs.nautobot.com/projects/core/en/latest/plugins/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Production](https://kubernetes.io/docs/setup/production-environment/)

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review deployment logs
3. Check GitHub Actions run logs
4. Contact DevOps team

## 🎉 Success Criteria

Your deployment is successful when:
- ✅ All pods are Running (1/1 Ready)
- ✅ LoadBalancer has external IP
- ✅ Health check returns HTTP 200
- ✅ Plugins appear in Nautobot UI
- ✅ No errors in pod logs
- ✅ Database migrations completed

---

**Last Updated**: 2026-02-18  
**Version**: 1.0.0  
**Maintained By**: DevOps Team
