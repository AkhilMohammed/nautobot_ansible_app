output "lb_id" {
  description = "Load Balancer ID"
  value       = azurerm_lb.nautobot.id
}

output "lb_public_ip" {
  description = "Load Balancer Public IP Address"
  value       = azurerm_public_ip.lb.ip_address
}

output "lb_public_ip_fqdn" {
  description = "Load Balancer Public IP FQDN"
  value       = azurerm_public_ip.lb.fqdn
}

output "lb_backend_pool_id" {
  description = "Backend Address Pool ID"
  value       = azurerm_lb_backend_address_pool.nautobot.id
}

output "lb_frontend_ip_configuration" {
  description = "Frontend IP Configuration"
  value       = azurerm_lb.nautobot.frontend_ip_configuration
}
