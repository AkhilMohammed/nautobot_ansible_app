terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    # Backend configuration will be provided via backend config file
    # terraform init -backend-config=backend-<env>.hcl
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Data source for current Azure client
data "azurerm_client_config" "current" {}

# Local variables
locals {
  common_tags = {
    Environment = var.environment
    Project     = "Nautobot"
    ManagedBy   = "Terraform"
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.environment}-nautobot-rg"
  location = var.location
  tags     = local.common_tags
}

# Virtual Network Module
module "network" {
  source = "./modules/network"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_address_space  = var.vnet_address_space
  
  tags = local.common_tags
}

# Azure Database for PostgreSQL (Managed Service)
module "database" {
  source = "./modules/database"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_id             = module.network.vnet_id
  
  db_admin_username             = var.db_admin_username
  db_admin_password             = var.db_admin_password
  postgresql_sku                = var.postgresql_sku
  postgresql_storage_mb         = var.postgresql_storage_mb
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  high_availability_enabled     = var.high_availability_enabled
  
  allowed_subnet_ids  = [module.network.app_subnet_id]
  app_subnet_cidrs    = [var.app_subnet_cidr]
  enable_private_endpoint = var.enable_private_endpoint
  
  tags = local.common_tags
}

# Azure Cache for Redis (Managed Service)
module "redis" {
  source = "./modules/redis"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_id             = module.network.vnet_id
  
  redis_sku      = var.redis_sku
  redis_family   = var.redis_family
  redis_capacity = var.redis_capacity
  
  allowed_subnet_cidrs       = [var.app_subnet_cidr]
  enable_private_endpoint    = var.enable_private_endpoint
  private_endpoint_subnet_id = module.network.app_subnet_id
  
  tags = local.common_tags
}

# Nautobot Web Application VMs
module "nautobot_web" {
  source = "./modules/compute"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.app_subnet_id
  
  vm_name_prefix      = "nautobot-web"
  vm_count            = var.web_vm_count
  vm_size             = var.web_vm_size
  admin_username      = var.admin_username
  ssh_public_key_path = var.ssh_public_key_path
  
  backend_pool_id     = module.load_balancer.backend_pool_id
  
  tags = merge(local.common_tags, {
    Role = "Web"
    Component = "Nautobot-App"
  })
}

# Nautobot Worker VMs
module "nautobot_worker" {
  source = "./modules/compute"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.app_subnet_id
  
  vm_name_prefix      = "nautobot-worker"
  vm_count            = var.worker_vm_count
  vm_size             = var.worker_vm_size
  admin_username      = var.admin_username
  ssh_public_key_path = var.ssh_public_key_path
  
  tags = merge(local.common_tags, {
    Role = "Worker"
    Component = "Nautobot-Worker"
  })
}

# Nautobot Scheduler VMs
module "nautobot_scheduler" {
  source = "./modules/compute"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.app_subnet_id
  
  vm_name_prefix      = "nautobot-scheduler"
  vm_count            = var.scheduler_vm_count
  vm_size             = var.scheduler_vm_size
  admin_username      = var.admin_username
  ssh_public_key_path = var.ssh_public_key_path
  
  tags = merge(local.common_tags, {
    Role = "Scheduler"
    Component = "Nautobot-Scheduler"
  })
}

# Load Balancer for Nautobot Web
module "load_balancer" {
  source = "./modules/load_balancer"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.lb_subnet_id
  
  frontend_ip_allocation = var.lb_frontend_ip_allocation
  sku                    = var.lb_sku
  
  tags = local.common_tags
}

# Key Vault for secrets
module "key_vault" {
  source = "./modules/key_vault"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  
  secrets = {
    "db-admin-password"     = var.db_admin_password
    "db-connection-string"  = module.database.postgresql_connection_string
    "redis-primary-key"     = module.redis.redis_primary_access_key
    "redis-connection-string" = module.redis.redis_primary_connection_string
    "nautobot-secret-key"   = random_password.nautobot_secret.result
  }
  
  tags = local.common_tags
}

# Random password for Nautobot secret key
resource "random_password" "nautobot_secret" {
  length  = 50
  special = true
}

# Storage Account for static files and backups
resource "azurerm_storage_account" "nautobot" {
  name                     = "${var.environment}nautobotsa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
  }

  tags = local.common_tags
}

# Storage containers
resource "azurerm_storage_container" "static" {
  name                  = "static"
  storage_account_name  = azurerm_storage_account.nautobot.name
  container_access_type = "blob"
}

resource "azurerm_storage_container" "media" {
  name                  = "media"
  storage_account_name  = azurerm_storage_account.nautobot.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.nautobot.name
  container_access_type = "private"
}
