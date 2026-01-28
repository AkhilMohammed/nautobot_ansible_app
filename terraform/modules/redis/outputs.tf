output "redis_name" {
  description = "Redis cache name"
  value       = azurerm_redis_cache.main.name
}

output "redis_hostname" {
  description = "Redis hostname"
  value       = azurerm_redis_cache.main.hostname
}

output "redis_ssl_port" {
  description = "Redis SSL port"
  value       = azurerm_redis_cache.main.ssl_port
}

output "redis_port" {
  description = "Redis port (non-SSL)"
  value       = azurerm_redis_cache.main.port
}

output "redis_primary_access_key" {
  description = "Redis primary access key"
  value       = azurerm_redis_cache.main.primary_access_key
  sensitive   = true
}

output "redis_secondary_access_key" {
  description = "Redis secondary access key"
  value       = azurerm_redis_cache.main.secondary_access_key
  sensitive   = true
}

output "redis_primary_connection_string" {
  description = "Redis primary connection string"
  value       = azurerm_redis_cache.main.primary_connection_string
  sensitive   = true
}

output "redis_secondary_connection_string" {
  description = "Redis secondary connection string"
  value       = azurerm_redis_cache.main.secondary_connection_string
  sensitive   = true
}

output "redis_id" {
  description = "Redis cache ID"
  value       = azurerm_redis_cache.main.id
}

output "redis_private_endpoint_ip" {
  description = "Redis private endpoint IP address"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.redis[0].private_service_connection[0].private_ip_address : null
}
