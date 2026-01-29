# Azure DevOps Pipeline Setup Guide

## Prerequisites
- Azure DevOps account
- Azure subscription with deployed infrastructure
- Service Principal credentials
- SSH key pair for VM access

## Step 1: Create Variable Group

In Azure DevOps, create a **Variable Group** named `nautobot-azure-secrets`:

1. Go to **Pipelines** → **Library** → **+ Variable group**
2. Name: `nautobot-azure-secrets`
3. Add the following variables:

### Required Variables:

| Variable Name | Value | Secret? | Description |
|--------------|-------|---------|-------------|
| `ARM_CLIENT_ID` | `<service-principal-app-id>` | ✅ | Azure Service Principal App ID |
| `ARM_CLIENT_SECRET` | `<service-principal-password>` | ✅ | Azure Service Principal Password |
| `ARM_SUBSCRIPTION_ID` | `9b5bcc59-580a-4bd3-b729-4c4fd52e2682` | ❌ | Your Azure Subscription ID |
| `ARM_TENANT_ID` | `<your-tenant-id>` | ❌ | Azure Tenant ID |
| `STORAGE_ACCOUNT_NAME` | `tfstate87003` | ❌ | Terraform state storage account |
| `STORAGE_KEY` | `<storage-account-key>` | ✅ | Storage account access key |
| `DB_ADMIN_PASSWORD` | `<your-db-password>` | ✅ | PostgreSQL admin password |
| `SSH_PRIVATE_KEY` | `<your-private-key>` | ✅ | SSH private key (entire key including headers) |
| `VAULT_PASSWORD` | `<ansible-vault-password>` | ✅ | Ansible Vault password |

### Get Service Principal Credentials:

```bash
# In Azure Cloud Shell
az ad sp show --id <your-sp-app-id>

# Get tenant ID
az account show --query tenantId -o tsv

# Get storage account key
az storage account keys list \
  --resource-group terraform-state-rg \
  --account-name tfstate87003 \
  --query '[0].value' -o tsv
```

### Get SSH Private Key:

```bash
# In Azure Cloud Shell (where you generated the key)
cat ~/.ssh/id_rsa
```

Copy the entire output including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`

## Step 2: Create Pipeline

1. In Azure DevOps, go to **Pipelines** → **New Pipeline**
2. Select **Azure Repos Git**
3. Select your repository: **Nautobot**
4. Select **Existing Azure Pipelines YAML file**
5. Path: `/azure-pipelines.yml`
6. Branch: `feat/initial`
7. Click **Run**

## Step 3: Pipeline Stages

The pipeline has 3 stages:

### 1. **Terraform_Deploy** (Infrastructure)
- Installs Terraform 1.7.0
- Initializes backend with Azure Storage
- Plans and applies infrastructure changes
- Publishes Terraform outputs

### 2. **Ansible_Deploy** (Application)
- Installs Ansible and dependencies
- Queries Azure for VMSS instance IPs
- Creates dynamic inventory
- Deploys Nautobot application via Ansible
- Configures PostgreSQL and Redis connections

### 3. **Validation** (Optional - add this)
- Tests application endpoints
- Verifies database connectivity
- Checks Redis connectivity

## Step 4: Trigger Pipeline

The pipeline triggers automatically on:
- Commits to `main` branch
- Commits to `feat/*` branches

Or manually trigger:
1. Go to **Pipelines**
2. Select your pipeline
3. Click **Run pipeline**
4. Select branch: `feat/initial`
5. Click **Run**

## Step 5: Monitor Pipeline

1. Click on the running pipeline
2. Watch each stage execute:
   - ✅ Terraform Deploy (5-10 minutes)
   - ✅ Ansible Deploy (10-15 minutes)
3. View logs for troubleshooting

## Step 6: Access Nautobot

After successful deployment:

```bash
# Get Load Balancer IP
az network public-ip show \
  --resource-group dev-nautobot-rg \
  --name pip-lb-nautobot-dev \
  --query ipAddress -o tsv
```

Access: `http://<load-balancer-ip>`

## Troubleshooting

### SSH Connection Issues
- Verify SSH key format (no extra spaces/newlines)
- Check VMs are running: `az vmss list-instances`
- Verify NSG rules allow SSH from Azure Pipeline agents

### Terraform Backend Issues
- Verify storage account exists
- Check storage account key is correct
- Ensure service principal has access

### Ansible Vault Issues
- Verify vault password is correct
- Check vault files are encrypted: `ansible-vault view group_vars/dev/vault.yml`

### VM Quota Issues
- Free tier limit: 4 vCPUs
- Current usage: 2 VMs × 2 vCPUs = 4 vCPUs
- Request quota increase if needed

## Manual Deployment (Alternative)

If pipeline fails, deploy manually from Azure Cloud Shell:

```bash
cd ~/nautobot_ansible_app

# Get VM IPs
WEB_IPS=$(az vmss nic list --resource-group dev-nautobot-rg --vmss-name vmss-nautobot-web-dev --query "[].ipConfigurations[0].privateIpAddress" -o tsv)

# Create inventory
cat > inventory/vm/dev_manual.yml <<EOF
all:
  children:
    web_servers:
      hosts:
        $WEB_IPS:
  vars:
    ansible_user: azureuser
    environment: dev
EOF

# Deploy
ansible-playbook -i inventory/vm/dev_manual.yml \
  playbooks/deploy_app_only.yml \
  --vault-password-file vault_pass.txt \
  -e "deploy_env=dev"
```

## Pipeline Updates

To update the pipeline:

1. Edit `azure-pipelines.yml`
2. Commit and push:
   ```bash
   git add azure-pipelines.yml
   git commit -m "Update pipeline"
   git push azure feat/initial
   ```
3. Pipeline will automatically run on push

## Best Practices

1. **Always test in dev** before promoting to prod
2. **Use separate service principals** per environment
3. **Rotate secrets** regularly
4. **Enable pipeline approvals** for production deployments
5. **Monitor costs** in Azure Cost Management

## Next Steps

1. ✅ Create variable group
2. ✅ Add all secrets
3. ✅ Create pipeline from YAML
4. ✅ Run first deployment
5. ⏭️ Add smoke tests
6. ⏭️ Add production environment
7. ⏭️ Configure auto-scaling rules
