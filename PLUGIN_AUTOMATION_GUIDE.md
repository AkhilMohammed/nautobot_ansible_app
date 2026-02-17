# Nautobot Plugin Automation Guide
**Production-Ready Zero-Manual-Intervention Plugin Deployment**

Last Updated: 2026-02-17

---

## 🎯 Overview

This guide explains the **fully automated plugin deployment system** that allows you to add, update, or remove Nautobot plugins by simply editing a configuration file and pushing to Git.

### Key Features
- ✅ **Zero Manual Work**: No SSH, no kubectl commands needed
- ✅ **Git-Based Installation**: Support for private GitHub repos with authentication
- ✅ **Atomic Deployments**: Automatic rollback on failure
- ✅ **Retry Logic**: 2 automatic retries with 30-second delays
- ✅ **Health Monitoring**: Prometheus + Grafana integration
- ✅ **Code Quality**: SonarQube static analysis

---

## 📋 Table of Contents

1. [Architecture](#architecture)
2. [Quick Start: Adding a Plugin](#quick-start-adding-a-plugin)
3. [Complete Deployment Flow](#complete-deployment-flow)
4. [Configuration Reference](#configuration-reference)
5. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
6. [Production Services](#production-services)
7. [Rollback Procedures](#rollback-procedures)
8. [Advanced Topics](#advanced-topics)

---

## 🏗️ Architecture

### Component Stack
```
┌─────────────────────────────────────────────────────────────┐
│                   Production Infrastructure                  │
├─────────────────────────────────────────────────────────────┤
│  MetalLB LoadBalancer (172.17.152.200-205)                  │
│  ├─ Nautobot:        172.17.152.200:8000                    │
│  ├─ Nginx Ingress:   172.17.152.201 (HTTP/HTTPS)            │
│  ├─ Grafana:         172.17.152.202                         │
│  ├─ Prometheus:      172.17.152.203:9090                    │
│  └─ SonarQube:       172.17.152.204:9000                    │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes Cluster (v1.28.15)                              │
│  ├─ Master:   172.17.152.109                                │
│  ├─ Worker-1: 172.17.152.103                                │
│  ├─ Worker-2: 172.17.152.104                                │
│  ├─ Worker-3: 172.17.152.105                                │
│  └─ Worker-4: 172.17.152.106                                │
├─────────────────────────────────────────────────────────────┤
│  Nautobot Pods                                              │
│  ├─ nautobot-web (2 replicas)      - Init: install-plugins │
│  ├─ nautobot-worker (2 replicas)   - Init: install-plugins │
│  ├─ nautobot-scheduler (1 replica) - Init: install-plugins │
│  ├─ nautobot-postgresql                                     │
│  └─ nautobot-redis                                          │
└─────────────────────────────────────────────────────────────┘
```

### Plugin Installation Flow
```
Developer Action → Git Push
         ↓
GitHub Actions Detects Change
         ↓
Ansible Playbook Executes
         ↓
┌────────────────────────────────────┐
│ 1. Read nautobot_git_packages      │
│    from group_vars/onprem/nautobot.yml │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 2. Generate Helm Values            │
│    (templates/nautobot-helm-values.yaml.j2) │
│    - Extract plugin names          │
│    - Extract module names          │
│    - Extract Git URLs              │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 3. Helm Upgrade --atomic           │
│    - Deploy to Kubernetes          │
│    - Trigger init containers       │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 4. Init Containers (per pod)       │
│    a. Check for git binary         │
│    b. Install git if missing       │
│    c. pip install git+https://...  │
│    d. Fail fast on errors          │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 5. Main Containers Start           │
│    - Load plugins from /opt/plugins│
│    - Run migrations                │
│    - Start Nautobot                │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 6. Health Checks                   │
│    - Kubernetes readiness probes   │
│    - Prometheus scraping           │
│    - Success ✓                     │
└────────────────────────────────────┘
         ↓
    Plugin Active!
```

---

## 🚀 Quick Start: Adding a Plugin

### Step 1: Edit Configuration File

Open `group_vars/onprem/nautobot.yml` and add your plugin to `nautobot_git_packages`:

```yaml
nautobot_git_packages:
  # Existing plugins
  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/nautobot-app-device-lifecycle-mgmt.git@develop"
    version: "develop"
    module_name: "nautobot_device_lifecycle_mgmt"
  
  # YOUR NEW PLUGIN - Add here!
  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/nautobot-app-ssot.git@main"
    version: "main"
    module_name: "nautobot_ssot"
```

### Step 2: Configure Plugin Settings (Optional)

If your plugin requires configuration, add it to `nautobot_plugins_config`:

```yaml
nautobot_plugins_config:
  nautobot_device_lifecycle_mgmt: {}
  nautobot_bgp_models: {}
  
  # Your plugin config
  nautobot_ssot:
    enable_json: true
    enable_aci: false
```

### Step 3: Commit and Push

```bash
git add group_vars/onprem/nautobot.yml
git commit -m "feat: Add nautobot-ssot plugin"
git push origin feat/onprem-deployment
```

### Step 4: Monitor Deployment

```bash
# Watch Helm deployment
kubectl get pods -n nautobot -w

# Check plugin installation logs (any pod)
kubectl logs -n nautobot nautobot-web-<pod-id> -c install-plugins --follow

# Verify plugin loaded
kubectl exec -n nautobot nautobot-web-<pod-id> -- \
  nautobot-server shell -c "from django.conf import settings; print(settings.PLUGINS)"
```

### Expected Output

```
==> Installing Nautobot plugins...
Installing plugin: git+https://***@github.com/nautobot/nautobot-app-device-lifecycle-mgmt.git@develop
✓ Successfully installed: git+https://***@github.com/nautobot/nautobot-app-device-lifecycle-mgmt.git@develop
Installing plugin: git+https://***@github.com/nautobot/nautobot-app-ssot.git@main
✓ Successfully installed: git+https://***@github.com/nautobot/nautobot-app-ssot.git@main
==> All plugins installed successfully
```

---

## 🔄 Complete Deployment Flow

### Manual Trigger (For Testing)

```bash
# From your local machine or CI/CD server
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_production.yml \
  --vault-password-file vault_pass.txt \
  -e "target_env=onprem" \
  -e "kubernetes_version=1.28.15"
```

### Automatic Trigger (GitHub Actions)

The pipeline automatically triggers when:
- Changes to `group_vars/onprem/nautobot.yml`
- Changes to `playbooks/deploy_k8s_production.yml`
- Changes to `helm/nautobot/**`
- Manual workflow dispatch

### Deployment Steps Executed

1. **Pre-flight Checks** (lines 1-50)
   - Verify Kubernetes cluster is running
   - Check connectivity to all nodes
   - Validate vault credentials

2. **Generate Plugin Configuration** (lines 2178-2194)
   ```yaml
   - name: Generate plugin configuration from nautobot_git_packages
     set_fact:
       plugin_packages_list: "{{ nautobot_git_packages | map(attribute='module_name') | list }}"
       plugin_git_urls: "{{ nautobot_git_packages | map(attribute='name') | list }}"
   
   - name: Create Helm values file with plugins
     template:
       src: ../templates/nautobot-helm-values.yaml.j2
       dest: /home/{{ ansible_user }}/nautobot-values.yaml
   ```

3. **Helm Deployment** (lines 2196-2218)
   ```yaml
   - name: Deploy Nautobot with Helm
     command: >
       helm upgrade --install nautobot /home/{{ ansible_user }}/nautobot-helm
       --namespace nautobot
       --values /home/{{ ansible_user }}/nautobot-values.yaml
       --atomic
       --cleanup-on-fail
       --wait
       --timeout=15m
     retries: 2
     delay: 30
   ```

4. **Health Validation** (lines 2220-2280)
   - Wait for all pods to be Ready
   - Check database migrations
   - Verify plugin imports
   - Test API endpoints

5. **Post-Deployment** (lines 2282-2310)
   - Update PrometheusRules
   - Configure ServiceMonitor
   - Send notifications

---

## 📝 Configuration Reference

### Plugin Definition Structure

```yaml
nautobot_git_packages:
  - name: "git+https://{{ git_auth_url_safe }}github.com/org/repo.git@branch"
    # Full Git URL with authentication token variable
    # Template variable {{ git_auth_url_safe }} automatically includes token
    # Format: git+https://token@github.com/org/repo.git@branch_or_tag
    
    version: "develop"
    # Git branch, tag, or commit SHA
    # Used for documentation; actual version is in @branch part of URL
    
    module_name: "nautobot_plugin_name"
    # Python module name used in PLUGINS = ["nautobot_plugin_name"]
    # Must match the plugin's setup.py entry_points
```

### Helm Values Template

Location: `templates/nautobot-helm-values.yaml.j2`

Key sections:
```yaml
# Auto-generated from nautobot_git_packages
nautobot:
  plugins:
    enabled: {{ (nautobot_git_packages | length > 0) | lower }}
    packages:
      {% for plugin in nautobot_git_packages %}
      - name: "{{ plugin.name }}"        # Git URL
        module: "{{ plugin.module_name }}" # Python import name
        version: ""                       # Empty for Git URLs
      {% endfor %}
    config:
      {% for plugin_name, config in nautobot_plugins_config.items() %}
      {{ plugin_name }}: {{ config | to_nice_json }}
      {% endfor %}
```

### Init Container Logic

Location: `helm/nautobot/templates/deployment-{web,worker,scheduler}.yaml`

```bash
set -e  # Exit on any error

echo "==> Installing Nautobot plugins..."

# Ensure git is available
if ! command -v git >/dev/null 2>&1; then
  echo "Installing git..."
  apt-get update -qq && apt-get install -y -qq git
fi

# Install each plugin
{{ range .Values.nautobot.plugins.packages }}
echo "Installing plugin: {{ .name }}"
if pip install --no-cache-dir --target=/opt/plugins {{ .name }}; then
  echo "✓ Successfully installed: {{ .name }}"
else
  echo "✗ Failed to install: {{ .name }}"
  exit 1  # Fail fast
fi
{{ end }}

echo "==> All plugins installed successfully"
```

---

## 📊 Monitoring & Troubleshooting

### Service Endpoints

| Service | URL | Credentials |
|---------|-----|-------------|
| **Nautobot** | http://172.17.152.200:8000 | admin / [vault] |
| **Grafana** | http://172.17.152.202 | admin / [get from secret] |
| **Prometheus** | http://172.17.152.203:9090 | None |
| **SonarQube** | http://172.17.152.204:9000 | admin / admin (change!) |
| **Nginx Ingress** | http://172.17.152.201 | Routes to Nautobot |

### Get Grafana Password

```bash
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

### Check Plugin Installation Status

```bash
# View installation logs
kubectl logs -n nautobot -l app.kubernetes.io/component=web \
  -c install-plugins --tail=100

# Check if plugins are loaded in Django
kubectl exec -n nautobot deploy/nautobot-web -- \
  nautobot-server shell -c "
from django.conf import settings
import json
print(json.dumps(settings.PLUGINS, indent=2))
"

# Verify plugin in Nautobot UI
# Navigate to: http://172.17.152.200:8000/plugins/
```

### Common Issues

#### 1. Plugin Installation Fails

**Symptom**: Init container crashes, pods stuck in Init

**Check**:
```bash
kubectl logs -n nautobot nautobot-web-xxx -c install-plugins
```

**Solutions**:
- Verify Git token has repo access: `group_vars/onprem/vault.yml`
- Check plugin Git URL is correct
- Ensure branch/tag exists
- Test manually:
  ```bash
  kubectl run -it --rm debug --image=networktocode/nautobot:3.0.6-py3.11 -- bash
  pip install git+https://token@github.com/org/repo.git@branch
  ```

#### 2. Plugin Installed But Not Loaded

**Symptom**: Init succeeds, but plugin not in `/plugins/` UI

**Check**:
```bash
# Verify PLUGINS configuration
kubectl get cm -n nautobot nautobot-config -o yaml | grep -A 20 PLUGINS

# Check Python path
kubectl exec -n nautobot deploy/nautobot-web -- env | grep PYTHONPATH
```

**Solutions**:
- Ensure `module_name` in nautobot.yml matches plugin's entry_points
- Check ConfigMap has correct module name
- Verify PYTHONPATH includes `/opt/plugins`
- Restart pods: `kubectl rollout restart deploy -n nautobot`

#### 3. Helm Deployment Times Out

**Symptom**: Helm stuck for 15 minutes, then fails

**Check**:
```bash
helm status nautobot -n nautobot
kubectl get events -n nautobot --sort-by='.lastTimestamp'
```

**Solutions**:
- Check pod logs: `kubectl logs -n nautobot -l app.kubernetes.io/name=nautobot`
- Verify PVCs are bound: `kubectl get pvc -n nautobot`
- Check node resources: `kubectl top nodes`
- Increase timeout: `-e helm_timeout=30m`

#### 4. Atomic Rollback Triggered

**Symptom**: "Upgrade failed: atomic rollback performed"

**Check**:
```bash
helm history nautobot -n nautobot
kubectl get pods -n nautobot
```

**Solutions**:
- Review Helm upgrade output for error messages
- Check if database migrations failed
- Verify plugin compatibility with Nautobot version
- Manual rollback:
  ```bash
  helm rollback nautobot -n nautobot
  ```

---

## 🔧 Production Services

### MetalLB LoadBalancer

Configuration:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 172.17.152.200-172.17.152.205
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
```

### Nginx Ingress

Features:
- SSL/TLS termination
- Rate limiting
- Proxy timeouts
- WebSocket support

Access:
```bash
# HTTP
curl http://172.17.152.201

# HTTPS (requires cert)
curl -k https://172.17.152.201
```

### Prometheus Monitoring

Pre-configured dashboards:
- Nautobot application metrics
- Kubernetes cluster health
- PostgreSQL database stats
- Redis cache performance

Custom alerts:
- Pod restart rate
- API response time
- Database connection pool
- Plugin load failures

### Grafana Dashboards

Import dashboard IDs:
- **13460**: Kubernetes Cluster
- **11074**: PostgreSQL Database
- **11835**: Redis
- **Custom**: Nautobot App Metrics

### SonarQube Integration

Setup:
1. Access http://172.17.152.204:9000
2. Login: admin / admin (change password!)
3. Create project: "Nautobot Plugins"
4. Generate token
5. Add to GitHub Actions:
   ```yaml
   - name: SonarQube Scan
     uses: sonarsource/sonarqube-scan-action@master
     env:
       SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
       SONAR_HOST_URL: http://172.17.152.204:9000
   ```

---

## ⏪ Rollback Procedures

### Automatic Rollback

Helm automatically rolls back if:
- Init container fails (plugins don't install)
- Health checks fail
- Pods don't become Ready within 15 minutes

### Manual Rollback

```bash
# View deployment history
helm history nautobot -n nautobot

# Rollback to previous version
helm rollback nautobot -n nautobot

# Rollback to specific revision
helm rollback nautobot 5 -n nautobot

# Verify rollback
kubectl get pods -n nautobot
kubectl logs -n nautobot -l app.kubernetes.io/component=web
```

### Emergency Plugin Removal

If a plugin is causing issues:

1. **Edit nautobot.yml**:
   ```bash
   # Remove or comment out the problematic plugin
   vim group_vars/onprem/nautobot.yml
   ```

2. **Deploy**:
   ```bash
   git add group_vars/onprem/nautobot.yml
   git commit -m "fix: Remove problematic plugin"
   git push
   ```

3. **Or manual kubectl**:
   ```bash
   # Edit ConfigMap to remove plugin
   kubectl edit cm nautobot-config -n nautobot
   # Remove plugin from PLUGINS list and PLUGINS_CONFIG
   
   # Restart pods
   kubectl rollout restart deploy -n nautobot
   ```

---

## 🎓 Advanced Topics

### Multi-Environment Plugin Testing

Test plugin in dev before deploying to production:

```bash
# Test in dev
ansible-playbook -i inventory/k8s/dev.yml \
  playbooks/deploy_k8s_production.yml \
  -e "target_env=dev" \
  -e "git_token=$DEV_GITHUB_TOKEN"

# Promote to test
git checkout test-env
git merge feat/new-plugin
git push

# Promote to production
git checkout main
git merge test-env
git push
```

### Plugin Development Workflow

1. **Create Plugin Repo**
2. **Add to dependencies**:
   ```yaml
   # In your plugin's setup.py
   install_requires = [
       "nautobot>=3.0.0",
   ]
   ```

3. **Add to nautobot.yml**:
   ```yaml
   - name: "git+https://{{ git_auth_url_safe }}github.com/yourorg/nautobot-plugin-custom.git@develop"
     version: "develop"
     module_name: "nautobot_plugin_custom"
   ```

4. **Test Locally**:
   ```bash
   poetry add git+https://github.com/yourorg/nautobot-plugin-custom.git@develop
   nautobot-server migrate
   nautobot-server runserver
   ```

5. **Deploy to K8s**: Push to Git, watch deployment

### Private Registry Support

To use private Docker registries:

```yaml
# In helm/nautobot/values.yaml
image:
  repository: your-registry.com/nautobot
  tag: "3.0.6-custom"
  pullPolicy: Always
  pullSecrets:
    - name: registry-credentials
```

Create pull secret:
```bash
kubectl create secret docker-registry registry-credentials \
  --docker-server=your-registry.com \
  --docker-username=user \
  --docker-password=pass \
  -n nautobot
```

### Custom Init Scripts

Add custom initialization to Helm chart:

```yaml
# In templates/deployment-web.yaml
initContainers:
  - name: custom-setup
    image: busybox
    command:
      - sh
      - -c
      - |
        echo "Running custom setup..."
        # Your custom logic here
```

---

## 📚 References

- [Nautobot Documentation](https://docs.nautobot.com)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [MetalLB Configuration](https://metallb.universe.tf/configuration/)
- [Prometheus Operator](https://prometheus-operator.dev/)

---

## 🆘 Support

For issues:
1. Check logs: `kubectl logs -n nautobot <pod-name> -c install-plugins`
2. Review Helm status: `helm status nautobot -n nautobot`
3. Check Prometheus: http://172.17.152.203:9090
4. Review Grafana dashboards: http://172.17.152.202

Contact: DevOps Team / Nautobot Administrators
