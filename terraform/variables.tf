# General Configuration
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

# Network Configuration
variable "vnet_address_space" {
  description = "Virtual network address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "app_subnet_cidr" {
  description = "Application subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

# Database Configuration (Azure PostgreSQL Managed)
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

variable "postgresql_sku" {
  description = "PostgreSQL SKU (B_Standard_B1ms, GP_Standard_D2s_v3, MO_Standard_E4s_v3)"
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
  description = "Enable high availability for PostgreSQL"
  type        = bool
  default     = false
}

# Redis Configuration (Azure Cache for Redis Managed)
variable "redis_sku" {
  description = "Redis SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis family (C for Basic/Standard, P for Premium)"
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis capacity (0-6)"
  type        = number
  default     = 1
}

# VM Configuration
variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "web_vm_count" {
  description = "Number of Nautobot web VMs"
  type        = number
  default     = 2
}

variable "web_vm_size" {
  description = "VM size for Nautobot web"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "worker_vm_count" {
  description = "Number of Nautobot worker VMs"
  type        = number
  default     = 2
}

variable "worker_vm_size" {
  description = "VM size for Nautobot worker"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "scheduler_vm_count" {
  description = "Number of Nautobot scheduler VMs"
  type        = number
  default     = 1
}

variable "scheduler_vm_size" {
  description = "VM size for Nautobot scheduler"
  type        = string
  default     = "Standard_B2s"
}

# Load Balancer Configuration
variable "lb_frontend_ip_allocation" {
  description = "Load balancer frontend IP allocation (Static or Dynamic)"
  type        = string
  default     = "Static"
}

variable "lb_sku" {
  description = "Load balancer SKU (Basic or Standard)"
  type        = string
  default     = "Standard"
}

# Storage Configuration
variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

# Private Endpoint Configuration
variable "enable_private_endpoint" {
  description = "Enable private endpoints for managed services"
  type        = bool
  default     = false
}
