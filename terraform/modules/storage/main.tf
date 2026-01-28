# Storage Module - Storage Account and Managed Disks

# Storage Account for Boot Diagnostics
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stdiag${var.project_name}${var.environment}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = merge(var.tags, {
    Component = "Diagnostics"
  })
}

# Storage Container for Backups
resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.diagnostics.name
  container_access_type = "private"
}

# Storage Container for Nautobot Media (if needed)
resource "azurerm_storage_container" "media" {
  count                 = var.create_media_storage ? 1 : 0
  name                  = "nautobot-media"
  storage_account_name  = azurerm_storage_account.diagnostics.name
  container_access_type = "private"
}
