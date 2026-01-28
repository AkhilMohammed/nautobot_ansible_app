variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

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

variable "vnet_address_space" {
  description = "VNet address space"
  type        = string
}

variable "subnet_frontend" {
  description = "Frontend subnet CIDR"
  type        = string
}

variable "subnet_app" {
  description = "Application subnet CIDR"
  type        = string
}

variable "subnet_data" {
  description = "Data subnet CIDR"
  type        = string
}

variable "subnet_bastion" {
  description = "Bastion subnet CIDR"
  type        = string
  default     = ""
}

variable "enable_bastion" {
  description = "Enable Azure Bastion"
  type        = bool
  default     = false
}

variable "enable_ssh_access" {
  description = "Enable SSH access to app VMs"
  type        = bool
  default     = true
}

variable "ssh_source_addresses" {
  description = "Allowed source IP addresses for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "availability_zones" {
  description = "Availability zones for resources"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
