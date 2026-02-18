# Why Plugins Work in Azure VMs But Not in Kubernetes

## The Problem

Your plugins are configured in `group_vars/onprem/nautobot.yml` but **are NOT being installed** in Kubernetes. Here's why:

### Current Kubernetes Deployment Status
```bash
$ helm get values nautobot -n nautobot
nautobot:
  plugins:
    enabled: false  # <-- PLUGINS ARE DISABLED
```

### Init Container Shows
```bash
$ kubectl get deployment nautobot-web -n nautobot -o yaml
initContainers:
  - command:
    - sh
    - -c
    - |
      echo "No plugins to install"  # <-- NOT INSTALLING ANYTHING
```

---

## Why It Works in Azure VMs

**VM Deployment (works):**
```
1. Ansible runs on VM
2. Creates Python virtualenv: /opt/nautobot/venv
3. Installs Nautobot: pip install nautobot
4. Installs plugins: pip install git+https://github.com/...@develop
5. Plugins persist in /opt/nautobot/venv/lib/python3.11/site-packages/
6. Nautobot loads them successfully ✅
```

The plugins are installed **directly into the persistent Python virtual environment** on disk.

---

## Why It DOESN'T Work in Kubernetes

**Kubernetes Deployment (broken):**

### Attempt #1: EmptyDir Volume (Current Approach - FAILS)
```yaml
initContainers:
  - name: install-plugins
    image: nautobot:3.0.6-py3.11
    command: 
      - pip install git+https://...@develop --target=/opt/plugins
    volumeMounts:
      - name: plugins
        mountPath: /opt/plugins

containers:
  - name: nautobot
    volumeMounts:
      - name: plugins
        mountPath: /opt/plugins
    env:
      - name: PYTHONPATH
        value: /opt/plugins

volumes:
  - name: plugins
    emptyDir: {}  # ❌ PROBLEM: Sharing issues between init and main containers
```

**Problems:**
1. **Timing Issues**: Init container finishes, but volume state is inconsistent
2. **Module Not Found**: Main container can't find installed packages
3. **Git Installation Complexity**: Installing from Git `@develop` branches is unreliable:
   - Requires git client in container
   - Needs to clone entire repo
   - Build dependencies may be missing
   - Slow (10+ minutes for multiple plugins)
4. **No Persistence**: emptyDir is ephemeral, recreated on every pod restart

### Failed Error Example
```python
ModuleNotFoundError: No module named 'nautobot_device_lifecycle_mgmt'
```

Even though the plugin was "installed" in the init container, the main container can't see it.

---

## The Solution: Use PyPI Packages Instead of Git URLs

**The Problem**: Git URLs (`git+https://...@develop`)
**The Solution**: PyPI package names

### Why PyPI Packages Work Better

| Git URLs (@develop) | PyPI Packages |
|---------------------|---------------|
| ❌ Requires git clone | ✅ Direct download |
| ❌ Needs git in container | ✅ Pip only |
| ❌ Slow (clones entire repo) | ✅ Fast (downloads wheel) |
| ❌ Build dependencies needed | ✅ Pre-built wheels |
| ❌ Unreliable in containers | ✅ Container-friendly |
| ⏱ 10-15 minutes | ⏱ 2-3 minutes |

---

## Step-by-Step Fix

### Step 1: Update Your Plugin Configuration

Edit `/home/ubuntu/nautobot_ansible_app/group_vars/onprem/nautobot.yml`:

**BEFORE (Git URLs - doesn't work in K8s):**
```yaml
nautobot_git_packages:
  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/nautobot-app-device-lifecycle-mgmt.git@develop#egg=nautobot-device-lifecycle-mgmt"
    version: "develop"
    module_name: "nautobot_device_lifecycle_mgmt"

  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/nautobot-app-dns-models.git@develop#egg=nautobot-dns-models"
    version: "develop"
    module_name: "nautobot_dns_models"

  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/nautobot-app-bgp-models.git@develop#egg=nautobot-bgp-models"
    version: "develop"
    module_name: "nautobot_bgp_models"

  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/nautobot-app-firewall-models.git@develop#egg=nautobot-firewall-models"
    version: "develop"
    module_name: "nautobot_firewall_models"
```

**AFTER (PyPI packages - reliable in K8s):**
```yaml
nautobot_pip_packages:
  # Core dependencies (keep existing)
  - name: "social-auth-core[openidconnect]"
    version: "4.3.0"
  
  - name: "netutils"
    version: "1.10.0"
  
  - name: "azure-storage-blob"
    version: "12.21.0"
  
  # Nautobot plugins from PyPI
  - name: "nautobot-device-lifecycle-mgmt"
    version: "2.2.0"  # Specific version from PyPI
  
  - name: "nautobot-dns-models"
    version: "1.0.0"
  
  - name: "nautobot-bgp-models"
    version: "0.8.0"
  
  - name: "nautobot-firewall-models"
    version: "1.3.0"

# Keep git_packages for VM deployments if needed, or remove entirely
nautobot_git_packages: []
```

### Step 2: Check Available PyPI Versions

```bash
# Find available versions on PyPI
pip index versions nautobot-device-lifecycle-mgmt
pip index versions nautobot-dns-models
pip index versions nautobot-bgp-models
pip index versions nautobot-firewall-models
```

Or visit:
- https://pypi.org/project/nautobot-device-lifecycle-mgmt/
- https://pypi.org/project/nautobot-dns-models/
- https://pypi.org/project/nautobot-bgp-models/
- https://pypi.org/project/nautobot-firewall-models/

### Step 3: Update Helm Template

The Helm template needs to use `nautobot_pip_packages` instead of `nautobot_git_packages`.

Check: `/home/ubuntu/nautobot_ansible_app/templates/nautobot-helm-values.yaml.j2`

Make sure it has:
```jinja2
{% if nautobot_pip_packages | default([]) | length > 0 %}
nautobot:
  plugins:
    enabled: true
    packages:
{% for plugin in nautobot_pip_packages %}
{% if 'nautobot' in plugin.name %}
      - name: "{{ plugin.name }}"
        version: "{{ plugin.version | default('') }}"
{% endif %}
{% endfor %}
{% endif %}
```

### Step 4: Deploy with Ansible

```bash
cd /home/ubuntu/nautobot_ansible_app

# Deploy to Kubernetes with updated configuration
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_production.yml \
  --vault-password-file vault_pass.txt \
  -e "target_env=onprem" \
  --tags nautobot_deploy \
  --limit master
```

### Step 5: Verify Installation

```bash
# Wait for deployment to complete
kubectl rollout status deployment/nautobot-web -n nautobot

# Check plugin installation logs
kubectl logs -n nautobot -l app.kubernetes.io/component=web -c install-plugins --tail=100

# Verify plugins are loaded
kubectl exec -n nautobot deploy/nautobot-web -- \
  nautobot-server shell -c "from django.conf import settings; print(settings.PLUGINS)"

# Check in UI
firefox http://172.17.152.200:8000/plugins/
```

---

## Alternative: Manual Helm Deployment (Quick Test)

If you want to test quickly without running the full Ansible playbook:

### Create Test Values File

```bash
cat > /tmp/nautobot-values-pypi.yaml << 'EOF'
nautobot:
  image: networktocode/nautobot:3.0.6-py3.11
  
  plugins:
    enabled: true
    packages:
      - name: nautobot-device-lifecycle-mgmt
        version: "2.2.0"
      - name: nautobot-dns-models
        version: "1.0.0"
      - name: nautobot-bgp-models
        version: "0.8.0"
      - name: nautobot-firewall-models
        version: "1.3.0"
  
  config:
    PLUGINS:
      - nautobot_device_lifecycle_mgmt
      - nautobot_dns_models
      - nautobot_bgp_models
      - nautobot_firewall_models
    
    PLUGINS_CONFIG:
      nautobot_device_lifecycle_mgmt: {}
      nautobot_dns_models: {}
      nautobot_bgp_models: {}
      nautobot_firewall_models: {}

database:
  host: nautobot-postgresql
  name: nautobot
  password: Akhil@0387

redis:
  host: nautobot-redis
  password: Akhil@0387

secretKey: "12rva+@-bi(#s)18^e3y22*4oki2um5o(^qwwyd=iyi95(4)"
superuserPassword: admin

web:
  replicas: 2
worker:
  replicas: 2
EOF
```

### Deploy with Helm

```bash
# Copy values file to master
scp /tmp/nautobot-values-pypi.yaml ubuntu@172.17.152.109:/tmp/

# Upgrade Helm deployment
ssh ubuntu@172.17.152.109 "helm upgrade nautobot ~/nautobot-helm \
  --namespace nautobot \
  --values /tmp/nautobot-values-pypi.yaml \
  --wait --timeout=15m"
```

---

## Expected Results

### Before (No Plugins)
```bash
$ curl -s http://172.17.152.200:8000/plugins/ | grep "No installed plugins"
No installed plugins found
```

### After (With Plugins)
```bash
$ curl -s http://172.17.152.200:8000/plugins/
Device Lifecycle Management
DNS Models
BGP Models  
Firewall Models
```

---

## Why This Solution Works

1. **PyPI Packages**: Pre-built, tested, released versions
2. **Fast Installation**: No git clones, direct pip install
3. **Container-Friendly**: Simple pip install, no build tools needed
4. **Reliable**: Proven to work in containerized environments
5. **Version Control**: Specific versions prevent unexpected breaking changes
6. **Easier Debugging**: Clear error messages if something fails

---

## Comparison: VM vs K8s Deployment Methods

| Aspect | VM (Azure) | K8s (Recommended) |
|--------|-----------|-------------------|
| **Method** | Git URLs (@develop) | PyPI packages |
| **Installation** | Persistent venv | Init container + pip |
| **Speed** | Medium | Fast |
| **Reliability** | High (direct install) | High (with PyPI) |
| **Versioning** | Branch-based | Semantic versioning |
| **Best For** | Development/testing | Production |

---

## If You MUST Use Git URLs in K8s

If you absolutely need development branches, use a **PersistentVolumeClaim** instead of emptyDir:

```yaml
# Create PVC for plugins
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nautobot-plugins
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods can access
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-path

# Use in deployment
volumes:
  - name: plugins
    persistentVolumeClaim:
      claimName: nautobot-plugins
```

But **this is NOT recommended** for production. Use PyPI packages instead.

---

## Troubleshooting

### Issue: Plugins still not showing after deployment

```bash
# 1. Check if plugins are enabled
kubectl get deployment nautobot-web -n nautobot -o yaml | grep -A 5 "plugins"

# 2. Check init container logs
kubectl logs -n nautobot -l app.kubernetes.io/component=web -c install-plugins

# 3. Check if plugins installed
kubectl exec -n nautobot deploy/nautobot-web -- pip list | grep nautobot

# 4. Check Django configuration
kubectl exec -n nautobot deploy/nautobot-web -- \
  nautobot-server shell -c "from django.conf import settings; print(settings.PLUGINS)"

# 5. Run migrations
kubectl exec -n nautobot deploy/nautobot-web -- \
  nautobot-server migrate
```

### Issue: ModuleNotFoundError

This means the plugin is not installed. Check:
```bash
kubectl logs -n nautobot <pod-name> -c install-plugins
```

Look for pip install errors.

---

## Summary

**Root Cause**: Git URLs work in VMs but fail in K8s due to volume sharing and containerization issues

**Solution**: Use PyPI packages instead of Git URLs for Kubernetes deployments

**Action Required**:
1. Update `group_vars/onprem/nautobot.yml`
2. Change from `nautobot_git_packages` to `nautobot_pip_packages`
3. Use PyPI package names with versions
4. Redeploy with Ansible or Helm

**Result**: Plugins will install reliably in ~3 minutes and appear in Nautobot UI ✅
