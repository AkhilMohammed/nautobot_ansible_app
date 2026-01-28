# Output values for DEV environment

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.nautobot.name
}

output "location" {
  description = "Azure region"
  value       = local.location
}

# Network Outputs
output "vnet_name" {
  description = "Virtual Network name"
  value       = module.network.vnet_name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.network.vnet_id
}

# Load Balancer Outputs
output "lb_public_ip" {
  description = "Load Balancer Public IP - Access Nautobot here"
  value       = module.loadbalancer.lb_public_ip
}

output "nautobot_url" {
  description = "Nautobot Web URL"
  value       = "https://${module.loadbalancer.lb_public_ip}"
}

# Compute Outputs
output "postgres_vm_name" {
  description = "PostgreSQL VM name"
  value       = module.compute.postgres_vm_name
}

output "postgres_private_ip" {
  description = "PostgreSQL private IP"
  value       = module.compute.postgres_private_ip
}

output "redis_vm_name" {
  description = "Redis VM name"
  value       = module.compute.redis_vm_name
}

output "redis_private_ip" {
  description = "Redis private IP"
  value       = module.compute.redis_private_ip
}

output "scheduler_vm_name" {
  description = "Scheduler VM name"
  value       = module.compute.scheduler_vm_name
}

output "scheduler_private_ip" {
  description = "Scheduler private IP"
  value       = module.compute.scheduler_private_ip
}

output "web_vmss_name" {
  description = "Web VM Scale Set name"
  value       = module.compute.web_vmss_name
}

output "worker_vmss_name" {
  description = "Worker VM Scale Set name"
  value       = module.compute.worker_vmss_name
}

# Storage Outputs
output "storage_account_name" {
  description = "Storage Account name"
  value       = module.storage.storage_account_name
}

# Ansible Integration Outputs
output "ansible_inventory" {
  description = "Ansible inventory data (JSON)"
  value = jsonencode({
    all = {
      children = {
        dev_vm = {
          hosts = {
            "dev-nautobot-postgres" = {
              ansible_host     = module.compute.postgres_private_ip
              ansible_user     = var.admin_username
              deploy_env       = "dev"
              deployment_type  = "vm"
              component        = "postgres"
            }
            "dev-nautobot-redis" = {
              ansible_host     = module.compute.redis_private_ip
              ansible_user     = var.admin_username
              deploy_env       = "dev"
              deployment_type  = "vm"
              component        = "redis"
            }
            "dev-nautobot-scheduler" = {
              ansible_host     = module.compute.scheduler_private_ip
              ansible_user     = var.admin_username
              deploy_env       = "dev"
              deployment_type  = "vm"
              component        = "scheduler"
            }
          }
          vars = {
            resource_group = azurerm_resource_group.nautobot.name
            web_vmss_name  = module.compute.web_vmss_name
            worker_vmss_name = module.compute.worker_vmss_name
            postgres_host  = module.compute.postgres_private_ip
            redis_host     = module.compute.redis_private_ip
          }
        }
      }
    }
  })
  sensitive = true
}

# Quick deployment guide
output "deployment_commands" {
  description = "Commands to deploy Nautobot with Ansible"
  value = <<-EOT
  
  ====== Nautobot Infrastructure Deployed Successfully! ======
  
  Next Steps:
  
  1. Save Ansible inventory:
     terraform output -json ansible_inventory > ../../../inventory/vm/terraform_dev.json
  
  2. Get VMSS instance IPs:
     az vmss list-instance-connection-info \
       --resource-group ${azurerm_resource_group.nautobot.name} \
       --name ${module.compute.web_vmss_name}
  
  3. Update your Ansible inventory with VMSS IPs
  
  4. Deploy with Ansible:
     cd ../../../
     ansible-playbook -i inventory/vm/dev.yml playbooks/deploy_vm_all.yml
  
  5. Access Nautobot:
     URL: https://${module.loadbalancer.lb_public_ip}
     (Accept self-signed certificate warning)
  
  6. Create superuser (SSH to one web VM):
     sudo -u nautobot /opt/nautobot/venv/bin/nautobot-server createsuperuser
  
  ============================================================
  
  EOT
}
