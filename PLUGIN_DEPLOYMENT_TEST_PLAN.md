# Plugin Deployment Test Plan
**Quick Validation Guide for Production-Ready Automated Plugin System**

---

## ✅ Test 1: Verify Current Setup

### 1.1 Check Cluster Status
```bash
kubectl get nodes
# Expected: 5 nodes, all Ready
```

### 1.2 Check Nautobot Pods
```bash
kubectl get pods -n nautobot
# Expected:
# - nautobot-web-xxx (2 pods, Running)
# - nautobot-worker-xxx (2 pods, Running)
# - nautobot-scheduler-xxx (1 pod, Running)
# - nautobot-postgresql-xxx (1 pod, Running)
# - nautobot-redis-xxx (1 pod, Running)
```

### 1.3 Check LoadBalancer IPs
```bash
kubectl get svc -A | grep LoadBalancer
# Expected:
# nautobot         nautobot                172.17.152.200   8000
# ingress-nginx    ingress-nginx-controller 172.17.152.201  80,443
# monitoring       prometheus-grafana      172.17.152.202   80
# monitoring       prometheus-kube-prometheus 172.17.152.203 9090
# sonarqube        sonarqube               172.17.152.204   9000
```

### 1.4 Access Nautobot UI
```bash
curl -I http://172.17.152.200:8000
# Expected: HTTP/1.1 200 OK

# Or in browser
firefox http://172.17.152.200:8000 &
```

---

## ✅ Test 2: Verify Current Plugins

### 2.1 Check Installed Plugins in UI
1. Open http://172.17.152.200:8000
2. Login (admin / [vault password])
3. Navigate to: **Plugins** menu
4. Expected plugins:
   - Device Lifecycle Management
   - DNS Models (if enabled)
   - BGP Models (if enabled)
   - Firewall Models (if enabled)

### 2.2 Check ConfigMap
```bash
kubectl get cm nautobot-config -n nautobot -o yaml | grep -A 20 "PLUGINS ="
# Expected: List of module_name entries from nautobot.yml
```

### 2.3 Check Init Container Logs
```bash
# Get any web pod name
POD=$(kubectl get pod -n nautobot -l app.kubernetes.io/component=web -o jsonpath='{.items[0].metadata.name}')

# Check plugin installation logs
kubectl logs -n nautobot $POD -c install-plugins
# Expected:
# ==> Installing Nautobot plugins...
# Installing plugin: git+https://***@github.com/...
# ✓ Successfully installed: ...
# ==> All plugins installed successfully
```

---

## ✅ Test 3: Add a New Plugin (Golden Path Test)

### 3.1 Edit Configuration
```bash
cd /home/ubuntu/nautobot_ansible_app

# Backup current config
cp group_vars/onprem/nautobot.yml group_vars/onprem/nautobot.yml.backup

# Add Golden Config plugin (example)
cat >> group_vars/onprem/nautobot.yml << 'EOF'

  # Test: Golden Config Plugin
  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/nautobot-app-golden-config.git@develop"
    version: "develop"
    module_name: "nautobot_golden_config"
EOF

# Add plugin config
# Edit the nautobot_plugins_config section to add:
#   nautobot_golden_config: {}
```

### 3.2 Commit and Track Deployment

**Terminal 1 - Watch Pods:**
```bash
kubectl get pods -n nautobot -w
```

**Terminal 2 - Watch Events:**
```bash
kubectl get events -n nautobot -w
```

**Terminal 3 - Push Changes:**
```bash
git add group_vars/onprem/nautobot.yml
git commit -m "test: Add golden-config plugin"
git push origin feat/onprem-deployment
```

**Terminal 4 - Watch Logs:**
```bash
# Wait for deployment to trigger, then get new pod name
sleep 60
POD=$(kubectl get pod -n nautobot -l app.kubernetes.io/component=web -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n nautobot $POD -c install-plugins --follow
```

### 3.3 Expected Behavior

1. **Helm detects change** (within 1-2 minutes)
2. **Old pods start terminating**
3. **New pods enter Init:0/2**
4. **Init container logs show**:
   ```
   ==> Installing Nautobot plugins...
   Installing plugin: git+https://***@github.com/nautobot/nautobot-app-device-lifecycle-mgmt.git@develop
   ✓ Successfully installed: ...
   Installing plugin: git+https://***@github.com/nautobot/nautobot-app-golden-config.git@develop
   ✓ Successfully installed: git+https://***@github.com/nautobot/nautobot-app-golden-config.git@develop
   ==> All plugins installed successfully
   ```
5. **Pods transition to Running**
6. **Health checks pass**
7. **Deployment complete** (5-10 minutes total)

### 3.4 Verify New Plugin

```bash
# Check plugin in Django settings
kubectl exec -n nautobot deploy/nautobot-web -- \
  nautobot-server shell -c "from django.conf import settings; print('nautobot_golden_config' in settings.PLUGINS)"
# Expected: True

# Check in UI
# Navigate to: http://172.17.152.200:8000/plugins/
# Should see "Golden Config" plugin listed
```

---

## ✅ Test 4: Test Failure Scenario (Atomic Rollback)

### 4.1 Add Invalid Plugin
```bash
# Add a plugin that doesn't exist
cat >> group_vars/onprem/nautobot.yml << 'EOF'

  # Test: Invalid plugin (should fail)
  - name: "git+https://{{ git_auth_url_safe }}github.com/nautobot/this-plugin-does-not-exist.git@main"
    version: "main"
    module_name: "nautobot_invalid"
EOF

git add group_vars/onprem/nautobot.yml
git commit -m "test: Add invalid plugin (expect rollback)"
git push
```

### 4.2 Watch Rollback
```bash
# Watch deployment
kubectl get pods -n nautobot -w

# Watch Helm status
helm status nautobot -n nautobot --show-desc
```

### 4.3 Expected Behavior

1. **New pods start**
2. **Init container fails** with:
   ```
   ✗ Failed to install: git+https://***@github.com/nautobot/this-plugin-does-not-exist.git@main
   ERROR: Could not find a version that satisfies the requirement...
   ```
3. **Helm detects failure**
4. **Automatic rollback triggered**:
   ```
   Upgrade failed: atomic rollback performed
   ```
5. **Old pods restored**
6. **Service continues running** with previous plugin set

### 4.4 Verify Rollback
```bash
# Check Helm history
helm history nautobot -n nautobot
# Should show failed deployment and rollback

# Verify old plugins still work
kubectl exec -n nautobot deploy/nautobot-web -- \
  nautobot-server shell -c "from django.conf import settings; print(settings.PLUGINS)"
# Should NOT contain nautobot_invalid

# Restore backup
mv group_vars/onprem/nautobot.yml.backup group_vars/onprem/nautobot.yml
git add group_vars/onprem/nautobot.yml
git commit -m "fix: Restore valid plugin configuration"
git push
```

---

## ✅ Test 5: Verify Monitoring & Observability

### 5.1 Prometheus Metrics
```bash
# Access Prometheus
firefox http://172.17.152.203:9090 &

# Query examples:
# - up{namespace="nautobot"}
# - nautobot_request_duration_seconds
# - kube_pod_container_status_restarts_total{namespace="nautobot"}
```

### 5.2 Grafana Dashboards
```bash
# Get Grafana password
GRAFANA_PASS=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)
echo "Grafana password: $GRAFANA_PASS"

# Access Grafana
firefox http://172.17.152.202 &
# Login: admin / $GRAFANA_PASS

# Check dashboards:
# - Kubernetes Cluster Monitoring
# - Nautobot Application Metrics (if configured)
```

### 5.3 Check Alerts
```bash
# List active alerts
curl -s http://172.17.152.203:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state: .state, message: .annotations.message}'
```

### 5.4 SonarQube Setup
```bash
firefox http://172.17.152.204:9000 &
# Login: admin / admin
# Change password!
# Create project for Nautobot plugins
```

---

## ✅ Test 6: Performance & Scale Testing

### 6.1 Plugin Load Time
```bash
# Measure time from pod start to Ready
kubectl delete pod -n nautobot -l app.kubernetes.io/component=web
time kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=web -n nautobot --timeout=600s
# Expected: 2-5 minutes for full plugin installation + migrations
```

### 6.2 Multiple Plugin Addition
```bash
# Add 2-3 plugins simultaneously
# Edit nautobot.yml to add multiple plugins
# Measure total deployment time
# Expected: Linear increase (~1-2 minutes per plugin)
```

### 6.3 Worker Autoscaling
```bash
# Check HPA status
kubectl get hpa -n nautobot

# Generate load (if applicable)
# Watch workers scale
kubectl get pods -n nautobot -w
```

---

## 🎯 Success Criteria

### All Tests Must Pass:
- ✅ All 5 nodes Ready
- ✅ All LoadBalancer IPs assigned
- ✅ Nautobot accessible via UI
- ✅ Current plugins visible in UI
- ✅ New plugin deploys successfully
- ✅ Invalid plugin triggers rollback
- ✅ Service continues during rollback
- ✅ Prometheus collects metrics
- ✅ Grafana displays dashboards
- ✅ SonarQube accessible

### Performance Benchmarks:
- Plugin installation: < 2 minutes per plugin
- Total deployment: < 10 minutes for 4 plugins
- Rollback time: < 3 minutes
- Zero downtime during deployment

### Security Validation:
- Git tokens not exposed in logs ✅
- Secrets properly mounted ✅
- Non-root containers ✅
- Network policies enforced ✅

---

## 🐛 Troubleshooting Commands

```bash
# View all plugin installation logs
for pod in $(kubectl get pods -n nautobot -l app.kubernetes.io/name=nautobot -o name); do
  echo "=== $pod ==="
  kubectl logs -n nautobot $pod -c install-plugins 2>/dev/null || echo "No install-plugins container"
done

# Check Helm deployment status
helm list -n nautobot
helm status nautobot -n nautobot

# Check ConfigMap generation
kubectl get cm nautobot-config -n nautobot -o yaml > /tmp/nautobot-config.yaml
grep -A 50 "PLUGINS" /tmp/nautobot-config.yaml

# Check persistent volumes
kubectl get pvc -n nautobot
kubectl describe pvc -n nautobot

# Check pod resources
kubectl top pods -n nautobot

# Full event log
kubectl get events -n nautobot --sort-by='.lastTimestamp' | tail -50

# Database migrations status
kubectl exec -n nautobot deploy/nautobot-web -- \
  nautobot-server showmigrations | grep '\[ \]'
```

---

## 📝 Test Results Template

```
Date: _______________
Tester: _______________
Environment: onprem / dev / prod

Test 1 - Current Setup:        PASS / FAIL
Test 2 - Verify Plugins:       PASS / FAIL
Test 3 - Add New Plugin:       PASS / FAIL
Test 4 - Rollback Test:        PASS / FAIL
Test 5 - Monitoring:           PASS / FAIL
Test 6 - Performance:          PASS / FAIL

Plugin Install Time: ______ minutes
Total Deployment Time: ______ minutes
Rollback Time: ______ minutes

Issues Encountered:
_______________________________________
_______________________________________
_______________________________________

Notes:
_______________________________________
_______________________________________
_______________________________________
```

---

## 📚 Next Steps After Testing

If all tests pass:
1. ✅ Document in production runbook
2. ✅ Train team on plugin addition workflow
3. ✅ Set up monitoring alerts
4. ✅ Schedule regular plugin updates
5. ✅ Create plugin library/whitelist

If tests fail:
1. ❌ Review error logs
2. ❌ Check configuration files
3. ❌ Verify Git authentication
4. ❌ Test plugin compatibility
5. ❌ Contact support team
