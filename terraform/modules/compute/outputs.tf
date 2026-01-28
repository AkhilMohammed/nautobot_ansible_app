output "postgres_vm_id" {
  description = "PostgreSQL VM ID"
  value       = azurerm_linux_virtual_machine.postgres.id
}

output "postgres_vm_name" {
  description = "PostgreSQL VM name"
  value       = azurerm_linux_virtual_machine.postgres.name
}

output "postgres_private_ip" {
  description = "PostgreSQL private IP address"
  value       = azurerm_network_interface.postgres.private_ip_address
}

output "redis_vm_id" {
  description = "Redis VM ID"
  value       = azurerm_linux_virtual_machine.redis.id
}

output "redis_vm_name" {
  description = "Redis VM name"
  value       = azurerm_linux_virtual_machine.redis.name
}

output "redis_private_ip" {
  description = "Redis private IP address"
  value       = azurerm_network_interface.redis.private_ip_address
}

output "scheduler_vm_id" {
  description = "Scheduler VM ID"
  value       = azurerm_linux_virtual_machine.scheduler.id
}

output "scheduler_vm_name" {
  description = "Scheduler VM name"
  value       = azurerm_linux_virtual_machine.scheduler.name
}

output "scheduler_private_ip" {
  description = "Scheduler private IP address"
  value       = azurerm_network_interface.scheduler.private_ip_address
}

output "web_vmss_id" {
  description = "Web VMSS ID"
  value       = azurerm_linux_virtual_machine_scale_set.web.id
}

output "web_vmss_name" {
  description = "Web VMSS name"
  value       = azurerm_linux_virtual_machine_scale_set.web.name
}

output "worker_vmss_id" {
  description = "Worker VMSS ID"
  value       = azurerm_linux_virtual_machine_scale_set.worker.id
}

output "worker_vmss_name" {
  description = "Worker VMSS name"
  value       = azurerm_linux_virtual_machine_scale_set.worker.name
}

output "managed_identity_id" {
  description = "Managed Identity ID"
  value       = azurerm_user_assigned_identity.nautobot.id
}

output "managed_identity_principal_id" {
  description = "Managed Identity Principal ID"
  value       = azurerm_user_assigned_identity.nautobot.principal_id
}
