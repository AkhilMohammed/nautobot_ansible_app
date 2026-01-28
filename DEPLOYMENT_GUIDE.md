# Nautobot Azure VM Deployment Guide
## NTC-Style Architecture with Terraform and Ansible

This guide provides complete instructions for deploying Nautobot on Azure VMs using Terraform for infrastructure provisioning and Ansible for application deployment, following Network to Code (NTC) best practices.

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Detailed Setup](#detailed-setup)
5. [Deployment Workflow](#deployment-workflow)
6. [Scaling](#scaling)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

### Infrastructure Components

```
                    Internet
                       ↓
              [Azure Load Balancer]
                (Public IP: HTTPS/HTTP)
                       ↓
         ┌─────────────┴──────────────┐
         ↓                            ↓
[Web VM Scale Set]          [Web VM Scale Set]
  (2-10 instances)            (Auto-scaling)
         ↓                            ↓
         └─────────────┬──────────────┘
                       ↓
         ┌─────────────┴──────────────┐
         ↓                            ↓
[Worker VMSS]              [Scheduler VM]
  (2-5 instances)            (Single)
         ↓                            ↓
         └─────────────┬──────────────┘
                       ↓
         ┌─────────────┴──────────────┐
         ↓                            ↓
  [PostgreSQL VM]              [Redis VM]
   (Data disk)                  (Cache)
```

### Azure Resources Created

1. **Networking**
   - Virtual Network (VNet) with 3 subnets (frontend, app, data)
   - Network Security Groups (NSGs) with least-privilege rules
   - NAT Gateway for outbound connectivity
   - Public IP for Load Balancer

2. **Compute**
   - PostgreSQL VM (with dedicated data disk)
   - Redis VM
   - Nautobot Scheduler VM
   - Web VMSS (2-10 instances with auto-scaling)
   - Worker VMSS (2-5 instances with auto-scaling)

3. **Load Balancing**
   - Azure Load Balancer (Standard SKU)
   - Health probes (HTTP/HTTPS)
   - Load balancing rules
   - Backend pools

4. **Storage**
   - Managed disks for PostgreSQL
   - Boot diagnostics storage account

5. **Security**
   - Managed Identities for VMs
   - NSG rules
   - Private networking for data tier

---

## 📦 Prerequisites

### Required Tools

1. **Azure CLI**
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   az login
   ```

2. **Terraform (>= 1.5.0)**
   ```bash
   wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
   unzip terraform_1.5.7_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   terraform version
   ```

3. **Ansible (>= 2.15.0)**
   ```bash
   pip3 install ansible pyyaml
   ansible --version
   ```

4. **Python 3.11+**
   ```bash
   python3 --version
   pip3 install pyyaml
   ```

### Azure Requirements

1. **Azure Subscription** with sufficient quota for:
   - VMs: 10+ vCPUs
   - Public IPs: 2
   - Load Balancers: 1

2. **Azure Permissions**: Contributor role or equivalent

3. **SSH Key Pair**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/nautobot-azure -C "nautobot@azure"
   ```

---

## 🚀 Quick Start (10 Minutes)

### 1. Clone and Configure

```bash
cd /home/ubuntu/ansible/nautobot_ansible_app

# Copy Terraform variables
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
nano terraform.tfvars
```

**Required Changes in `terraform.tfvars`:**
```hcl
admin_ssh_public_key = "ssh-rsa AAAAB3Nza... your-actual-key-here"
ssh_source_addresses = ["YOUR_IP/32"]  # Your public IP for SSH access
```

### 2. Deploy Everything

```bash
cd /home/ubuntu/ansible/nautobot_ansible_app

# Run complete deployment (Terraform + Ansible)
./scripts/deploy_full_stack.sh dev
```

This script will:
1. ✅ Check prerequisites
2. ✅ Deploy Azure infrastructure (10-15 min)
3. ✅ Update Ansible inventory automatically
4. ✅ Test connectivity
5. ✅ Deploy Nautobot application (5-10 min)
6. ✅ Display access URL

### 3. Access Nautobot

```bash
# Get the Load Balancer IP
cd terraform/environments/dev
terraform output lb_public_ip

# Access in browser
https://<LOAD_BALANCER_IP>
```

---

## 🔧 Detailed Setup

### Step-by-Step Manual Deployment

#### Step 1: Initialize Terraform

```bash
cd terraform/environments/dev
terraform init
```

#### Step 2: Review Infrastructure Plan

```bash
terraform plan -out=tfplan
```

Review the resources that will be created:
- Resource Group
- VNet and Subnets
- NSGs
- Load Balancer
- 5 VMs (Postgres, Redis, Scheduler, 2x Web, 2x Worker)

#### Step 3: Apply Infrastructure

```bash
terraform apply tfplan
```

Wait 10-15 minutes for deployment.

#### Step 4: Get Terraform Outputs

```bash
terraform output
terraform output -json > ../../../scripts/terraform_output.json
```

#### Step 5: Update Ansible Inventory

```bash
cd ../../../  # Back to project root
python3 scripts/update_inventory_from_terraform.py --environment dev
```

This creates/updates: `inventory/vm/dev.yml`

#### Step 6: Verify Connectivity

```bash
ansible -i inventory/vm/dev.yml all -m ping
```

Expected output:
```
dev-nautobot-postgres | SUCCESS => ...
dev-nautobot-redis | SUCCESS => ...
dev-nautobot-scheduler | SUCCESS => ...
dev-nautobot-web-00 | SUCCESS => ...
dev-nautobot-web-01 | SUCCESS => ...
dev-nautobot-worker-00 | SUCCESS => ...
dev-nautobot-worker-01 | SUCCESS => ...
```

#### Step 7: Deploy Nautobot with Ansible

```bash
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml -e "deploy_env=dev"
```

This will:
1. Install PostgreSQL and Redis
2. Deploy Nautobot Web, Workers, and Scheduler
3. Configure Nginx with SSL
4. Start all services

---

## 📊 Deployment Workflow

### Complete Flow

```
Developer/Ops
     ↓
[Git Push/Manual Trigger]
     ↓
[1. Terraform Apply]
     ↓
  Azure Creates:
  - VNet, Subnets, NSGs
  - Load Balancer
  - VM Scale Sets
  - Individual VMs
     ↓
[2. Python Script]
     ↓
  Updates Ansible Inventory
  with VM IPs
     ↓
[3. Ansible Playbook]
     ↓
  Deploys to Each VM:
  - PostgreSQL → Data VM
  - Redis → Cache VM
  - Web → Web VMSS instances
  - Worker → Worker VMSS instances
  - Scheduler → Scheduler VM
     ↓
[Load Balancer]
     ↓
  Distributes traffic to
  Web VMSS instances
     ↓
[End User Access]
  https://<LOAD_BALANCER_IP>
```

### CI/CD Pipeline

The included GitHub Actions workflow (`.github/workflows/deploy.yml`) automates:

1. **On Pull Request**: Terraform plan and comment
2. **On Merge to Main**: Terraform apply + Ansible deploy
3. **Manual Trigger**: Deploy to any environment

**Setup GitHub Secrets:**
```bash
# Create Azure Service Principal
az ad sp create-for-rbac \
  --name "nautobot-terraform" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth

# Add to GitHub Secrets:
# - AZURE_CREDENTIALS (JSON output from above)
# - SSH_PRIVATE_KEY (Your private SSH key)
```

---

## 📈 Scaling

### Manual Scaling

#### Scale Web Tier
```bash
./scripts/scale_vmss.sh dev web 5
```

#### Scale Worker Tier
```bash
./scripts/scale_vmss.sh dev worker 3
```

### Auto-Scaling (Pre-configured)

Auto-scaling is enabled by default:

**Web Tier:**
- Min: 2 instances
- Max: 10 instances
- Scale up: CPU > 70% for 5 minutes
- Scale down: CPU < 30% for 5 minutes

**Worker Tier:**
- Min: 2 instances
- Max: 5 instances
- Scale up: CPU > 75% for 5 minutes
- Scale down: CPU < 25% for 5 minutes

### After Scaling

Always update inventory:
```bash
python3 scripts/update_inventory_from_terraform.py --environment dev
```

Then deploy to new instances:
```bash
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml \
  --tags app,worker \
  -e "deploy_env=dev"
```

---

## 🔍 Monitoring & Maintenance

### Check VM Status

```bash
# Get all VMs in resource group
az vm list \
  --resource-group rg-nautobot-dev \
  --output table

# Get VMSS instances
./scripts/get_vmss_ips.sh dev web
./scripts/get_vmss_ips.sh dev worker
```

### View Logs

```bash
# SSH to a VM (use Azure Bastion or direct SSH)
az vmss list-instance-connection-info \
  --resource-group rg-nautobot-dev \
  --name vmss-nautobot-web-dev

# View Nautobot logs
ssh azureuser@<VM_IP>
sudo tail -f /opt/nautobot/logs/nautobot.log
```

### Health Checks

```bash
# Check Load Balancer health
az network lb show \
  --resource-group rg-nautobot-dev \
  --name lb-nautobot-dev \
  --query 'backendAddressPools[0].backendIpConfigurations[*].id'

# Test Nautobot API
LB_IP=$(cd terraform/environments/dev && terraform output -raw lb_public_ip)
curl -k https://$LB_IP/api/
```

### Backups

PostgreSQL backups are automated:
```bash
# Manual backup
ssh azureuser@<POSTGRES_VM_IP>
sudo su - postgres
pg_dump nautobot > /tmp/nautobot_backup_$(date +%Y%m%d).sql
```

---

## 🛠️ Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails

```bash
# Check Azure quota
az vm list-usage --location eastus --output table

# Refresh Terraform state
cd terraform/environments/dev
terraform refresh
```

#### 2. Ansible Connection Failures

```bash
# Test SSH directly
ssh -i ~/.ssh/nautobot-azure azureuser@<VM_IP>

# Check NSG rules
az network nsg rule list \
  --resource-group rg-nautobot-dev \
  --nsg-name nsg-app-dev \
  --output table

# Verify cloud-init completed
ssh azureuser@<VM_IP>
cloud-init status
```

#### 3. Load Balancer Not Working

```bash
# Check backend pool health
az network lb show \
  --resource-group rg-nautobot-dev \
  --name lb-nautobot-dev

# Check health probe
az network lb probe show \
  --resource-group rg-nautobot-dev \
  --lb-name lb-nautobot-dev \
  --name HealthProbeHTTPS

# Test directly on web VM
curl -k https://<WEB_VM_PRIVATE_IP>
```

#### 4. Nautobot Not Starting

```bash
# Check service status
ssh azureuser@<WEB_VM_IP>
sudo systemctl status nginx nautobot

# Check logs
sudo journalctl -u nautobot -f
tail -f /opt/nautobot/logs/nautobot.log
```

### Get Help

```bash
# Show Terraform outputs
cd terraform/environments/dev
terraform output

# Show Ansible inventory
cat inventory/vm/dev.yml

# Test Ansible connectivity
ansible -i inventory/vm/dev.yml all -m ping -vvv
```

---

## 🗑️ Cleanup

### Destroy Infrastructure

```bash
# Using script (with confirmations)
./scripts/destroy_infrastructure.sh dev

# Or manually
cd terraform/environments/dev
terraform destroy
```

**Warning:** This deletes ALL resources including databases!

---

## 📚 Additional Resources

- [Nautobot Documentation](https://docs.nautobot.com)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Ansible Azure Guide](https://docs.ansible.com/ansible/latest/scenario_guides/guide_azure.html)
- [Azure VM Scale Sets](https://docs.microsoft.com/azure/virtual-machine-scale-sets/)

---

## 🤝 Contributing

To contribute to this deployment:

1. Create a feature branch
2. Test in `dev` environment
3. Submit PR with Terraform plan output
4. After approval, merge triggers deployment

---

## 📝 License

This deployment configuration is provided as-is for internal use.

---

**Questions?** Contact your DevOps team or open an issue in the repository.
