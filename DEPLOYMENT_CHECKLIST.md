# Pre-Deployment Checklist

Use this checklist to ensure you have everything ready before deploying.

## ✅ Prerequisites

### Tools Installation

- [ ] **Azure CLI** installed
  ```bash
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  az --version
  ```

- [ ] **Terraform** (>= 1.5.0) installed
  ```bash
  terraform --version
  ```

- [ ] **Ansible** (>= 2.15.0) installed
  ```bash
  ansible --version
  ```

- [ ] **Python 3.11+** installed
  ```bash
  python3 --version
  pip3 install pyyaml
  ```

- [ ] **Git** installed
  ```bash
  git --version
  ```

### Azure Setup

- [ ] **Azure subscription** active
- [ ] **Logged in to Azure CLI**
  ```bash
  az login
  az account show
  ```
- [ ] **Sufficient quota** in target region
  ```bash
  az vm list-usage --location eastus --output table
  ```
  - Need at least 10 vCPUs available

### SSH Keys

- [ ] **SSH key pair generated**
  ```bash
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/nautobot-azure -C "nautobot@azure"
  ```
- [ ] **Public key ready** (`~/.ssh/nautobot-azure.pub`)

## ✅ Configuration

### Terraform Variables

- [ ] Copied `terraform.tfvars.example` to `terraform.tfvars`
  ```bash
  cd terraform/environments/dev
  cp terraform.tfvars.example terraform.tfvars
  ```

- [ ] Updated `admin_ssh_public_key` with your public key
  ```hcl
  admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
  ```

- [ ] Updated `ssh_source_addresses` with your IP
  ```bash
  # Get your public IP
  curl ifconfig.me
  ```
  ```hcl
  ssh_source_addresses = ["YOUR_IP/32"]
  ```

- [ ] Reviewed other settings:
  - [ ] `project_name` (default: "nautobot")
  - [ ] `location` (default: "eastus")
  - [ ] Network CIDRs
  - [ ] VM sizes

### Ansible Configuration

- [ ] Reviewed `ansible.cfg`
- [ ] Ansible vault password configured (if using vault)
  ```bash
  echo "your-vault-password" > vault_pass.txt
  chmod 600 vault_pass.txt
  ```

### Network Planning

- [ ] **VNet CIDR** doesn't conflict with existing networks
  - Default: 10.0.0.0/16
  
- [ ] **Subnet allocation** reviewed:
  - Frontend: 10.0.1.0/24
  - App: 10.0.2.0/24
  - Data: 10.0.3.0/24

- [ ] **Static IPs** for data tier noted:
  - PostgreSQL: 10.0.3.10
  - Redis: 10.0.3.11

## ✅ Pre-Deployment Tests

### Terraform Validation

- [ ] Initialize Terraform
  ```bash
  cd terraform/environments/dev
  terraform init
  ```

- [ ] Validate configuration
  ```bash
  terraform validate
  ```

- [ ] Run plan (no apply yet)
  ```bash
  terraform plan
  ```
  - [ ] Review resources to be created (~20 resources)
  - [ ] Check for any errors
  - [ ] Verify resource names and locations

### Ansible Validation

- [ ] Syntax check
  ```bash
  cd /home/ubuntu/ansible/nautobot_ansible_app
  ansible-playbook playbooks/deploy_vm_all.yml --syntax-check
  ```

- [ ] Scripts are executable
  ```bash
  chmod +x scripts/*.sh scripts/*.py
  ```

## ✅ Security Review

- [ ] **SSH access** restricted to your IP only
- [ ] **Ansible vault** passwords secured
- [ ] **No sensitive data** in git (check .gitignore)
- [ ] **Azure credentials** properly secured
- [ ] **Service Principal** created (if using CI/CD)
  ```bash
  az ad sp create-for-rbac --name "nautobot-terraform" \
    --role contributor \
    --scopes /subscriptions/SUBSCRIPTION_ID \
    --sdk-auth
  ```

## ✅ Documentation Review

- [ ] Read [ARCHITECTURE.md](ARCHITECTURE.md)
- [ ] Read [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- [ ] Review [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- [ ] Understand [COMPLETE_FLOW.md](COMPLETE_FLOW.md)

## ✅ Backup & Rollback Plan

- [ ] **Backup strategy** defined
  - PostgreSQL backup schedule
  - Terraform state backup location
  
- [ ] **Rollback procedure** understood
  ```bash
  ./scripts/destroy_infrastructure.sh dev
  ```

- [ ] **Contact information** for support team

## ✅ Cost Estimate Accepted

- [ ] **Monthly cost** reviewed and approved
  - Dev: ~$270/month
  - Test: ~$450/month
  - Prod: ~$1000/month

- [ ] **Budget alerts** set up in Azure

## ✅ Final Checks

- [ ] **Target environment** confirmed (dev/test/prod)
- [ ] **Resource naming** convention reviewed
- [ ] **Tags** for cost tracking configured
- [ ] **Deployment time** scheduled
  - Terraform: 10-15 minutes
  - Ansible: 5-10 minutes
  - Total: ~30 minutes

- [ ] **Team notified** of deployment
- [ ] **Maintenance window** scheduled (if prod)

## 🚀 Ready to Deploy!

If all boxes are checked, you're ready to deploy:

```bash
cd /home/ubuntu/ansible/nautobot_ansible_app
./scripts/deploy_full_stack.sh dev
```

Or deploy manually:

```bash
# 1. Deploy infrastructure
cd terraform/environments/dev
terraform apply

# 2. Update inventory
cd ../../../
python3 scripts/update_inventory_from_terraform.py --environment dev

# 3. Deploy application
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml
```

## 📝 Post-Deployment Checklist

After deployment completes:

- [ ] **Access URL** working
  ```bash
  LB_IP=$(cd terraform/environments/dev && terraform output -raw lb_public_ip)
  curl -k https://$LB_IP
  ```

- [ ] **All VMs** responding
  ```bash
  ansible -i inventory/vm/dev.yml all -m ping
  ```

- [ ] **Load Balancer** health probes passing
  ```bash
  az network lb show --name lb-nautobot-dev --resource-group rg-nautobot-dev
  ```

- [ ] **Services** running on all VMs
  - PostgreSQL: `systemctl status postgresql`
  - Redis: `systemctl status redis`
  - Nautobot: `systemctl status nautobot`
  - Nginx: `systemctl status nginx`

- [ ] **Logs** checked for errors
  ```bash
  tail -f /opt/nautobot/logs/nautobot.log
  ```

- [ ] **Superuser created**
  ```bash
  sudo -u nautobot /opt/nautobot/venv/bin/nautobot-server createsuperuser
  ```

- [ ] **Login successful** via web interface

- [ ] **API accessible**
  ```bash
  curl -k https://$LB_IP/api/
  ```

- [ ] **Documentation updated** with deployment details

- [ ] **Monitoring** configured

- [ ] **Backups** scheduled

- [ ] **Team notified** of successful deployment

## 🔧 Troubleshooting Resources

If issues occur, refer to:

1. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#troubleshooting)
2. [QUICK_REFERENCE.md](QUICK_REFERENCE.md#troubleshooting)
3. Azure Portal → Resource Group → Activity Log
4. Terraform state: `terraform show`
5. Ansible logs: Use `-vvv` flag

## 📞 Support Contacts

- **Documentation**: See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Azure Issues**: Azure Support Portal
- **Terraform Issues**: Check state file, run `terraform refresh`
- **Ansible Issues**: Check inventory and connectivity
- **Nautobot Issues**: Check logs at `/opt/nautobot/logs/`

---

**Date Completed**: _______________

**Deployed By**: _______________

**Environment**: _______________

**Load Balancer IP**: _______________

**Notes**: _______________________________________________

____________________________________________________________

____________________________________________________________
