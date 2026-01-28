output "storage_account_id" {
  description = "Storage Account ID"
  value       = azurerm_storage_account.diagnostics.id
}

output "storage_account_name" {
  description = "Storage Account name"
  value       = azurerm_storage_account.diagnostics.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary Blob Endpoint"
  value       = azurerm_storage_account.diagnostics.primary_blob_endpoint
}

output "backups_container_name" {
  description = "Backups container name"
  value       = azurerm_storage_container.backups.name
}

output "media_container_name" {
  description = "Media container name"
  value       = var.create_media_storage ? azurerm_storage_container.media[0].name : ""
}
