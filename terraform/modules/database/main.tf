# Azure Database for PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.environment}-nautobot-psql"
  location               = var.location
  resource_group_name    = var.resource_group_name
  
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password
  
  sku_name   = var.postgresql_sku
  version    = "15"
  storage_mb = var.postgresql_storage_mb
  
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  
  dynamic "high_availability" {
    for_each = var.high_availability_enabled ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.standby_availability_zone
    }
  }

  tags = merge(
    var.tags,
    {
      Role = "Database"
      Type = "PostgreSQL-Managed"
    }
  )
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "nautobot" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# PostgreSQL Firewall Rules - Allow Azure Services
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# PostgreSQL Firewall Rules - Allow Application Subnet
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_app_subnet" {
  count            = length(var.allowed_subnet_ids)
  name             = "allow-app-subnet-${count.index}"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = var.app_subnet_cidrs[count.index]
  end_ip_address   = var.app_subnet_cidrs[count.index]
}

# PostgreSQL Configuration - Max Connections
resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = var.max_connections
}

# PostgreSQL Configuration - Shared Buffers
resource "azurerm_postgresql_flexible_server_configuration" "shared_buffers" {
  name      = "shared_buffers"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = var.shared_buffers
}

# PostgreSQL Configuration - Work Memory
resource "azurerm_postgresql_flexible_server_configuration" "work_mem" {
  name      = "work_mem"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "16384"
}

# PostgreSQL Configuration - Maintenance Work Memory
resource "azurerm_postgresql_flexible_server_configuration" "maintenance_work_mem" {
  name      = "maintenance_work_mem"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "65536"
}

# Private DNS Zone for PostgreSQL (optional - for private endpoint)
resource "azurerm_private_dns_zone" "postgres" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "${var.environment}-postgres-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}
