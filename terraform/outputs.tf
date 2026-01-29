# Resource Group
output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

# Network Outputs
output "vnet_id" {
  description = "Virtual network ID"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "Virtual network name"
  value       = module.network.vnet_name
}

output "app_subnet_id" {
  description = "Application subnet ID"
  value       = module.network.app_subnet_id
}

# PostgreSQL Outputs (Azure Managed)
output "postgresql_server_name" {
  description = "PostgreSQL server name"
  value       = module.database.postgresql_server_name
}

output "postgresql_server_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = module.database.postgresql_server_fqdn
}

output "postgresql_database_name" {
  description = "PostgreSQL database name"
  value       = module.database.postgresql_database_name
}

output "postgresql_admin_username" {
  description = "PostgreSQL admin username"
  value       = module.database.postgresql_admin_username
  sensitive   = true
}

# Redis Outputs (Azure Managed)
output "redis_hostname" {
  description = "Redis hostname"
  value       = module.redis.redis_hostname
}

output "redis_ssl_port" {
  description = "Redis SSL port"
  value       = module.redis.redis_ssl_port
}

output "redis_primary_access_key" {
  description = "Redis primary access key"
  value       = module.redis.redis_primary_access_key
  sensitive   = true
}

# Compute Outputs
output "web_vmss_id" {
  description = "Web VMSS ID"
  value       = module.compute.web_vmss_id
}

output "worker_vmss_id" {
  description = "Worker VMSS ID"
  value       = module.compute.worker_vmss_id
}

# output "scheduler_vm_id" {
#   description = "Scheduler VM ID"
#   value       = module.compute.scheduler_vm_id
# }
#
# output "scheduler_private_ip" {
#   description = "Scheduler private IP"
#   value       = module.compute.scheduler_private_ip
# }

# output "postgres_vm_id" {
#   description = "PostgreSQL VM ID"
#   value       = module.compute.postgres_vm_id
# }
#
# output "postgres_private_ip" {
#   description = "PostgreSQL private IP"
#   value       = module.compute.postgres_private_ip
# }
#
# output "redis_vm_id" {
#   description = "Redis VM ID"
#   value       = module.compute.redis_vm_id
# }
#
# output "redis_private_ip" {
#   description = "Redis private IP"
#   value       = module.compute.redis_private_ip
# }

# Load Balancer
output "load_balancer_public_ip" {
  description = "Load balancer public IP"
  value       = module.load_balancer.lb_public_ip
}

output "load_balancer_fqdn" {
  description = "Load balancer FQDN"
  value       = module.load_balancer.lb_public_ip_fqdn
}

# Key Vault
output "key_vault_name" {
  description = "Key Vault name"
  value       = module.key_vault.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.key_vault_uri
}

# Storage Account
output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.nautobot.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Storage account primary blob endpoint"
  value       = azurerm_storage_account.nautobot.primary_blob_endpoint
}

# Ansible Inventory Data
output "ansible_inventory" {
  description = "Data for Ansible inventory generation"
  sensitive   = true
  value = {
    scheduler_server = {
      host = module.compute.scheduler_private_ip
      vars = {
        ansible_user = var.admin_username
        role = "scheduler"
      }
    }
    database = {
      host = module.database.postgresql_server_fqdn
      port = 5432
      name = module.database.postgresql_database_name
      username = module.database.postgresql_admin_username
    }
    redis = {
      host = module.redis.redis_hostname
      port = module.redis.redis_ssl_port
      ssl = true
    }
  }
}
