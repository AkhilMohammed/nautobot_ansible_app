# AUTO CI/CD DEPLOYMENT - HOW IT WORKS

## 🎯 Overview

Your deployment now has **AUTOMATIC CI/CD** that triggers when you modify plugins!

## 🔄 How It Works

### 1. You Make a Change
Edit plugin configuration in any environment:
```yaml
# group_vars/dev/nautobot.yml
# group_vars/prod/nautobot.yml  
# group_vars/onprem/nautobot.yml

nautobot_plugins:
  - name: nautobot-golden-config
    version: "latest"
    config:
      enable_backup: true
```

### 2. Commit and Push
```bash
git add group_vars/onprem/nautobot.yml
git commit -m "Add golden-config plugin"
git push origin feat/onprem-deployment
```

### 3. GitHub Actions Auto-Triggers
The workflow automatically:
- ✅ Detects changes to `group_vars/**/nautobot.yml`
- ✅ Identifies if plugins section changed
- ✅ Determines deployment type (K8s or VM)
- ✅ Validates Ansible syntax
- ✅ **Automatically deploys** the changes!

### 4. Nautobot Gets Updated
- Installs/updates the plugin
- Runs database migrations
- Collects static files
- Restarts services/pods
- Zero downtime (K8s) or minimal downtime (VM)

## 📝 Adding a Plugin - Step by Step

### Example: Add Device Lifecycle Plugin

**Step 1: Edit Configuration**
```bash
vim group_vars/onprem/nautobot.yml
```

Add to the `nautobot_plugins` section:
```yaml
nautobot_plugins:
  - name: nautobot-device-lifecycle-mgmt
    version: "latest"
    config:
      barcoded_assets:
        - "DeviceType"
        - "Device"
```

**Step 2: Commit Changes**
```bash
git add group_vars/onprem/nautobot.yml
git commit -m "Add device lifecycle management plugin"
```

**Step 3: Push to GitHub**
```bash
git push origin feat/onprem-deployment
```

**Step 4: Watch Magic Happen** ✨
- Go to GitHub → Actions tab
- See workflow automatically start
- Watch deployment progress
- Get notified when complete

**Step 5: Verify**
- Access Nautobot UI
- Go to Plugins section
- See your new plugin installed!

## 🎮 Workflow Triggers

### Automatic Triggers (on push):
- `group_vars/**/nautobot.yml` - Config changes
- `group_vars/dev/**` - Dev environment
- `group_vars/prod/**` - Prod environment  
- `group_vars/onprem/**` - On-prem environment
- `playbooks/**` - Playbook changes
- `roles/**` - Role changes
- `helm/**` - Helm chart changes

### Manual Triggers:
- GitHub Actions UI → "Run workflow"
- Choose deployment type and stage

## 📊 Workflow Jobs

### 1. detect-changes
- Analyzes what files changed
- Determines deployment type (K8s/VM)
- Detects plugin modifications
- Sets environment (dev/prod/onprem)

### 2. validate
- Checks Ansible syntax
- Validates playbooks
- Ensures no errors

### 3. auto_deploy_k8s (Automatic)
- **Triggers**: When plugins or config changed in K8s setup
- Updates Helm deployment
- Rolls out new pods
- Zero downtime

### 4. auto_deploy_vm (Automatic)
- **Triggers**: When plugins or config changed in VM setup
- Updates application code
- Installs plugins
- Restarts services

## 🔌 Plugin Configuration Format

```yaml
nautobot_plugins:
  # From PyPI
  - name: nautobot-golden-config
    version: "latest"  # or "2.1.0"
    config:
      enable_backup: true
      enable_compliance: true

  # From Git repository
  - name: my-custom-plugin
    version: "main"
    git_url: "https://github.com/myorg/my-plugin.git"
    config:
      custom_setting: "value"

  # Minimal (no config needed)
  - name: nautobot-capacity-metrics
    version: "1.3.0"
```

## ⚡ Quick Commands

### Add a plugin:
```bash
# 1. Edit config
vim group_vars/onprem/nautobot.yml

# 2. Add plugin to nautobot_plugins list

# 3. Deploy
git add group_vars/onprem/nautobot.yml
git commit -m "Add <plugin-name>"
git push
```

### View deployment logs:
```bash
# GitHub UI
# Go to: Actions → Latest workflow → Job logs

# Or via API
gh run list
gh run watch
```

### Manual deployment if needed:
```bash
# From GitHub Actions UI
Actions → Deploy Nautobot On-Premises → Run workflow
  Deployment Type: k8s_production (or vm_deployment)
  Stage: full_stack
```

## 🎯 What Gets Deployed Automatically?

When you change `group_vars/**/nautobot.yml`:

### Kubernetes Deployment:
1. ✅ Helm chart updated with new plugin config
2. ✅ ConfigMap regenerated
3. ✅ Pods restarted with new config
4. ✅ Migrations run automatically
5. ✅ Static files collected
6. ✅ Health checks verify success

### VM Deployment:
1. ✅ Plugins installed via pip
2. ✅ Configuration updated
3. ✅ Migrations executed
4. ✅ Static files collected
5. ✅ Services restarted
6. ✅ Health checks run

## 🔐 Security

- Vault passwords stored in GitHub Secrets
- No credentials in code
- All sensitive data encrypted
- Secure vault file access

## 📈 Benefits

✅ **No Manual Deployment** - Just push code
✅ **Consistent** - Same process every time  
✅ **Auditable** - All changes tracked in Git
✅ **Reversible** - Can roll back via Git
✅ **Fast** - Automated pipeline saves time
✅ **Safe** - Validation before deployment
✅ **Visible** - See progress in GitHub UI

## 🎉 Example Workflow

```bash
# Morning: Add new plugin
vim group_vars/dev/nautobot.yml
# Add: nautobot-device-onboarding

git add group_vars/dev/nautobot.yml
git commit -m "Add device onboarding plugin to dev"
git push

# ☕ Grab coffee while it deploys automatically

# 5 minutes later: Plugin is live!
# Access Nautobot → See new plugin

# Afternoon: Test passed, deploy to prod
vim group_vars/prod/nautobot.yml
# Add same plugin

git add group_vars/prod/nautobot.yml
git commit -m "Add device onboarding plugin to prod"
git push

# ✅ Done! Prod updated automatically
```

## 💡 Tips

1. **Test in dev first** - Add plugins to dev environment before prod
2. **Use version pins** - Specify exact versions for prod (`version: "2.1.0"`)
3. **Check compatibility** - Verify plugin supports your Nautobot version
4. **Watch the logs** - Monitor GitHub Actions during deployment
5. **Small changes** - Deploy one plugin at a time for easier troubleshooting

## 🆘 Troubleshooting

**Workflow didn't trigger?**
- Check file path: must be `group_vars/**/nautobot.yml`
- Verify branch: must be `main` or `feat/onprem-deployment`
- Check GitHub Actions enabled in repo settings

**Deployment failed?**
- View logs in GitHub Actions
- Check vault password file exists on runner
- Verify inventory file has correct IPs
- Test Ansible connection manually

**Plugin not working?**
- Check Nautobot logs: `kubectl logs -n nautobot <pod>`
- Verify plugin compatibility with Nautobot version
- Check plugin configuration syntax
- Run migrations manually if needed

---

**Now you have fully automated CI/CD for Nautobot plugins!** 🚀

Just edit `group_vars/*/nautobot.yml`, commit, and push. GitHub Actions handles the rest!
