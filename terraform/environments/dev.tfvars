# Development Environment Configuration
environment = "dev"
location    = "centralus"  # trying centralus for PostgreSQL support on free tier

# Network Configuration
vnet_address_space = ["10.10.0.0/16"]
subnet_frontend    = "10.10.0.0/24"  # Fixed subnet range
subnet_app         = "10.10.1.0/24"  # Fixed subnet range
subnet_data        = "10.10.2.0/24"  # Fixed subnet range
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

# Load Balancer Configuration
lb_sku = "Standard"  # Changed from Basic to support availability zones

# VM Configuration (All B1s to fit within 4 vCPU quota: 1+1+1=3 vCPUs)
web_vm_count       = 1
web_vm_size        = "Standard_B1s"  # 1 vCPU, 1GB RAM
worker_vm_count    = 1
worker_vm_size     = "Standard_B1s"  # 1 vCPU, 1GB RAM
scheduler_vm_count = 1
scheduler_vm_size  = "Standard_B1s"  # 1 vCPU, 1GB RAM

# Storage
storage_replication_type = "LRS"

# Private Endpoints (disabled for dev to save cost)
enable_private_endpoint = false
