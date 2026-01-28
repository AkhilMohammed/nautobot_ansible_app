# Nautobot Azure Deployment - NTC Style with Managed Services

Complete Infrastructure-as-Code solution for deploying Nautobot on Azure using **Azure-managed PostgreSQL and Redis** (no VM-based databases), following Network to Code (NTC) architecture pattern.

## 🎯 Overview

This project provides a production-ready deployment of Nautobot on Azure with:

- **Azure Database for PostgreSQL Flexible Server**: Managed PaaS (not VM-based)
- **Azure Cache for Redis**: Managed PaaS (not VM-based)
- **Direct VM Deployment**: Web, Worker, and Scheduler on Azure VMs (no Docker/K8s)
- **Terraform**: Automated infrastructure provisioning
- **Ansible**: Application deployment and configuration
- **Azure Load Balancer**: High availability for web tier

## 🏗️ Architecture

```
Internet → Azure Load Balancer → Web VMs (1-3 instances)
                                      ↓
                              Worker VMs (1-3)
                              Scheduler VM (1-2)
                                      ↓
                       ┌──────────────┴──────────────┐
                       │                             │
          Azure Database for PostgreSQL    Azure Cache for Redis
          (Managed PaaS Service)            (Managed PaaS Service)
```

**Key Differences from Traditional Setup**:
- ✅ Azure-managed PostgreSQL (not VM-based)
- ✅ Azure-managed Redis (not VM-based)
- ✅ No Docker containers
- ✅ No Kubernetes
- ✅ Direct systemd services on VMs

**Full Documentation**: See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)

## 🚀 Quick Start

### Prerequisites

- Azure CLI (logged in)
- Terraform >= 1.5.0
- Ansible >= 2.15.0
- Python 3.11+
- SSH key pair

### Deploy in 3 Steps

```bash
# 1. Configure
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your SSH key and IPs

# 2. Deploy everything
cd ../../../
./scripts/deploy_full_stack.sh dev

# 3. Access Nautobot
# Get IP: cd terraform/environments/dev && terraform output lb_public_ip
# Visit: https://<LOAD_BALANCER_IP>
```

## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Complete deployment instructions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture and design details
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick commands and tips

## 📁 Project Structure

```
nautobot_ansible_app/
├── terraform/                    # Infrastructure as Code
│   ├── modules/
│   │   ├── network/             # VNet, Subnets, NSGs
│   │   ├── compute/             # VMs and VM Scale Sets
│   │   ├── loadbalancer/        # Azure Load Balancer
│   │   └── storage/             # Storage Accounts
│   └── environments/
│       ├── dev/                 # Dev environment
│       ├── test/                # Test environment
│       └── prod/                # Production environment
│
├── playbooks/                   # Ansible Playbooks
│   ├── deploy_vm_all.yml        # Complete deployment
│   ├── deploy_app_only.yml      # App-only deployment
│   └── rollback.yml             # Rollback playbook
│
├── roles/                       # Ansible Roles
│   ├── vm_postgres/             # PostgreSQL setup
│   ├── vm_redis/                # Redis setup
│   ├── vm_nautobot_app/         # Nautobot web application
│   ├── vm_nautobot_worker/      # Celery workers
│   └── vm_nautobot_scheduler/   # Celery beat scheduler
│
├── inventory/                   # Ansible Inventory
│   └── vm/
│       ├── dev.yml              # Dev inventory (auto-generated)
│       ├── test.yml             # Test inventory
│       └── prod.yml             # Prod inventory
│
├── scripts/                     # Helper Scripts
│   ├── deploy_full_stack.sh     # Complete deployment
│   ├── update_inventory_from_terraform.py  # Inventory updater
│   ├── scale_vmss.sh            # Scale VM Scale Sets
│   ├── get_vmss_ips.sh          # Get VMSS instance IPs
│   └── destroy_infrastructure.sh # Cleanup script
│
└── .github/workflows/           # CI/CD Pipeline
    └── deploy.yml               # GitHub Actions workflow
```

## 🎛️ Key Features

### Infrastructure (Terraform)

✅ **Network**
- Virtual Network with 3-tier subnet design
- Network Security Groups with least-privilege rules
- NAT Gateway for outbound connectivity
- Azure Load Balancer with health probes

✅ **Compute**
- VM Scale Sets with auto-scaling (web and worker tiers)
- Single VMs for scheduler, PostgreSQL, Redis
- Managed Identities for secure Azure access
- Cloud-init for initial VM configuration

✅ **Storage**
- Managed disks for PostgreSQL data
- Boot diagnostics storage
- Automated backup support

### Application (Ansible)

✅ **Nautobot Deployment**
- PostgreSQL 14+ with dedicated data disk
- Redis for caching and message broker
- Nautobot web (Nginx + Gunicorn)
- Celery workers for background jobs
- Celery beat scheduler for periodic tasks

✅ **Configuration Management**
- Templated configurations
- Environment-specific variables
- Ansible Vault for secrets
- Automated service management

### CI/CD

✅ **GitHub Actions**
- Automated Terraform plan on PR
- Auto-deploy on merge to main
- Manual deployment triggers
- Environment-specific workflows

## 🔧 Common Operations

### Deploy

```bash
# Complete deployment
./scripts/deploy_full_stack.sh dev

# Infrastructure only
cd terraform/environments/dev
terraform apply

# Application only
ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml
```

### Scale

```bash
# Scale web tier
./scripts/scale_vmss.sh dev web 5

# Scale worker tier
./scripts/scale_vmss.sh dev worker 3

# Update inventory after scaling
python3 scripts/update_inventory_from_terraform.py --environment dev
```

### Monitor

```bash
# Get VM status
az vm list -g rg-nautobot-dev --output table

# Get VMSS instance IPs
./scripts/get_vmss_ips.sh dev web

# View logs
ssh azureuser@<VM_IP>
sudo tail -f /opt/nautobot/logs/nautobot.log
```

### Destroy

```bash
./scripts/destroy_infrastructure.sh dev
```

## 📊 Resource Sizing

### Development Environment

| Component | Type | Count | Size | Cost/Month |
|-----------|------|-------|------|------------|
| Web | VMSS | 2 | Standard_B2ms | $60 |
| Worker | VMSS | 2 | Standard_B2ms | $60 |
| Scheduler | VM | 1 | Standard_B2s | $30 |
| PostgreSQL | VM | 1 | Standard_D2s_v3 | $70 |
| Redis | VM | 1 | Standard_B2s | $30 |
| Load Balancer | Standard | 1 | - | $20 |
| **Total** | | | | **~$270** |

### Production Environment

| Component | Type | Count | Size | Cost/Month |
|-----------|------|-------|------|------------|
| Web | VMSS | 3-10 | Standard_D4s_v3 | $400 |
| Worker | VMSS | 3-5 | Standard_D4s_v3 | $300 |
| Scheduler | VM | 1 | Standard_D2s_v3 | $70 |
| PostgreSQL | VM | 1 | Standard_D4s_v3 | $140 |
| Redis | VM | 1 | Standard_D2s_v3 | $70 |
| Load Balancer | Standard | 1 | - | $20 |
| **Total** | | | | **~$1000** |

## 🔒 Security

- ✅ Private networking for data tier (no public IPs)
- ✅ Network Security Groups (NSGs) with least privilege
- ✅ SSH key authentication only
- ✅ Managed Identities for Azure resource access
- ✅ Ansible Vault for secrets management
- ✅ TLS/SSL on Load Balancer
- ✅ Optional: Azure Bastion for secure VM access

## 🎯 Use Cases

This deployment is ideal for:

- **Network Source of Truth**: Manage network device inventory and configurations
- **IPAM**: IP address management and tracking
- **Network Automation**: Automated device configuration and compliance
- **Documentation**: Single source of truth for network infrastructure
- **Custom Applications**: Extensible platform for custom network tools

## 🔄 CI/CD Pipeline

### Workflow

```
Developer Push → GitHub
       ↓
Terraform Plan (on PR)
       ↓
Manual Approval
       ↓
Terraform Apply (on merge)
       ↓
Update Inventory
       ↓
Ansible Deploy
       ↓
Health Checks
       ↓
Notify Team
```

### Setup

1. Create Azure Service Principal:
   ```bash
   az ad sp create-for-rbac --name "nautobot-terraform" \
     --role contributor --scopes /subscriptions/{subscription-id} \
     --sdk-auth
   ```

2. Add GitHub Secrets:
   - `AZURE_CREDENTIALS`: Output from above
   - `SSH_PRIVATE_KEY`: Your SSH private key

3. Push to main branch to trigger deployment

## 📝 Environment Variables

Required in `terraform.tfvars`:

```hcl
admin_ssh_public_key = "ssh-rsa AAAAB3..."
ssh_source_addresses = ["1.2.3.4/32"]  # Your IP
project_name         = "nautobot"
location             = "eastus"
```

## 🤝 Contributing

1. Create feature branch
2. Test changes in dev environment
3. Submit PR with Terraform plan
4. After approval, merge to main

## 📞 Support

- **Documentation**: Check `DEPLOYMENT_GUIDE.md` and `ARCHITECTURE.md`
- **Issues**: Open GitHub issue
- **Quick Help**: See `QUICK_REFERENCE.md`

## 📜 License

Internal use only. See your organization's license policy.

## 🙏 Acknowledgments

- Network to Code (NTC) for architecture patterns
- Nautobot community for the amazing platform
- HashiCorp for Terraform
- Red Hat for Ansible

---

**Ready to deploy?** → Start with [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

**Need quick commands?** → See [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

**Want to understand the design?** → Read [ARCHITECTURE.md](ARCHITECTURE.md)