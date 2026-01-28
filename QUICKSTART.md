# 🚀 NTC-Style Azure Deployment - Complete Flow

## Overview
This deploys Nautobot on Azure VMs with **Azure-managed PostgreSQL and Redis** (no Docker, no K8s).

## Quick Start
```bash
# 1. Deploy infrastructure
./scripts/deploy_complete.sh dev deploy

# 2. Configure secrets
cp group_vars/dev/vault_template.yml group_vars/dev/vault.yml
# Edit vault.yml, then:
ansible-vault encrypt group_vars/dev/vault.yml

# 3. Deploy application
ansible-playbook -i inventory/vm/dev_dynamic.yml playbooks/deploy_vm_all.yml --ask-vault-pass
```

## Architecture
- ✅ Direct VM deployment (Web, Worker, Scheduler)
- ✅ Azure Database for PostgreSQL (Managed PaaS)
- ✅ Azure Cache for Redis (Managed PaaS)
- ✅ Azure Load Balancer
- ❌ No Docker/Kubernetes
- ❌ No VM-based PostgreSQL/Redis

## Documentation
- [Complete Deployment Guide](docs/AZURE_MANAGED_SERVICES_GUIDE.md)
- [Architecture Details](COMPLETE_FLOW.md)
