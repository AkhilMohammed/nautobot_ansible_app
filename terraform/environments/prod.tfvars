# Production Environment Configuration
environment = "prod"
location    = "eastus"

# Network Configuration
vnet_address_space = ["10.30.0.0/16"]
app_subnet_cidr    = "10.30.1.0/24"

# PostgreSQL Configuration (Azure Managed - High Availability)
postgresql_sku                = "MO_Standard_E4s_v3"  # Memory Optimized
postgresql_storage_mb         = 131072                 # 128 GB
backup_retention_days         = 30
geo_redundant_backup_enabled  = true
high_availability_enabled     = true

# Redis Configuration (Azure Managed - Premium Tier)
redis_sku      = "Premium"
redis_family   = "P"
redis_capacity = 1           # 6 GB
# shard_count will be set for Premium tier
# zones will be set for Premium tier

# VM Configuration
web_vm_count       = 3
web_vm_size        = "Standard_D4s_v3"
worker_vm_count    = 3
worker_vm_size     = "Standard_D4s_v3"
scheduler_vm_count = 2
scheduler_vm_size  = "Standard_D2s_v3"

# Load Balancer
lb_sku                    = "Standard"
lb_frontend_ip_allocation = "Static"

# Storage
storage_replication_type = "GZRS"  # Geo-Zone-Redundant

# Private Endpoints (enabled for production security)
enable_private_endpoint = true
