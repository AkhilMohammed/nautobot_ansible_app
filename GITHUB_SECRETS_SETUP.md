# GitHub Actions Setup Guide

## Required GitHub Secrets

To enable automatic CI/CD deployment, configure these secrets in your GitHub repository:

### 📍 Location
`Repository → Settings → Secrets and variables → Actions → New repository secret`

### 🔑 Required Secrets

#### 1. **K8S_SSH_KEY** (Required)
**Description**: SSH private key to access the Kubernetes master node

**How to get**:
```bash
# Use your existing SSH key
cat ~/.ssh/id_rsa

# Or generate a new one specifically for GitHub Actions:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_actions_key -N ""
cat ~/.ssh/github_actions_key

# Copy the public key to K8s master:
ssh-copy-id -i ~/.ssh/github_actions_key.pub ubuntu@172.17.152.109
```

**Value**: Paste the **entire private key** including:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
...
-----END RSA PRIVATE KEY-----
```

#### 2. **K8S_MASTER_IP** (Required)
**Description**: IP address of your Kubernetes master node

**Value**: 
```
172.17.152.109
```
(Replace with your actual master IP from `inventory/k8s/onprem.yml`)

#### 3. **ANSIBLE_VAULT_PASSWORD** (Optional but Recommended)
**Description**: Password for decrypting Ansible vault encrypted variables

**How to get**:
```bash
# If you have vault_pass.txt:
cat vault_pass.txt

# If you don't use vault:
# Leave this secret empty or unconfigured
# The workflow will skip encrypted variables
```

**Value**: Your vault password (plain text)

**⚠️ Note**: If not configured, deployment will skip encrypted variables (database passwords, API keys, etc.). You'll need to set these manually or use plain text in group_vars.

#### 4. **K8S_VERSION** (Optional)
**Description**: Kubernetes version for validation

**Default**: `1.28.15`

**Value**:
```
1.28.15
```

### 🏭 Production-Only Secrets (Optional)

If deploying to production environment, add:

#### **K8S_PROD_SSH_KEY**
SSH key for production K8s cluster

#### **K8S_PROD_MASTER_IP**
IP address of production master node

#### **PROD_APPROVERS**
GitHub usernames for deployment approval (comma-separated)
```
user1,user2
```

## ✅ Verify Setup

### Option 1: Check via GitHub UI
1. Go to: `Repository → Settings → Secrets and variables → Actions`
2. Verify you see:
   - ✅ K8S_SSH_KEY
   - ✅ K8S_MASTER_IP
   - ✅ ANSIBLE_VAULT_PASSWORD (optional)

### Option 2: Trigger Test Run
```bash
# Make a small change
echo "# test" >> group_vars/dev/nautobot.yml

# Commit and push
git add group_vars/dev/nautobot.yml
git commit -m "test: trigger CI/CD"
git push origin develop

# Watch: GitHub → Actions tab
```

## 🚨 Troubleshooting

### "vault password file not found"
**Cause**: `ANSIBLE_VAULT_PASSWORD` secret not configured
**Solution**: 
- Option A: Add the secret with your vault password
- Option B: Remove vault encryption from your group_vars

### "Permission denied (publickey)"
**Cause**: `K8S_SSH_KEY` incorrect or not authorized
**Solution**:
1. Verify the private key format (includes BEGIN/END lines)
2. Ensure public key is in `~/.ssh/authorized_keys` on master node
3. Test SSH access manually:
   ```bash
   ssh -i ~/.ssh/your_key ubuntu@172.17.152.109
   ```

### "Could not find required secret"
**Cause**: Secret name mismatch
**Solution**: Verify secret names match exactly (case-sensitive):
- `K8S_SSH_KEY` (not `K8S_SSH_KEY_DEV`)
- `K8S_MASTER_IP` (not `K8S_MASTER_IP_DEV`)

## 🔐 Security Best Practices

### 1. **Use Dedicated Keys**
Create separate SSH keys for GitHub Actions:
```bash
ssh-keygen -t rsa -b 4096 -C "github-actions@yourcompany.com" -f ~/.ssh/github_actions
```

### 2. **Limit Key Permissions**
On K8s master, restrict the authorized_keys entry:
```bash
# ~/.ssh/authorized_keys
command="/usr/bin/kubectl",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-rsa AAAA...
```

### 3. **Rotate Secrets Regularly**
- Update SSH keys every 90 days
- Change vault passwords periodically
- Use secret scanning tools

### 4. **Use Environment Protection**
GitHub → Settings → Environments → Create "production"
- Required reviewers: 2+
- Wait timer: 5 minutes
- Deployment branches: main only

## 📋 Quick Setup Checklist

```bash
# 1. Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_actions_key -N ""

# 2. Copy to K8s master
ssh-copy-id -i ~/.ssh/github_actions_key.pub ubuntu@YOUR_MASTER_IP

# 3. Get values for secrets
cat ~/.ssh/github_actions_key  # Copy entire output for K8S_SSH_KEY
echo "YOUR_MASTER_IP"           # Copy for K8S_MASTER_IP
cat vault_pass.txt              # Copy for ANSIBLE_VAULT_PASSWORD (if used)

# 4. Add to GitHub
# Go to: Repository → Settings → Secrets → Actions → New secret
# Paste values for each secret

# 5. Test
git commit --allow-empty -m "test: trigger CI/CD"
git push origin develop
```

## 🎯 Without Vault (Simplified Setup)

If you're not using Ansible Vault:

1. **Skip** ANSIBLE_VAULT_PASSWORD secret
2. Ensure `group_vars/dev/nautobot.yml` has no `vault_*` variables
3. Set passwords directly (for dev only!):
   ```yaml
   nautobot_secret_key: "dev-secret-key-123"
   nautobot_admin_password: "admin123"
   nautobot_db:
     password: "nautobot123"
   ```
4. **⚠️ WARNING**: Never commit real passwords! Use vault for production.

## 📞 Need Help?

1. **Check workflow logs**: GitHub → Actions → Latest run → Job logs
2. **Test SSH manually**: `ssh -i ~/.ssh/your_key ubuntu@MASTER_IP`
3. **Verify inventory**: Check `inventory/k8s/onprem.yml` for correct IPs
4. **Check secrets**: Secrets → Actions → Verify all required secrets exist

---

**Ready to go?** Push a change to `develop` branch and watch the magic! 🚀
