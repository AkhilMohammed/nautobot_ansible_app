# Nautobot Azure Infrastructure - Terraform

This Terraform configuration creates the complete Azure infrastructure for deploying Nautobot in an NTC-style architecture.

## Architecture Overview

```
Internet → Azure Load Balancer → Nautobot Web VMs (VM Scale Set)
                                      ↓
                              Nautobot Workers VMs
                              Nautobot Scheduler VM
                                      ↓
                              PostgreSQL VM (with Data Disk)
                              Redis VM
```

## Components Created

### Network Infrastructure
- Virtual Network with multiple subnets (web, app, data)
- Network Security Groups with proper rules
- NAT Gateway for outbound connectivity
- Public IPs for Load Balancer

### Compute Resources
- **Web Tier**: VM Scale Set (2-10 instances) for Nautobot Web/API
- **Worker Tier**: VM Scale Set (2-5 instances) for Nautobot Workers
- **Scheduler**: Single VM for Nautobot Scheduler
- **Database**: Single VM for PostgreSQL with managed disk
- **Cache**: Single VM for Redis

### Load Balancing
- Azure Load Balancer with:
  - HTTP (80) → HTTPS (443) redirect
  - HTTPS (443) → Backend pool
  - Health probes
  - Load balancing rules

### Storage
- Managed disks for PostgreSQL data
- Boot diagnostics storage account

### Security
- Managed Identities for VMs
- NSG rules (least privilege)
- Key Vault integration (optional)

## Prerequisites

1. Azure CLI installed and authenticated
2. Terraform >= 1.5.0
3. Azure subscription with appropriate permissions

## Quick Start

```bash
# 1. Initialize Terraform
cd terraform/environments/dev
terraform init

# 2. Review the plan
terraform plan -out=tfplan

# 3. Apply the infrastructure
terraform apply tfplan

# 4. Get outputs (IP addresses, VM names)
terraform output

# 5. Update Ansible inventory with new IPs
terraform output -json > ../../../inventory/vm/terraform_dev.json
python3 ../../../scripts/update_inventory.py

# 6. Run Ansible deployment
cd ../../../
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml

# 7. Access Nautobot
# Get Load Balancer IP: terraform output lb_public_ip
```

## Directory Structure

```
terraform/
├── modules/
│   ├── network/          # VNet, Subnets, NSGs
│   ├── compute/          # VMs, Scale Sets
│   ├── loadbalancer/     # Azure Load Balancer
│   ├── storage/          # Managed Disks
│   └── security/         # NSGs, Key Vault
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   ├── test/
│   └── prod/
└── README.md
```

## Environment-Specific Deployment

Each environment (dev/test/prod) has its own configuration:

### Dev Environment
- 2 Web VMs (autoscale: 2-4)
- 2 Worker VMs (autoscale: 2-3)
- 1 Scheduler VM
- Basic SKU Load Balancer
- Standard_B2s VM size

### Test Environment
- 2 Web VMs (autoscale: 2-6)
- 2 Worker VMs (autoscale: 2-4)
- 1 Scheduler VM
- Standard SKU Load Balancer
- Standard_B4ms VM size

### Prod Environment
- 3 Web VMs (autoscale: 3-10)
- 3 Worker VMs (autoscale: 3-5)
- 1 Scheduler VM (with HA standby)
- Standard SKU Load Balancer with redundancy
- Standard_D4s_v3 VM size

## Outputs

After deployment, Terraform outputs:

```hcl
lb_public_ip              # Load Balancer Public IP
web_vmss_name            # Web VM Scale Set name
worker_vmss_name         # Worker VM Scale Set name
scheduler_vm_name        # Scheduler VM name
postgres_vm_private_ip   # PostgreSQL VM IP
redis_vm_private_ip      # Redis VM IP
resource_group_name      # Resource Group name
```

## Integration with Ansible

The Terraform output is automatically consumed by Ansible:

```bash
# After terraform apply
terraform output -json > ../../../scripts/terraform_output.json

# Python script updates Ansible inventory
python3 scripts/update_inventory.py

# Deploy with Ansible
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml
```

## Cost Optimization

- Use Azure Reserved Instances for production
- Enable auto-shutdown for dev/test environments
- Use Azure Spot VMs for non-critical worker nodes
- Implement proper tagging for cost allocation

## Scaling

### Manual Scaling
```bash
# Scale web tier
az vmss scale --name nautobot-web-vmss --new-capacity 5 --resource-group rg-nautobot-dev

# Scale worker tier
az vmss scale --name nautobot-worker-vmss --new-capacity 3 --resource-group rg-nautobot-dev
```

### Auto-scaling
Auto-scaling is configured based on:
- CPU usage (>70% scale up, <30% scale down)
- Memory usage
- Custom metrics (queue depth for workers)

## Monitoring

Deploy with Azure Monitor:
- VM Insights enabled
- Application Insights for Nautobot
- Log Analytics workspace
- Alerts for critical metrics

## Disaster Recovery

- PostgreSQL: Automated backups with 7-day retention
- VM Images: Weekly snapshots
- Cross-region replication (prod only)

## Security Considerations

1. **Network Security**
   - NSGs with least privilege
   - Private endpoints for storage
   - No public IPs on backend VMs

2. **Identity & Access**
   - Managed Identities for Azure resource access
   - RBAC for Terraform service principal
   - Key Vault for secrets

3. **Compliance**
   - Encryption at rest (managed disks)
   - TLS 1.2+ for all connections
   - Audit logging enabled

## Troubleshooting

### Terraform Issues
```bash
# Refresh state
terraform refresh

# Show state
terraform show

# Taint resource to force recreation
terraform taint module.compute.azurerm_linux_virtual_machine.scheduler
```

### VM Issues
```bash
# SSH to VM via bastion or serial console
az vm run-command invoke \
  --resource-group rg-nautobot-dev \
  --name nautobot-scheduler-vm \
  --command-id RunShellScript \
  --scripts "systemctl status nautobot"
```

## Clean Up

```bash
# Destroy infrastructure
cd terraform/environments/dev
terraform destroy

# Verify cleanup
az group list --query "[?name=='rg-nautobot-dev']"
```

## CI/CD Pipeline Integration

See `.github/workflows/terraform-deploy.yml` for automated deployment pipeline.

## Support

For issues or questions:
1. Check Terraform logs: `TF_LOG=DEBUG terraform apply`
2. Check Azure Activity Log in portal
3. Review Ansible logs: `/opt/nautobot/logs/`
