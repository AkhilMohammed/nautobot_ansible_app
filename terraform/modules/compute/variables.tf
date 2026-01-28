variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
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

variable "subnet_app_id" {
  description = "Application subnet ID"
  type        = string
}

variable "subnet_data_id" {
  description = "Data subnet ID"
  type        = string
}

variable "lb_backend_pool_id" {
  description = "Load Balancer backend pool ID"
  type        = string
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for admin user"
  type        = string
}

variable "boot_diagnostics_storage_uri" {
  description = "Storage URI for boot diagnostics"
  type        = string
}

# PostgreSQL VM Configuration
variable "postgres_vm_size" {
  description = "PostgreSQL VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "postgres_private_ip" {
  description = "Static private IP for PostgreSQL"
  type        = string
}

variable "postgres_disk_size_gb" {
  description = "PostgreSQL data disk size in GB"
  type        = number
  default     = 128
}

variable "postgres_disk_type" {
  description = "PostgreSQL disk type"
  type        = string
  default     = "Premium_LRS"
}

# Redis VM Configuration
variable "redis_vm_size" {
  description = "Redis VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "redis_private_ip" {
  description = "Static private IP for Redis"
  type        = string
}

# Scheduler VM Configuration
variable "scheduler_vm_size" {
  description = "Scheduler VM size"
  type        = string
  default     = "Standard_B2s"
}

# Web VMSS Configuration
variable "web_vm_size" {
  description = "Web VM size"
  type        = string
  default     = "Standard_B2ms"
}

variable "web_instance_count" {
  description = "Initial number of web instances"
  type        = number
  default     = 2
}

variable "web_min_instances" {
  description = "Minimum web instances"
  type        = number
  default     = 2
}

variable "web_max_instances" {
  description = "Maximum web instances"
  type        = number
  default     = 10
}

# Worker VMSS Configuration
variable "worker_vm_size" {
  description = "Worker VM size"
  type        = string
  default     = "Standard_B2ms"
}

variable "worker_instance_count" {
  description = "Initial number of worker instances"
  type        = number
  default     = 2
}

variable "worker_min_instances" {
  description = "Minimum worker instances"
  type        = number
  default     = 2
}

variable "worker_max_instances" {
  description = "Maximum worker instances"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
