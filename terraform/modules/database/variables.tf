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

variable "db_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "psqladmin"
}

variable "db_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Nautobot database name"
  type        = string
  default     = "nautobot"
}

variable "postgresql_sku" {
  description = "PostgreSQL SKU (e.g., B_Standard_B1ms, GP_Standard_D2s_v3, MO_Standard_E4s_v3)"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Backup retention days"
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup"
  type        = bool
  default     = false
}

variable "high_availability_enabled" {
  description = "Enable high availability"
  type        = bool
  default     = false
}

variable "standby_availability_zone" {
  description = "Standby availability zone for HA"
  type        = string
  default     = "2"
}

variable "max_connections" {
  description = "Maximum number of connections"
  type        = string
  default     = "200"
}

variable "shared_buffers" {
  description = "Shared buffers in 8kB units"
  type        = string
  default     = "32768"
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access PostgreSQL"
  type        = list(string)
  default     = []
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks of application subnets"
  type        = list(string)
  default     = []
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for PostgreSQL"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
