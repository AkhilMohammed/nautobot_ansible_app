# Test Environment Configuration
environment = "test"
location    = "eastus"

# Network Configuration
vnet_address_space = ["10.20.0.0/16"]
app_subnet_cidr    = "10.20.1.0/24"

# PostgreSQL Configuration (Azure Managed - General Purpose)
postgresql_sku                = "GP_Standard_D2s_v3"  # General Purpose
postgresql_storage_mb         = 65536                  # 64 GB
backup_retention_days         = 14
geo_redundant_backup_enabled  = false
high_availability_enabled     = false

# Redis Configuration (Azure Managed - Standard Tier)
redis_sku      = "Standard"
redis_family   = "C"
redis_capacity = 1           # 1 GB

# VM Configuration
web_vm_count       = 2
web_vm_size        = "Standard_D2s_v3"
worker_vm_count    = 2
worker_vm_size     = "Standard_D2s_v3"
scheduler_vm_count = 1
scheduler_vm_size  = "Standard_B2s"

# Load Balancer
lb_sku                    = "Standard"
lb_frontend_ip_allocation = "Static"

# Storage
storage_replication_type = "GRS"

# Private Endpoints
enable_private_endpoint = false
