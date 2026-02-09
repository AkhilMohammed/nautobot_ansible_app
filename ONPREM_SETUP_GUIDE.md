# On-Premises Nautobot Deployment Guide

## 📋 Overview

This guide will help you deploy Nautobot on 8 on-premises VMs with automated GitLab CI/CD pipeline.

### VM Allocation (8 VMs Total)

| VM # | Role | Hostname | IP Address (Example) | Purpose |
|------|------|----------|---------------------|---------|
| 1 | GitLab Runner | onprem-runner-01 | 192.168.1.18 | CI/CD Pipeline execution |
| 2 | Web Node 1 | onprem-nautobot-web-01 | 192.168.1.11 | Nautobot web interface |
| 3 | Web Node 2 | onprem-nautobot-web-02 | 192.168.1.12 | Nautobot web interface (HA) |
| 4 | Worker 1 | onprem-nautobot-worker-01 | 192.168.1.13 | Celery worker |
| 5 | Worker 2 | onprem-nautobot-worker-02 | 192.168.1.14 | Celery worker |
| 6 | Scheduler | onprem-nautobot-scheduler-01 | 192.168.1.15 | Celery beat scheduler |
| 7 | PostgreSQL | onprem-postgres-01 | 192.168.1.16 | Database server |
| 8 | Redis | onprem-redis-01 | 192.168.1.17 | Cache and message broker |

---

## 🚀 Quick Start

### Step 1: Configure Your VM IP Addresses

Edit the inventory file with your actual VM IPs:

```bash
vim inventory/vm/onprem.yml
```

**Replace these values:**
- All `192.168.1.XX` IP addresses with your actual VM IPs
- `your_username` with your SSH username (e.g., ubuntu, centos, root)

### Step 2: Configure Passwords and Secrets

1. **Copy the vault example file:**
```bash
cp group_vars/onprem/vault.yml.example group_vars/onprem/vault.yml
```

2. **Edit and add your passwords:**
```bash
vim group_vars/onprem/vault.yml
```

**Required passwords to set:**
- `vault_ssh_password`: Your VM SSH password
- `vault_database_password`: PostgreSQL password for Nautobot
- `vault_postgres_admin_password`: PostgreSQL admin password
- `vault_redis_password`: Redis password
- `vault_nautobot_secret_key`: 50-character random string
- `vault_nautobot_superuser_password`: Nautobot admin password
- `vault_gitlab_runner_token`: GitLab runner registration token

**Generate a secret key:**
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(50))"
```

3. **Encrypt the vault file:**
```bash
ansible-vault encrypt group_vars/onprem/vault.yml
# Enter a vault password when prompted - REMEMBER THIS PASSWORD!
```

4. **Save your vault password to a file (optional but recommended):**
```bash
echo "your_vault_password_here" > .vault_pass
chmod 600 .vault_pass
```

### Step 3: Update Database and Redis IPs

Edit the Nautobot configuration:
```bash
vim group_vars/onprem/nautobot.yml
```

Update these lines with your actual IPs:
- Line ~28: `host: "192.168.1.16"` (PostgreSQL VM IP)
- Line ~35: `host: "192.168.1.17"` (Redis VM IP)
- Lines ~45-47: Update allowed_hosts with your web node IPs

### Step 4: Test Ansible Connection

Test connectivity to all VMs:
```bash
ansible -i inventory/vm/onprem.yml all -m ping --ask-vault-pass
```

You should see "SUCCESS" for all 8 VMs.

### Step 5: Deploy Infrastructure (PostgreSQL + Redis)

```bash
ansible-playbook -i inventory/vm/onprem.yml \
  playbooks/deploy_onprem_all.yml \
  --tags "postgres,redis" \
  --ask-vault-pass
```

### Step 6: Deploy Nautobot Application

```bash
ansible-playbook -i inventory/vm/onprem.yml \
  playbooks/deploy_onprem_all.yml \
  --tags "nautobot,web,worker,scheduler" \
  --ask-vault-pass
```

### Step 7: Setup GitLab Runner (for CI/CD)

```bash
ansible-playbook -i inventory/vm/onprem.yml \
  playbooks/setup_gitlab_runner.yml \
  --ask-vault-pass
```

---

## 🔄 Using GitLab CI/CD Pipeline

### Get GitLab Runner Token

1. Go to your GitLab project
2. Navigate to: **Settings** → **CI/CD** → **Runners**
3. Click **"New project runner"**
4. Copy the registration token
5. Add it to your `group_vars/onprem/vault.yml` as `vault_gitlab_runner_token`

### Configure Pipeline

The `.gitlab-ci.yml` file is already configured. To use it:

1. **Copy vault password to runner VM:**
```bash
# On your runner VM
sudo su - gitlab-runner
echo "your_vault_password" > /home/gitlab-runner/vault_pass.txt
chmod 600 /home/gitlab-runner/vault_pass.txt
```

2. **Update `.gitlab-ci.yml` vault password path:**
Edit `.gitlab-ci.yml` and change:
```yaml
--vault-password-file /path/to/vault_pass.txt
```
to:
```yaml
--vault-password-file /home/gitlab-runner/vault_pass.txt
```

3. **Commit and push:**
```bash
git add .
git commit -m "Configure on-prem deployment"
git push origin feat/onprem-deployment
```

4. **Run pipeline in GitLab:**
   - Go to: **CI/CD** → **Pipelines**
   - Click **"Run pipeline"**
   - Select stages to run manually

---

## 📍 Where to Add IPs and Passwords - Quick Reference

| What | Where | File |
|------|-------|------|
| **VM IP Addresses** | Inventory file | `inventory/vm/onprem.yml` |
| **SSH Usernames** | Inventory file | `inventory/vm/onprem.yml` |
| **All Passwords** | Vault file (encrypted) | `group_vars/onprem/vault.yml` |
| **PostgreSQL IP** | Config file | `group_vars/onprem/nautobot.yml` (line ~28) |
| **Redis IP** | Config file | `group_vars/onprem/nautobot.yml` (line ~35) |
| **Allowed Hosts** | Config file | `group_vars/onprem/nautobot.yml` (lines ~45-47) |
| **GitLab Runner Token** | Vault file | `group_vars/onprem/vault.yml` |

---

## 🛠️ Useful Commands

### Check inventory
```bash
ansible-inventory -i inventory/vm/onprem.yml --list
```

### Test connection to specific group
```bash
ansible -i inventory/vm/onprem.yml nautobot_web -m ping --ask-vault-pass
```

### Deploy to specific hosts
```bash
ansible-playbook -i inventory/vm/onprem.yml \
  playbooks/deploy_onprem_all.yml \
  --limit onprem-nautobot-web-01 \
  --ask-vault-pass
```

### View encrypted vault
```bash
ansible-vault view group_vars/onprem/vault.yml
```

### Edit encrypted vault
```bash
ansible-vault edit group_vars/onprem/vault.yml
```

### Rollback deployment
```bash
ansible-playbook -i inventory/vm/onprem.yml \
  playbooks/rollback.yml \
  --ask-vault-pass
```

---

## 🔐 Security Best Practices

1. **Never commit unencrypted passwords**
   - Always use ansible-vault for sensitive data
   - Add `.vault_pass` to `.gitignore`

2. **Use SSH keys instead of passwords (recommended)**
   - Generate SSH key: `ssh-keygen -t ed25519`
   - Copy to all VMs: `ssh-copy-id user@vm-ip`
   - Remove `ansible_ssh_pass` from inventory

3. **Restrict Ansible vault password access**
   ```bash
   chmod 600 .vault_pass
   ```

4. **Use different passwords for each environment**
   - Dev, Test, Prod should have different credentials

---

## 🐛 Troubleshooting

### Cannot connect to VMs
```bash
# Test SSH manually
ssh your_username@192.168.1.11

# Check firewall
sudo ufw status
sudo ufw allow 22/tcp
```

### Ansible vault errors
```bash
# Decrypt vault
ansible-vault decrypt group_vars/onprem/vault.yml

# Re-encrypt vault
ansible-vault encrypt group_vars/onprem/vault.yml
```

### PostgreSQL connection failed
```bash
# Check PostgreSQL is running
ansible -i inventory/vm/onprem.yml postgres -a "systemctl status postgresql" --become --ask-vault-pass

# Check PostgreSQL listens on correct IP
ansible -i inventory/vm/onprem.yml postgres -a "cat /etc/postgresql/*/main/postgresql.conf | grep listen_addresses" --become --ask-vault-pass
```

### GitLab Runner not picking up jobs
```bash
# Check runner status
gitlab-runner status

# Re-register runner
gitlab-runner register
```

---

## 📞 Support

For issues or questions:
1. Check the main [README.md](README.md)
2. Review [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
3. Check Ansible logs: `/var/log/ansible.log`
4. Check Nautobot logs: `/opt/nautobot/logs/`

---

## ✅ Next Steps

After successful deployment:

1. **Access Nautobot Web UI:**
   - URL: `http://192.168.1.11:8000` (or your web node IP)
   - Username: `admin` (from vault)
   - Password: (from `vault_nautobot_superuser_password`)

2. **Setup Load Balancer (Optional):**
   - Configure HAProxy or Nginx to balance between web nodes
   - Update `allowed_hosts` with load balancer IP

3. **Configure Backups:**
   - Setup PostgreSQL backups
   - Backup Nautobot media files

4. **Monitor Health:**
   - Check `/health/` endpoint
   - Setup monitoring (Prometheus, Grafana)

Good luck with your deployment! 🚀
