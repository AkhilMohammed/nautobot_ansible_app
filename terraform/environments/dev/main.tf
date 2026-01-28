# Nautobot Infrastructure - DEV Environment
# This is the main Terraform configuration for deploying Nautobot infrastructure in Azure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }

  # Backend configuration for state management
  # Uncomment and configure after initial setup
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstatedev"
  #   container_name       = "tfstate"
  #   key                  = "nautobot-dev.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

# Local variables
locals {
  environment  = "dev"
  project_name = var.project_name
  location     = var.location

  common_tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
  }
}

# Resource Group
resource "azurerm_resource_group" "nautobot" {
  name     = "rg-${local.project_name}-${local.environment}"
  location = local.location
  tags     = local.common_tags
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.nautobot.name
  create_media_storage = false

  tags = local.common_tags
}

# Network Module
module "network" {
  source = "../../modules/network"

  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.nautobot.name

  vnet_address_space    = var.vnet_address_space
  subnet_frontend       = var.subnet_frontend
  subnet_app            = var.subnet_app
  subnet_data           = var.subnet_data
  enable_bastion        = false
  enable_ssh_access     = true
  ssh_source_addresses  = var.ssh_source_addresses

  tags = local.common_tags
}

# Load Balancer Module
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.nautobot.name
  lb_sku              = "Standard"

  tags = local.common_tags
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.nautobot.name

  subnet_app_id       = module.network.subnet_app_id
  subnet_data_id      = module.network.subnet_data_id
  lb_backend_pool_id  = module.loadbalancer.lb_backend_pool_id

  admin_username             = var.admin_username
  admin_ssh_public_key       = var.admin_ssh_public_key
  boot_diagnostics_storage_uri = module.storage.storage_account_primary_blob_endpoint

  # PostgreSQL Configuration
  postgres_vm_size      = "Standard_B2s"
  postgres_private_ip   = var.postgres_private_ip
  postgres_disk_size_gb = 128
  postgres_disk_type    = "Premium_LRS"

  # Redis Configuration
  redis_vm_size     = "Standard_B2s"
  redis_private_ip  = var.redis_private_ip

  # Scheduler Configuration
  scheduler_vm_size = "Standard_B2s"

  # Web VMSS Configuration
  web_vm_size        = "Standard_B2ms"
  web_instance_count = 2
  web_min_instances  = 2
  web_max_instances  = 4

  # Worker VMSS Configuration
  worker_vm_size        = "Standard_B2ms"
  worker_instance_count = 2
  worker_min_instances  = 2
  worker_max_instances  = 3

  tags = local.common_tags

  depends_on = [
    module.network,
    module.loadbalancer
  ]
}
