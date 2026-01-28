variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "nautobot"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "vnet_address_space" {
  description = "Virtual Network address space"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_frontend" {
  description = "Frontend subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_app" {
  description = "Application subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_data" {
  description = "Data subnet CIDR"
  type        = string
  default     = "10.0.3.0/24"
}

variable "postgres_private_ip" {
  description = "Static private IP for PostgreSQL VM"
  type        = string
  default     = "10.0.3.10"
}

variable "redis_private_ip" {
  description = "Static private IP for Redis VM"
  type        = string
  default     = "10.0.3.11"
}

variable "ssh_source_addresses" {
  description = "Allowed source IP addresses for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change to your IP range for security
}
