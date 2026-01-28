# Nautobot Azure Architecture
## NTC-Style VM-Based Deployment

## Overview

This document describes the complete architecture for deploying Nautobot on Azure using VM-based infrastructure (no Docker/Kubernetes), following Network to Code (NTC) best practices.

## Architecture Diagram

```
                                    Internet
                                       │
                                       ▼
                        ┌──────────────────────────┐
                        │  Azure Load Balancer     │
                        │  (Public IP)             │
                        │  - HTTP :80  → HTTPS     │
                        │  - HTTPS:443 → Backend   │
                        │  - Health Probes         │
                        └─────────┬────────────────┘
                                  │
                  ┌───────────────┴────────────────┐
                  │   Frontend Subnet              │
                  │   10.0.1.0/24                  │
                  └───────────────┬────────────────┘
                                  │
                  ┌───────────────┴────────────────┐
                  │                                │
         ┌────────▼────────┐            ┌─────────▼────────┐
         │  Web VMSS       │            │  Web VMSS        │
         │  Instance 0     │            │  Instance 1      │
         │  - Nginx        │            │  - Nginx         │
         │  - Gunicorn     │◄──────────►│  - Gunicorn      │
         │  - Nautobot Web │            │  - Nautobot Web  │
         └────────┬────────┘            └─────────┬────────┘
                  │                               │
                  │   Application Subnet          │
                  │   10.0.2.0/24                 │
                  │                               │
         ┌────────▼────────┐            ┌─────────▼────────┐
         │  Worker VMSS    │            │  Scheduler VM    │
         │  Instance 0     │            │  - Celery Beat   │
         │  - Celery       │◄──────────►│  - Scheduled     │
         │  - Background   │            │    Tasks         │
         │    Jobs         │            │                  │
         └────────┬────────┘            └─────────┬────────┘
                  │                               │
                  └───────────────┬───────────────┘
                                  │
                  ┌───────────────┴────────────────┐
                  │   Data Subnet                  │
                  │   10.0.3.0/24                  │
                  └───────────────┬────────────────┘
                                  │
                  ┌───────────────┴────────────────┐
                  │                                │
         ┌────────▼────────┐            ┌─────────▼────────┐
         │  PostgreSQL VM  │            │  Redis VM        │
         │  10.0.3.10      │            │  10.0.3.11       │
         │  - Port 5432    │            │  - Port 6379     │
         │  - Data Disk    │            │  - In-Memory     │
         │    128 GB       │            │    Cache         │
         └─────────────────┘            └──────────────────┘

                  ┌───────────────────────────────┐
                  │  NAT Gateway                  │
                  │  (Outbound Internet)          │
                  └───────────────────────────────┘
```

## Components

### 1. Network Layer

#### Virtual Network (VNet)
- **CIDR**: 10.0.0.0/16
- **Subnets**:
  - Frontend: 10.0.1.0/24 (Load Balancer)
  - Application: 10.0.2.0/24 (Web, Worker, Scheduler VMs)
  - Data: 10.0.3.0/24 (PostgreSQL, Redis)
  - Bastion: 10.0.4.0/24 (Optional - secure access)

#### Network Security Groups (NSGs)

**Frontend NSG**:
- Allow: Internet → LB (80, 443)
- Deny: All other inbound

**Application NSG**:
- Allow: Frontend → App (80, 443)
- Allow: App → Data (5432, 6379)
- Allow: Management subnet → App (22) [optional]
- Deny: All other inbound

**Data NSG**:
- Allow: App → Data (5432, 6379)
- Deny: All other inbound

### 2. Compute Layer

#### Web Tier - VM Scale Set
- **Purpose**: Serve Nautobot web interface and API
- **Count**: 2-10 instances (auto-scaling)
- **VM Size**: Standard_B2ms (Dev), Standard_D4s_v3 (Prod)
- **Software**:
  - Ubuntu 22.04 LTS
  - Python 3.11
  - Nginx (reverse proxy, SSL termination)
  - Gunicorn (WSGI server)
  - Nautobot application

**Auto-scaling Rules**:
- Scale up: CPU > 70% for 5 minutes → Add 1 instance
- Scale down: CPU < 30% for 5 minutes → Remove 1 instance
- Min: 2, Max: 10

#### Worker Tier - VM Scale Set
- **Purpose**: Process background jobs (device sync, webhooks, reports)
- **Count**: 2-5 instances (auto-scaling)
- **VM Size**: Standard_B2ms (Dev), Standard_D4s_v3 (Prod)
- **Software**:
  - Ubuntu 22.04 LTS
  - Python 3.11
  - Celery workers
  - Nautobot dependencies

**Auto-scaling Rules**:
- Scale up: CPU > 75% for 5 minutes → Add 1 instance
- Scale down: CPU < 25% for 5 minutes → Remove 1 instance
- Min: 2, Max: 5

#### Scheduler - Single VM
- **Purpose**: Schedule periodic tasks (Celery Beat)
- **Count**: 1 instance (singleton)
- **VM Size**: Standard_B2s
- **Software**:
  - Ubuntu 22.04 LTS
  - Python 3.11
  - Celery Beat scheduler

**Note**: Only ONE scheduler should run to avoid duplicate tasks

#### PostgreSQL - Single VM
- **Purpose**: Primary database
- **VM Size**: Standard_D2s_v3 (Dev), Standard_D4s_v3 (Prod)
- **Configuration**:
  - Static IP: 10.0.3.10
  - OS Disk: 30 GB (Premium SSD)
  - Data Disk: 128 GB (Premium SSD, LUN 0)
  - PostgreSQL 14+
  - Automated backups (7-day retention)

#### Redis - Single VM
- **Purpose**: Caching and message broker
- **VM Size**: Standard_B2s
- **Configuration**:
  - Static IP: 10.0.3.11
  - In-memory cache
  - Persistence enabled (RDB + AOF)

### 3. Load Balancing Layer

#### Azure Load Balancer
- **SKU**: Standard
- **Type**: Public
- **Frontend IP**: Dynamic public IP
- **Backend Pools**: Web VMSS instances

**Load Balancing Rules**:
```
HTTP  (80)  → Backend (80)  [Health Probe: TCP/80]
HTTPS (443) → Backend (443) [Health Probe: TCP/443]
```

**Health Probes**:
- Protocol: TCP
- Port: 443
- Interval: 5 seconds
- Unhealthy threshold: 2 consecutive failures

**Session Affinity**: SourceIPProtocol (sticky sessions)

### 4. Storage Layer

#### Boot Diagnostics Storage
- **Type**: Standard LRS
- **Purpose**: VM diagnostics and logs

#### PostgreSQL Data Disk
- **Type**: Premium SSD
- **Size**: 128 GB (configurable)
- **Caching**: ReadWrite
- **Mount**: /var/lib/postgresql

### 5. Security Layer

#### Identity & Access
- **Managed Identity**: User-assigned identity for all VMs
- **Purpose**: Access Azure resources without credentials
- **RBAC**: Least privilege principle

#### Secrets Management
- Ansible Vault for sensitive data
- Optional: Azure Key Vault integration

#### Network Security
- Private networking for data tier
- NSG rules (least privilege)
- No public IPs on backend VMs
- NAT Gateway for outbound only

## Traffic Flow

### User Request Flow

```
1. User → https://nautobot.example.com
2. DNS → Load Balancer Public IP
3. Load Balancer → Health check → Select healthy Web VM
4. Web VM (Nginx) → Terminates SSL
5. Nginx → Gunicorn (Nautobot)
6. Nautobot → PostgreSQL (10.0.3.10:5432)
7. Nautobot → Redis (10.0.3.11:6379)
8. Response ← Back through same path
```

### Background Job Flow

```
1. Nautobot Web → Enqueue job → Redis
2. Celery Worker (Worker VM) → Poll Redis
3. Worker → Fetch job → Execute
4. Worker → Update PostgreSQL
5. Worker → Mark job complete in Redis
```

### Scheduled Task Flow

```
1. Celery Beat (Scheduler VM) → Check schedule
2. Beat → Enqueue task → Redis
3. Celery Worker picks up task
4. Worker executes task
```

## Deployment Process

### Phase 1: Infrastructure (Terraform)

```bash
terraform apply
```

Creates:
1. Resource Group
2. VNet and Subnets
3. NSGs
4. NAT Gateway
5. Load Balancer
6. Storage Account
7. VMs and VM Scale Sets

**Duration**: 10-15 minutes

### Phase 2: Configuration (Ansible)

```bash
ansible-playbook deploy_vm_all.yml
```

Configures:
1. PostgreSQL VM:
   - Install PostgreSQL
   - Configure data disk
   - Create database and user
   - Enable remote connections

2. Redis VM:
   - Install Redis
   - Configure persistence
   - Bind to private IP

3. Scheduler VM:
   - Install Python dependencies
   - Deploy Nautobot
   - Configure Celery Beat
   - Start scheduler service

4. Web VMSS:
   - Install Nginx, Python
   - Deploy Nautobot
   - Configure Gunicorn
   - Setup SSL certificates
   - Start services

5. Worker VMSS:
   - Install Python dependencies
   - Deploy Nautobot
   - Configure Celery worker
   - Start worker service

**Duration**: 5-10 minutes per tier (parallelized)

## High Availability

### Web Tier
- ✅ Multiple instances behind Load Balancer
- ✅ Auto-scaling based on load
- ✅ Health probes remove failed instances
- ✅ Zone-redundant deployment (optional)

### Worker Tier
- ✅ Multiple workers for parallel processing
- ✅ Auto-scaling based on CPU
- ✅ Failed workers don't affect others

### Scheduler
- ⚠️ Single instance (by design)
- 💡 For HA: Use leader election (not implemented)

### Database
- ⚠️ Single instance PostgreSQL
- 💡 For HA: Azure Database for PostgreSQL (managed)
- ✅ Automated backups
- ✅ Point-in-time restore

### Cache
- ⚠️ Single instance Redis
- 💡 For HA: Azure Cache for Redis (managed)
- ✅ Persistence enabled

## Disaster Recovery

### Backup Strategy

**PostgreSQL**:
- Automated backups: Daily
- Retention: 7 days
- Manual snapshots before upgrades

**Configuration**:
- Ansible playbooks in Git
- Terraform state in Azure Storage
- Secrets in Ansible Vault

### Recovery Procedures

**Database Restore**:
```bash
# Stop applications
# Restore from backup
sudo -u postgres psql < backup.sql
# Start applications
```

**Complete Infrastructure Rebuild**:
```bash
terraform apply
ansible-playbook deploy_vm_all.yml
# Restore database
```

**RTO**: < 1 hour
**RPO**: < 24 hours

## Monitoring

### Metrics to Monitor

**Application**:
- HTTP response times
- Error rates (4xx, 5xx)
- Request throughput
- Celery queue depth

**Infrastructure**:
- VM CPU utilization
- Memory usage
- Disk I/O
- Network bandwidth

**Database**:
- Connection count
- Query performance
- Replication lag (if configured)
- Disk space

### Tools

- Azure Monitor (VM metrics)
- Application Insights (optional)
- Nautobot built-in logging
- Custom Prometheus/Grafana (optional)

## Cost Optimization

### Dev Environment
- VM Sizes: B-series (burstable)
- Auto-shutdown: 7 PM daily
- Scale down to minimum instances
- **Estimated cost**: $200-300/month

### Prod Environment
- VM Sizes: D-series (balanced)
- Reserved Instances (1-year): 30% savings
- Auto-scaling: Right-size based on usage
- **Estimated cost**: $800-1200/month

### Cost Reduction Tips
1. Use Azure Spot VMs for worker tier (70% savings)
2. Enable auto-shutdown for dev/test
3. Use smaller data disk, expand as needed
4. Monitor and right-size VMs monthly

## Security Best Practices

✅ **Implemented**:
- Private networking for data tier
- NSG rules (least privilege)
- Managed Identities
- SSH key authentication
- Ansible Vault for secrets

🔄 **Recommended**:
- Azure Bastion for secure access
- Azure Key Vault for secrets
- Enable disk encryption
- Setup Azure Sentinel (SIEM)
- Implement Azure Policy

## Comparison: VM vs Kubernetes

| Aspect | VM-Based (This) | Kubernetes |
|--------|-----------------|------------|
| Complexity | Low | High |
| Setup Time | 30 min | 2-4 hours |
| Scaling | VMSS auto-scale | HPA/VPA |
| Cost | Moderate | Higher |
| Maintenance | Ansible updates | K8s + Helm |
| Isolation | OS-level | Container |
| Best For | Traditional ops | Cloud-native |

**When to use VM-based**:
- Team familiar with VMs
- Simpler operations
- Lower overhead
- Traditional workflows

**When to use Kubernetes**:
- Microservices architecture
- Multi-tenant deployments
- Need container benefits
- Cloud-native team

## Troubleshooting Guide

### Load Balancer Issues
```bash
# Check backend health
az network lb show --name lb-nautobot-dev --resource-group rg-nautobot-dev

# Test backend directly
curl -k https://<BACKEND_VM_IP>
```

### Database Connection Issues
```bash
# Check PostgreSQL from app VM
psql -h 10.0.3.10 -U nautobot -d nautobot

# Check pg_hba.conf
sudo cat /etc/postgresql/14/main/pg_hba.conf
```

### Scaling Issues
```bash
# Check VMSS status
az vmss list-instances --name vmss-nautobot-web-dev --resource-group rg-nautobot-dev

# Force update
az vmss update-instances --instance-ids "*" --name vmss-nautobot-web-dev --resource-group rg-nautobot-dev
```

## Future Enhancements

1. **Database HA**: Migrate to Azure Database for PostgreSQL
2. **Cache HA**: Migrate to Azure Cache for Redis
3. **Global LB**: Azure Front Door for multi-region
4. **Monitoring**: Full Prometheus/Grafana stack
5. **Backup**: Azure Backup integration
6. **Security**: Azure Security Center integration

---

**Document Version**: 1.0
**Last Updated**: January 2026
**Maintained By**: DevOps Team
