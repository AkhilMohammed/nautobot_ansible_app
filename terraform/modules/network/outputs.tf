output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.nautobot.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.nautobot.name
}

output "subnet_frontend_id" {
  description = "Frontend subnet ID"
  value       = azurerm_subnet.frontend.id
}

output "subnet_app_id" {
  description = "Application subnet ID"
  value       = azurerm_subnet.app.id
}

output "subnet_data_id" {
  description = "Data subnet ID"
  value       = azurerm_subnet.data.id
}

output "nsg_frontend_id" {
  description = "Frontend NSG ID"
  value       = azurerm_network_security_group.frontend.id
}

output "nsg_app_id" {
  description = "Application NSG ID"
  value       = azurerm_network_security_group.app.id
}

output "nsg_data_id" {
  description = "Data NSG ID"
  value       = azurerm_network_security_group.data.id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway Public IP"
  value       = azurerm_public_ip.nat.ip_address
}
