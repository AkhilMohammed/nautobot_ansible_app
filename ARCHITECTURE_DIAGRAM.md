# Architecture Diagram - Azure Managed Services

## Complete Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEPLOYMENT ARCHITECTURE                            │
│                    (NTC Style - Azure Managed Services)                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────┐
│   Internet  │
│   Users     │
└──────┬──────┘
       │
       │ HTTPS/HTTP
       ▼
┌──────────────────────────────────────────────┐
│      Azure Load Balancer (Public IP)         │
│      - Public facing                         │
│      - Health probes                         │
│      - Session persistence                   │
└──────────────┬───────────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌─────────────┐  ┌─────────────┐
│  Web VM 1   │  │  Web VM 2   │
│  NGINX      │  │  NGINX      │
│  Gunicorn   │  │  Gunicorn   │
│  Nautobot   │  │  Nautobot   │
└──────┬──────┘  └──────┬──────┘
       │                │
       └────────┬───────┘
                │
        ┌───────┼───────┐
        │       │       │
        ▼       ▼       ▼
   ┌────────┐ ┌────────┐ ┌──────────┐
   │Worker  │ │Worker  │ │Scheduler │
   │Celery  │ │Celery  │ │Celery    │
   │Tasks   │ │Tasks   │ │Beat      │
   └───┬────┘ └───┬────┘ └────┬─────┘
       │          │           │
       └──────────┼───────────┘
                  │
         ┌────────┼────────┐
         │        │        │
         ▼        │        ▼
    ┌─────────────────────────────┐    ┌──────────────────────────┐
    │ Azure Database for          │    │ Azure Cache for Redis    │
    │ PostgreSQL Flexible Server  │    │                          │
    │ ──────────────────────────  │    │ ────────────────────     │
    │ ⭐ Managed PaaS Service     │    │ ⭐ Managed PaaS Service  │
    │ ✅ Automatic backups         │    │ ✅ High availability     │
    │ ✅ HA with zone redundancy   │    │ ✅ Data persistence      │
    │ ✅ SSL/TLS enforced          │    │ ✅ SSL/TLS enforced      │
    │ ✅ Point-in-time restore     │    │ ✅ Automatic failover    │
    │ ✅ Automatic patching        │    │ ✅ Geo-replication       │
    │                              │    │                          │
    │ SKUs:                        │    │ SKUs:                    │
    │ - Dev: B_Standard_B1ms      │    │ - Dev: Basic C0         │
    │ - Test: GP_Standard_D2s_v3  │    │ - Test: Standard C1     │
    │ - Prod: MO_Standard_E4s_v3  │    │ - Prod: Premium P1      │
    └──────────────────────────────┘    └──────────────────────────┘
                  │                                  │
                  └────────┬─────────────────────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │ Azure Key Vault  │
                  │ - DB passwords   │
                  │ - Redis keys     │
                  │ - App secrets    │
                  └──────────────────┘
                           │
                           ▼
                  ┌──────────────────────┐
                  │ Azure Storage        │
                  │ - Static files       │
                  │ - Media uploads      │
                  │ - Backups            │
                  └──────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                            NETWORK ARCHITECTURE                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│  Azure Virtual Network (10.0.0.0/16)                               │
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐         │
│  │ Load Balancer Subnet (10.0.0.0/24)                   │         │
│  │  - Public IP                                          │         │
│  │  - Frontend configuration                             │         │
│  └──────────────────────────────────────────────────────┘         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐         │
│  │ Application Subnet (10.0.1.0/24)                     │         │
│  │  - Web VMs (10.0.1.4, 10.0.1.5)                      │         │
│  │  - Worker VMs (10.0.1.6, 10.0.1.7)                   │         │
│  │  - Scheduler VM (10.0.1.8)                           │         │
│  │  - NSG: Allow 22, 80, 443, 8000                      │         │
│  └──────────────────────────────────────────────────────┘         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐         │
│  │ Private Endpoint Subnet (10.0.2.0/24) - Optional     │         │
│  │  - PostgreSQL private endpoint                       │         │
│  │  - Redis private endpoint                            │         │
│  └──────────────────────────────────────────────────────┘         │
└────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT FLOW (Terraform → Ansible)                 │
└─────────────────────────────────────────────────────────────────────────────┘

1. TERRAFORM PROVISIONING
   │
   ├─→ Create Resource Group
   ├─→ Create Virtual Network
   ├─→ Create Azure Database for PostgreSQL ⭐
   │   └─→ Configure SSL, HA, backups
   ├─→ Create Azure Cache for Redis ⭐
   │   └─→ Configure SSL, persistence
   ├─→ Create VMs for Nautobot
   ├─→ Create Load Balancer
   ├─→ Create Key Vault
   └─→ Create Storage Account
   
2. INTEGRATION (Python Script)
   │
   ├─→ Extract Terraform outputs
   ├─→ Generate Ansible inventory
   │   └─→ inventory/vm/<env>_dynamic.yml
   ├─→ Create Terraform variables
   │   └─→ group_vars/<env>/terraform.yml
   └─→ Create secrets template
       └─→ group_vars/<env>/vault_template.yml

3. ANSIBLE DEPLOYMENT
   │
   ├─→ Install system packages
   ├─→ Install Python 3.11
   ├─→ Create nautobot user
   ├─→ Install Nautobot
   ├─→ Configure PostgreSQL connection (SSL)
   ├─→ Configure Redis connection (SSL)
   ├─→ Deploy Web servers (NGINX + Gunicorn)
   ├─→ Deploy Worker servers (Celery)
   ├─→ Deploy Scheduler (Celery Beat)
   └─→ Create systemd services

┌─────────────────────────────────────────────────────────────────────────────┐
│                          ENVIRONMENT COMPARISON                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┬─────────────────┬──────────────────┬──────────────────┐
│ Component    │ Development     │ Test             │ Production       │
├──────────────┼─────────────────┼──────────────────┼──────────────────┤
│ PostgreSQL   │ B_Standard_B1ms │ GP_Standard_D2s  │ MO_Standard_E4s  │
│              │ 32GB, No HA     │ 64GB, No HA      │ 128GB, HA        │
├──────────────┼─────────────────┼──────────────────┼──────────────────┤
│ Redis        │ Basic C0        │ Standard C1      │ Premium P1       │
│              │ 250MB           │ 1GB              │ 6GB + Persist    │
├──────────────┼─────────────────┼──────────────────┼──────────────────┤
│ Web VMs      │ 1x B2s          │ 2x D2s_v3        │ 3x D4s_v3        │
├──────────────┼─────────────────┼──────────────────┼──────────────────┤
│ Worker VMs   │ 1x B2s          │ 2x D2s_v3        │ 3x D4s_v3        │
├──────────────┼─────────────────┼──────────────────┼──────────────────┤
│ Scheduler    │ 1x B1s          │ 1x B2s           │ 2x D2s_v3        │
├──────────────┼─────────────────┼──────────────────┼──────────────────┤
│ Load Balancer│ Basic           │ Standard         │ Standard         │
├──────────────┼─────────────────┼──────────────────┼──────────────────┤
│ Est. Cost    │ ~$96/month      │ ~$450/month      │ ~$1,546/month    │
└──────────────┴─────────────────┴──────────────────┴──────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                      KEY DIFFERENCES FROM VM-BASED                           │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┬────────────────────┬──────────────────────────┐
│ Aspect               │ VM-Based           │ Azure Managed (This)     │
├──────────────────────┼────────────────────┼──────────────────────────┤
│ PostgreSQL           │ VM + Manual setup  │ Managed PaaS ⭐          │
│ PostgreSQL Backups   │ Manual scripts     │ Automatic (7-30 days)    │
│ PostgreSQL HA        │ Manual clustering  │ Built-in zone-redundant  │
│ PostgreSQL Patching  │ Manual             │ Automatic                │
├──────────────────────┼────────────────────┼──────────────────────────┤
│ Redis                │ VM + Manual setup  │ Managed PaaS ⭐          │
│ Redis HA             │ Manual Sentinel    │ Automatic failover       │
│ Redis Persistence    │ Manual RDB/AOF     │ Built-in (Premium)       │
│ Redis Patching       │ Manual             │ Automatic                │
├──────────────────────┼────────────────────┼──────────────────────────┤
│ Maintenance          │ High effort        │ Low effort               │
│ Operations Load      │ Heavy              │ Light                    │
│ Disaster Recovery    │ Complex            │ Simple (built-in)        │
│ Cost                 │ Lower base         │ Higher but saves time    │
└──────────────────────┴────────────────────┴──────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          SECURITY FEATURES                                   │
└─────────────────────────────────────────────────────────────────────────────┘

✅ SSL/TLS Encryption
   ├─→ PostgreSQL requires sslmode=require
   ├─→ Redis requires --tls flag
   └─→ HTTPS on Load Balancer (configurable)

✅ Network Security
   ├─→ Network Security Groups (NSGs)
   ├─→ Private endpoints (optional, for prod)
   └─→ Firewall rules on managed services

✅ Secrets Management
   ├─→ Azure Key Vault integration
   ├─→ Ansible Vault for deployment secrets
   └─→ No hardcoded credentials

✅ Identity & Access
   ├─→ Service principals for Terraform
   ├─→ SSH keys for VM access
   └─→ Azure AD integration (optional)

✅ Monitoring & Logging
   ├─→ Azure Monitor integration
   ├─→ Diagnostic settings enabled
   └─→ Log Analytics workspace

Legend:
⭐ = Azure Managed PaaS Service (key feature)
✅ = Implemented feature
❌ = Not used (by design)
```
