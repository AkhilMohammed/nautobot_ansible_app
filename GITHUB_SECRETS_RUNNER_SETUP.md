# GitHub Actions Setup Guide - Secrets & Runner Configuration

## 🎯 Overview

This guide walks you through:
1. ✅ Setting up GitHub Secrets (vault password)
2. ✅ Configuring VM credentials and database passwords
3. ✅ Setting up GitHub Actions self-hosted runner
4. ✅ Testing the automated pipeline

---

## 📋 Prerequisites

- GitHub repository with admin access
- On-premises VM for GitHub runner (IP: as defined in inventory)
- Ansible vault password (or create a new one)
- VM SSH credentials
- Database passwords

---

## STEP 1: Create and Encrypt Vault File

### 1.1 Create vault password file (local machine)

```bash
# Create a strong vault password
echo "MyVaultPassword123!" > vault_pass.txt
chmod 600 vault_pass.txt

# Add to .gitignore (already done, but verify)
echo "vault_pass.txt" >> .gitignore
```

⚠️ **IMPORTANT:** Never commit `vault_pass.txt` to Git!

---

### 1.2 Create vault.yml with your credentials

```bash
# Copy example file
cp group_vars/onprem/vault.yml.example group_vars/onprem/vault.yml

# Edit with your real credentials
vim group_vars/onprem/vault.yml
```

**Example configuration:**

```yaml
---
# SSH Access Credentials
vault_ssh_password: "YourVMPassword123!"

# Database Credentials
vault_database_name: "nautobot"
vault_database_user: "nautobot"
vault_database_password: "StrongDBPass123!"

# PostgreSQL Admin Credentials
vault_postgres_admin_user: "postgres"
vault_postgres_admin_password: "PostgresAdminPass123!"

# Redis Credentials
vault_redis_password: "RedisPass123!"

# Nautobot Application Secrets
vault_nautobot_secret_key: "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMN"  # 50 chars
vault_nautobot_superuser_username: "admin"
vault_nautobot_superuser_password: "NautobotAdmin123!"
vault_nautobot_superuser_email: "admin@yourdomain.com"

# GitHub Personal Access Token
vault_github_token: "ghp_YourGitHubPersonalAccessToken"

# GitHub Repository Information
vault_github_repo_owner: "your-github-username"
vault_github_repo_name: "nautobot_ansible_app"
```

---

### 1.3 Generate Nautobot Secret Key

```bash
# Generate a 50-character random secret key
python3 -c "import secrets; print(secrets.token_urlsafe(50)[:50])"
```

**Copy the output and paste it as `vault_nautobot_secret_key`**

---

### 1.4 Encrypt the vault file

```bash
ansible-vault encrypt group_vars/onprem/vault.yml --vault-password-file vault_pass.txt
```

**Expected output:**
```
Encryption successful
```

**Verify encryption:**
```bash
cat group_vars/onprem/vault.yml
# Should show encrypted content starting with $ANSIBLE_VAULT;1.1;AES256
```

---

## STEP 2: Setup GitHub Actions Runner

### 2.1 Deploy the runner to your VM

```bash
# Make sure you have Ansible installed locally
pip install ansible

# Run the runner setup playbook
ansible-playbook -i inventory/vm/onprem.yml \
  playbooks/setup_github_runner.yml \
  --vault-password-file vault_pass.txt
```

This will:
- ✅ Install GitHub Actions runner software
- ✅ Create `github-runner` user
- ✅ Install dependencies (Python, Ansible, Git)
- ✅ Configure sudo access

---

### 2.2 Get GitHub Runner Token

1. Go to your GitHub repository
2. Navigate to: **Settings → Actions → Runners**
3. Click: **New self-hosted runner**
4. Select: **Linux**
5. Copy the **runner token** (looks like: `ABCD1234...`)

**Direct URL:**
```
https://github.com/YOUR_USERNAME/nautobot_ansible_app/settings/actions/runners/new
```

---

### 2.3 Register the runner on VM

**SSH to your runner VM:**

```bash
# SSH to the runner VM
ssh user@<runner-vm-ip>

# Switch to github-runner user
sudo su - github-runner

# Navigate to runner directory
cd /home/github-runner/actions-runner

# Register the runner
./config.sh \
  --url https://github.com/YOUR_USERNAME/nautobot_ansible_app \
  --token YOUR_RUNNER_TOKEN_FROM_GITHUB \
  --labels onprem,self-hosted \
  --name onprem-runner

# Install as service
sudo ./svc.sh install github-runner

# Start the service
sudo ./svc.sh start

# Check status
sudo ./svc.sh status
```

**Expected output:**
```
● actions.runner.YOUR_USERNAME-nautobot_ansible_app.onprem-runner.service
   Active: active (running)
```

---

### 2.4 Create vault password file on runner

**Still on the runner VM:**

```bash
# Create vault password file (use same password as vault_pass.txt)
echo 'MyVaultPassword123!' | sudo tee /home/github-runner/.vault_pass

# Set permissions
sudo chown github-runner:github-runner /home/github-runner/.vault_pass
sudo chmod 600 /home/github-runner/.vault_pass

# Verify
sudo ls -la /home/github-runner/.vault_pass
# Should show: -rw------- 1 github-runner github-runner
```

---

## STEP 3: Configure GitHub Secrets

### 3.1 Add vault password file path

1. Go to: **Repository → Settings → Secrets and variables → Actions**
2. Click: **New repository secret**

**Add secret:**
```
Name: ANSIBLE_VAULT_PASSWORD_FILE
Value: /home/github-runner/.vault_pass
```

---

### 3.2 (Optional) Add individual secrets

If you prefer not to use vault files, you can add each secret individually:

**Add these secrets:**

| Secret Name | Example Value | Description |
|-------------|---------------|-------------|
| `ANSIBLE_VAULT_PASSWORD_FILE` | `/home/github-runner/.vault_pass` | **Required** - Path to vault password |
| `VM_SSH_PASSWORD` | `YourVMPassword123!` | Optional - VM SSH password |
| `DB_USER` | `nautobot` | Optional - Database username |
| `DB_PASSWORD` | `StrongDBPass123!` | Optional - Database password |
| `REDIS_PASSWORD` | `RedisPass123!` | Optional - Redis password |
| `NAUTOBOT_SECRET_KEY` | `random50chars...` | Optional - Nautobot secret |

**To add a secret:**
1. Click: **New repository secret**
2. Enter **Name** and **Value**
3. Click: **Add secret**

---

## STEP 4: Verify Setup

### 4.1 Check runner status

**On GitHub:**
1. Go to: **Settings → Actions → Runners**
2. You should see: **onprem-runner** with status: **Idle** (green dot)

---

### 4.2 Test the workflow

**Option A: Push a change**

```bash
# Make a small change
echo "# Testing CI/CD" >> README.md

git add README.md
git commit -m "Test CI/CD pipeline"
git push origin feat/onprem-deployment
```

**Option B: Manual trigger**

1. Go to: **Actions → Deploy Nautobot On-Premises**
2. Click: **Run workflow**
3. Select:
   - Branch: `feat/onprem-deployment`
   - Deployment Type: `k8s_production` or `vm_deployment`
   - Deployment Stage: `validate_only`
4. Click: **Run workflow**

---

### 4.3 Monitor execution

1. Go to: **Actions** tab
2. Click on the running workflow
3. Watch logs in real-time
4. Verify all steps complete successfully ✅

---

## STEP 5: Test Automatic Plugin Deployment

### 5.1 Add a plugin configuration

```bash
# Edit plugin config
vim group_vars/onprem/nautobot.yml
```

**Add a plugin:**

```yaml
nautobot_plugins:
  - name: nautobot-golden-config
    version: "latest"
    config:
      enable_backup: true
```

---

### 5.2 Commit and push

```bash
git add group_vars/onprem/nautobot.yml
git commit -m "Add golden-config plugin"
git push origin feat/onprem-deployment
```

---

### 5.3 Watch automatic deployment

1. GitHub Actions will **automatically trigger**
2. Workflow detects plugin changes
3. Deploys automatically to your cluster
4. Check logs in **Actions** tab

**Expected workflow jobs:**
- ✅ `detect-changes` - Detects plugin modification
- ✅ `validate` - Validates Ansible syntax
- ✅ `auto_deploy_k8s` or `auto_deploy_vm` - Deploys automatically

---

## 🔧 Troubleshooting

### Issue: Vault password error

**Error:**
```
ERROR! Attempting to decrypt but no vault secrets found
```

**Solution:**
```bash
# Verify vault file is encrypted
file group_vars/onprem/vault.yml
# Should output: "ASCII text" with ANSIBLE_VAULT header

# Verify password file on runner
ssh user@runner-vm
sudo cat /home/github-runner/.vault_pass

# Check GitHub Secret is set correctly
# Should be: /home/github-runner/.vault_pass (full path)
```

---

### Issue: Runner not picking up jobs

**Solution:**
```bash
# SSH to runner VM
ssh user@runner-vm

# Check service status
sudo systemctl status actions.runner.*

# Restart service
sudo systemctl restart actions.runner.*

# Check logs
sudo journalctl -u actions.runner.* -f
```

---

### Issue: Permission denied on runner

**Solution:**
```bash
# Verify github-runner has sudo access
sudo -u github-runner sudo whoami
# Should output: root

# Check sudoers file
sudo cat /etc/sudoers.d/github-runner
# Should contain: github-runner ALL=(ALL) NOPASSWD: ALL
```

---

### Issue: ansible-playbook command not found (Exit code 127)

**Solution:**
```bash
# SSH to runner VM
ssh user@runner-vm

# Install Ansible
sudo apt update
sudo apt install -y ansible python3-pip

# Verify installation
ansible --version
```

---

## 📊 Summary Checklist

- [ ] Created `vault_pass.txt` locally (never commit!)
- [ ] Created and encrypted `group_vars/onprem/vault.yml`
- [ ] Generated 50-character secret key for Nautobot
- [ ] Deployed GitHub Actions runner to VM
- [ ] Registered runner with GitHub (green dot visible)
- [ ] Created `.vault_pass` file on runner VM
- [ ] Added `ANSIBLE_VAULT_PASSWORD_FILE` GitHub Secret
- [ ] Tested workflow with manual trigger
- [ ] Tested automatic plugin deployment
- [ ] Runner successfully executes Ansible playbooks

---

## 🎯 Quick Reference

### Local development:
```bash
# Test playbook locally
ansible-playbook -i inventory/k8s/onprem.yml \
  playbooks/deploy_k8s_production.yml \
  --vault-password-file vault_pass.txt \
  --check
```

### View encrypted vault:
```bash
ansible-vault view group_vars/onprem/vault.yml \
  --vault-password-file vault_pass.txt
```

### Edit encrypted vault:
```bash
ansible-vault edit group_vars/onprem/vault.yml \
  --vault-password-file vault_pass.txt
```

### Check runner status:
```bash
ssh user@runner-vm
sudo systemctl status actions.runner.*
```

---

## ✅ Next Steps

After completing this setup:

1. **Test deployment:**
   ```bash
   git push origin feat/onprem-deployment
   # Watch in GitHub Actions
   ```

2. **Verify services:**
   ```bash
   kubectl get pods -n nautobot
   kubectl get svc -n nautobot
   ```

3. **Access Nautobot:**
   ```
   http://<master-node-ip>:30080
   ```

4. **Monitor logs:**
   ```bash
   kubectl logs -f -l app.kubernetes.io/name=nautobot -n nautobot
   ```

---

**🎉 Your CI/CD pipeline is now fully automated!**

Every time you:
- Add/modify plugins in `group_vars/*/nautobot.yml`
- Update playbooks, roles, or Helm charts
- Change inventory or configuration

GitHub Actions will automatically validate and deploy! 🚀
