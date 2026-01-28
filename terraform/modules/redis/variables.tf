variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID"
  type        = string
}

variable "redis_sku" {
  description = "Redis SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku)
    error_message = "Redis SKU must be Basic, Standard, or Premium."
  }
}

variable "redis_family" {
  description = "Redis family (C for Basic/Standard, P for Premium)"
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis capacity (0-6 for Basic/Standard, 1-5 for Premium)"
  type        = number
  default     = 1
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "6"
}

variable "maxmemory_reserved" {
  description = "Maxmemory reserved in MB"
  type        = number
  default     = 50
}

variable "maxmemory_delta" {
  description = "Maxmemory delta in MB"
  type        = number
  default     = 50
}

variable "maxmemory_policy" {
  description = "Maxmemory eviction policy"
  type        = string
  default     = "allkeys-lru"
}

variable "maxfragmentationmemory_reserved" {
  description = "Max fragmentation memory reserved in MB"
  type        = number
  default     = 50
}

variable "notify_keyspace_events" {
  description = "Keyspace notifications"
  type        = string
  default     = ""
}

variable "shard_count" {
  description = "Number of shards (Premium tier only)"
  type        = number
  default     = 1
}

variable "zones" {
  description = "Availability zones (Premium tier only)"
  type        = list(string)
  default     = null
}

variable "patch_schedule_enabled" {
  description = "Enable patch schedule"
  type        = bool
  default     = true
}

variable "patch_schedule_day" {
  description = "Day of week for patching"
  type        = string
  default     = "Sunday"
}

variable "patch_schedule_hour" {
  description = "Hour of day for patching (UTC)"
  type        = number
  default     = 2
}

variable "allowed_subnet_cidrs" {
  description = "List of subnet CIDRs allowed to access Redis"
  type        = list(string)
  default     = []
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for Redis"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
