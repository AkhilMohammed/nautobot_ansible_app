output "public_ip" {
  description = "Jumpbox public IP"
  value       = azurerm_public_ip.jumpbox.ip_address
}

output "private_ip" {
  description = "Jumpbox private IP"
  value       = azurerm_network_interface.jumpbox.private_ip_address
}
