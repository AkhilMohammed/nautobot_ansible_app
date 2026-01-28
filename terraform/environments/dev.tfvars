# Development Environment Configuration
environment = "dev"
location    = "eastus"

# Network Configuration
vnet_address_space = ["10.10.0.0/16"]
app_subnet_cidr    = "10.10.1.0/24"

# PostgreSQL Configuration (Azure Managed - Development Tier)
postgresql_sku                = "B_Standard_B1ms"  # Burstable tier for dev
postgresql_storage_mb         = 32768               # 32 GB
backup_retention_days         = 7
geo_redundant_backup_enabled  = false
high_availability_enabled     = false

# Redis Configuration (Azure Managed - Development Tier)
redis_sku      = "Basic"    # Basic tier for dev
redis_family   = "C"
redis_capacity = 0          # 250 MB

# VM Configuration
web_vm_count       = 1
web_vm_size        = "Standard_B2s"
worker_vm_count    = 1
worker_vm_size     = "Standard_B2s"
scheduler_vm_count = 1
scheduler_vm_size  = "Standard_B1s"

# Load Balancer
lb_sku                    = "Basic"
lb_frontend_ip_allocation = "Dynamic"

# Storage
storage_replication_type = "LRS"

# Private Endpoints (disabled for dev to save cost)
enable_private_endpoint = false
