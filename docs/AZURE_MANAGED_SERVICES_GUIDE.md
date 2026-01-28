# Azure Managed Services Deployment Guide

## Architecture Overview

This deployment uses **Azure-managed PaaS services** instead of VM-based databases:

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Load Balancer                      │
│                    (Public IP + FQDN)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
    ┌─────▼─────┐         ┌────▼──────┐
    │ Nautobot  │         │ Nautobot  │
    │  Web VM 1 │         │ Web VM 2  │
    └───────────┘         └───────────┘
          │                     │
          └──────────┬──────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼────┐      ┌───▼────┐     ┌────▼──────┐
│Worker  │      │Worker  │     │ Scheduler │
│  VM 1  │      │  VM 2  │     │    VM     │
└────────┘      └────────┘     └───────────┘
    │                │                │
    │                │                │
    └────────┬───────┴────────────────┘
             │
    ┌────────┼──────────────────┐
    │        │                  │
┌───▼─────────────────┐   ┌────▼─────────────────┐
│ Azure Database for  │   │ Azure Cache for      │
│ PostgreSQL          │   │ Redis                │
│ (Managed Service)   │   │ (Managed Service)    │
└─────────────────────┘   └──────────────────────┘
```

### Key Components

1. **Compute (VMs)**: Nautobot application servers (Web, Worker, Scheduler)
2. **Database**: Azure Database for PostgreSQL Flexible Server (Managed)
3. **Cache**: Azure Cache for Redis (Managed)
4. **Load Balancer**: Azure Load Balancer (Standard SKU)
5. **Storage**: Azure Storage Account (for static files and backups)
6. **Secrets**: Azure Key Vault
7. **Network**: Azure Virtual Network with subnets

## Prerequisites

### Tools Required

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install Ansible
sudo apt update
sudo apt install ansible python3-pip -y
pip3 install ansible-core boto3 azure-cli

# Install Python dependencies
pip3 install pyyaml jinja2
```

### Azure Setup

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create service principal for Terraform
az ad sp create-for-rbac \
  --name "nautobot-terraform-sp" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"

# Save the output - you'll need:
# - appId (ARM_CLIENT_ID)
# - password (ARM_CLIENT_SECRET)
# - tenant (ARM_TENANT_ID)
```

## Step-by-Step Deployment

### 1. Configure Terraform Backend

Create a storage account for Terraform state:

```bash
# Create resource group for Terraform state
az group create --name terraform-state-rg --location eastus

# Create storage account
az storage account create \
  --name tfstateXXXXX \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name tfstateXXXXX
```

Update `terraform/backend-<env>.hcl`:

```hcl
resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstateXXXXX"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
```

### 2. Configure Environment Variables

Create `.env` file:

```bash
export ARM_CLIENT_ID="<service-principal-app-id>"
export ARM_CLIENT_SECRET="<service-principal-password>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"

# Database password (will be stored in Key Vault)
export TF_VAR_db_admin_password="<strong-password>"
```

Load the variables:

```bash
source .env
```

### 3. Initialize Terraform

```bash
cd terraform

# Initialize for specific environment
terraform init -backend-config=backend-dev.hcl

# Validate configuration
terraform validate

# Plan deployment
terraform plan -var-file=environments/dev.tfvars -out=tfplan
```

### 4. Deploy Azure Infrastructure

```bash
# Apply Terraform
terraform apply tfplan

# This will create:
# - Azure Database for PostgreSQL Flexible Server
# - Azure Cache for Redis
# - VMs for Nautobot Web, Worker, Scheduler
# - Load Balancer
# - Virtual Network
# - Key Vault
# - Storage Account
```

**Deployment time**: ~15-20 minutes

### 5. Generate Ansible Inventory

```bash
cd ..
python3 scripts/terraform_to_ansible.py dev
```

This script will:
- Extract Terraform outputs
- Generate Ansible inventory (`inventory/vm/dev_dynamic.yml`)
- Create Terraform variables for Ansible (`group_vars/dev/terraform.yml`)
- Create secrets template (`group_vars/dev/vault_template.yml`)

### 6. Configure Secrets

```bash
# Copy template to vault.yml
cp group_vars/dev/vault_template.yml group_vars/dev/vault.yml

# Edit and add real secrets
nano group_vars/dev/vault.yml
```

Update the following secrets:

```yaml
---
# Get from Terraform outputs or Azure Key Vault
vault_database_password: "<postgresql-password>"
vault_redis_password: "<redis-access-key>"
vault_azure_storage_key: "<storage-account-key>"
vault_nautobot_secret_key: "<random-50-char-string>"

# Git credentials
vault_git_username: "<git-username>"
vault_git_token: "<git-pat-token>"
```

Get secrets from Terraform:

```bash
# Database password (set during terraform apply)
terraform output -raw postgresql_admin_username

# Redis password
terraform output -raw redis_primary_access_key

# Storage account key
az storage account keys list \
  --resource-group dev-nautobot-rg \
  --account-name <storage-account-name> \
  --query '[0].value' -o tsv
```

Encrypt the vault:

```bash
ansible-vault encrypt group_vars/dev/vault.yml
```

### 7. Test Connectivity

```bash
# Test SSH connectivity to VMs
ansible all -i inventory/vm/dev_dynamic.yml -m ping

# Test with vault password
ansible all -i inventory/vm/dev_dynamic.yml -m ping --ask-vault-pass
```

### 8. Deploy Nautobot Application

```bash
# Deploy all components
ansible-playbook -i inventory/vm/dev_dynamic.yml \
  playbooks/deploy_vm_all.yml \
  --ask-vault-pass

# Or deploy specific components:

# Web servers only
ansible-playbook -i inventory/vm/dev_dynamic.yml \
  playbooks/deploy_app_only.yml \
  --limit nautobot_web \
  --ask-vault-pass

# Worker servers only
ansible-playbook -i inventory/vm/dev_dynamic.yml \
  playbooks/deploy_app_only.yml \
  --limit nautobot_worker \
  --ask-vault-pass

# Scheduler only
ansible-playbook -i inventory/vm/dev_dynamic.yml \
  playbooks/deploy_app_only.yml \
  --limit nautobot_scheduler \
  --ask-vault-pass
```

### 9. Verify Deployment

```bash
# Get Load Balancer public IP
terraform output load_balancer_public_ip

# Access Nautobot
curl http://<load-balancer-ip>/
```

Or get from Azure:

```bash
az network public-ip show \
  --resource-group dev-nautobot-rg \
  --name dev-nautobot-lb-pip \
  --query 'ipAddress' -o tsv
```

### 10. Post-Deployment Tasks

```bash
# SSH to one of the web servers
ssh azureuser@<web-vm-ip>

# Create superuser
sudo su - nautobot
cd /opt/nautobot
source venv/bin/activate
nautobot-server createsuperuser

# Collect static files (if using Azure Storage)
nautobot-server collectstatic --noinput

# Run migrations (if needed)
nautobot-server migrate
```

## Azure Managed Services Configuration

### PostgreSQL Configuration

```bash
# Connect to PostgreSQL
az postgres flexible-server connect \
  --name dev-nautobot-psql \
  --admin-user psqladmin \
  --admin-password <password>

# View configuration
az postgres flexible-server parameter list \
  --resource-group dev-nautobot-rg \
  --server-name dev-nautobot-psql \
  --output table

# Update configuration
az postgres flexible-server parameter set \
  --resource-group dev-nautobot-rg \
  --server-name dev-nautobot-psql \
  --name max_connections \
  --value 200
```

### Redis Configuration

```bash
# Get Redis connection info
az redis show \
  --name dev-nautobot-redis \
  --resource-group dev-nautobot-rg

# Get access keys
az redis list-keys \
  --name dev-nautobot-redis \
  --resource-group dev-nautobot-rg

# Test Redis connection
redis-cli -h dev-nautobot-redis.redis.cache.windows.net \
  -p 6380 \
  -a <access-key> \
  --tls \
  ping
```

### Monitoring

Enable monitoring for managed services:

```bash
# Enable diagnostic settings for PostgreSQL
az monitor diagnostic-settings create \
  --name pgql-diagnostics \
  --resource <postgresql-resource-id> \
  --logs '[{"category": "PostgreSQLLogs", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]' \
  --workspace <log-analytics-workspace-id>

# Enable diagnostic settings for Redis
az monitor diagnostic-settings create \
  --name redis-diagnostics \
  --resource <redis-resource-id> \
  --logs '[{"category": "ConnectedClientList", "enabled": true}]' \
  --metrics '[{"category": "AllMetrics", "enabled": true}]' \
  --workspace <log-analytics-workspace-id>
```

## Environment-Specific Deployments

### Development

```bash
terraform apply -var-file=environments/dev.tfvars
python3 scripts/terraform_to_ansible.py dev
ansible-playbook -i inventory/vm/dev_dynamic.yml playbooks/deploy_vm_all.yml --ask-vault-pass
```

### Test

```bash
terraform workspace select test || terraform workspace new test
terraform apply -var-file=environments/test.tfvars
python3 scripts/terraform_to_ansible.py test
ansible-playbook -i inventory/vm/test_dynamic.yml playbooks/deploy_vm_all.yml --ask-vault-pass
```

### Production

```bash
terraform workspace select prod || terraform workspace new prod
terraform apply -var-file=environments/prod.tfvars
python3 scripts/terraform_to_ansible.py prod
ansible-playbook -i inventory/vm/prod_dynamic.yml playbooks/deploy_vm_all.yml --ask-vault-pass
```

## Scaling

### Scale Web Servers

```bash
# Update terraform/environments/<env>.tfvars
web_vm_count = 4

# Apply changes
terraform apply -var-file=environments/<env>.tfvars

# Regenerate inventory
python3 scripts/terraform_to_ansible.py <env>

# Deploy to new servers only
ansible-playbook -i inventory/vm/<env>_dynamic.yml \
  playbooks/deploy_app_only.yml \
  --limit nautobot_web \
  --ask-vault-pass
```

### Scale PostgreSQL

```bash
# Vertical scaling (change SKU)
az postgres flexible-server update \
  --name dev-nautobot-psql \
  --resource-group dev-nautobot-rg \
  --sku-name GP_Standard_D4s_v3

# Increase storage
az postgres flexible-server update \
  --name dev-nautobot-psql \
  --resource-group dev-nautobot-rg \
  --storage-size 65536
```

### Scale Redis

```bash
# Upgrade Redis SKU
az redis update \
  --name dev-nautobot-redis \
  --resource-group dev-nautobot-rg \
  --sku Standard \
  --vm-size C2
```

## Backup and Recovery

### PostgreSQL Backups

```bash
# Backups are automatic (7-30 days retention)
# Restore from backup:
az postgres flexible-server restore \
  --resource-group dev-nautobot-rg \
  --name dev-nautobot-psql-restore \
  --source-server dev-nautobot-psql \
  --restore-time "2026-01-27T00:00:00Z"
```

### Redis Persistence

```bash
# Premium tier supports persistence
# Configure in Terraform:
# redis_sku = "Premium"
# Add persistence settings in module
```

## Troubleshooting

### Check Terraform State

```bash
terraform show
terraform state list
terraform output
```

### Check Azure Resources

```bash
# List all resources in resource group
az resource list --resource-group dev-nautobot-rg --output table

# Check PostgreSQL status
az postgres flexible-server show \
  --name dev-nautobot-psql \
  --resource-group dev-nautobot-rg

# Check Redis status
az redis show \
  --name dev-nautobot-redis \
  --resource-group dev-nautobot-rg
```

### Check Connectivity

```bash
# Test PostgreSQL connection from VM
psql "host=dev-nautobot-psql.postgres.database.azure.com port=5432 dbname=nautobot user=psqladmin sslmode=require"

# Test Redis connection
redis-cli -h dev-nautobot-redis.redis.cache.windows.net -p 6380 -a <key> --tls ping
```

## Cost Optimization

### Development Environment

- Use **Burstable (B-series)** PostgreSQL SKU
- Use **Basic** Redis tier
- Use **LRS** storage replication
- Scale down or stop VMs when not in use

### Production Environment

- Use **Memory Optimized** PostgreSQL with High Availability
- Use **Premium** Redis with persistence
- Use **GZRS** storage replication
- Consider Azure Reserved Instances for VMs

## Security Best Practices

1. **Enable Private Endpoints** for PostgreSQL and Redis (production)
2. **Use Key Vault** for all secrets
3. **Enable SSL/TLS** for all connections
4. **Configure firewall rules** to restrict access
5. **Enable diagnostic logging** and monitoring
6. **Use managed identities** where possible
7. **Regular security updates** for VMs

## Next Steps

- Set up CI/CD pipeline (Azure DevOps or GitHub Actions)
- Configure monitoring and alerting
- Set up backup automation
- Configure disaster recovery
- Implement infrastructure testing
