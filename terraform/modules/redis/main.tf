# Azure Cache for Redis
resource "azurerm_redis_cache" "main" {
  name                = "${var.environment}-nautobot-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  capacity            = var.redis_capacity
  family              = var.redis_family
  sku_name            = var.redis_sku
  
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"
  
  redis_version       = var.redis_version
  
  redis_configuration {
    maxmemory_reserved              = var.maxmemory_reserved
    maxmemory_delta                 = var.maxmemory_delta
    maxmemory_policy                = var.maxmemory_policy
    maxfragmentationmemory_reserved = var.maxfragmentationmemory_reserved
    notify_keyspace_events          = var.notify_keyspace_events
  }

  # Shard count for Premium tier
  shard_count = var.redis_sku == "Premium" ? var.shard_count : null
  
  # Zones for Premium tier
  zones = var.redis_sku == "Premium" ? var.zones : null

  # Patch schedule
  dynamic "patch_schedule" {
    for_each = var.patch_schedule_enabled ? [1] : []
    content {
      day_of_week    = var.patch_schedule_day
      start_hour_utc = var.patch_schedule_hour
    }
  }

  tags = merge(
    var.tags,
    {
      Role = "Cache"
      Type = "Redis-Managed"
    }
  )
}

# Redis Firewall Rules - Allow application subnet
resource "azurerm_redis_firewall_rule" "app_subnet" {
  count               = length(var.allowed_subnet_cidrs)
  name                = "allow-app-subnet-${count.index}"
  redis_cache_name    = azurerm_redis_cache.main.name
  resource_group_name = var.resource_group_name
  start_ip            = cidrhost(var.allowed_subnet_cidrs[count.index], 0)
  end_ip              = cidrhost(var.allowed_subnet_cidrs[count.index], -1)
}

# Private Endpoint for Redis (optional)
resource "azurerm_private_endpoint" "redis" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.environment}-redis-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.environment}-redis-privateserviceconnection"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis[0].id]
  }

  tags = var.tags
}

# Private DNS Zone for Redis
resource "azurerm_private_dns_zone" "redis" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  count                 = var.enable_private_endpoint ? 1 : 0
  name                  = "${var.environment}-redis-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis[0].name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}
