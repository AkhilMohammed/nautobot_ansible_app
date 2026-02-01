variable "project_name" {
  description = "Project name for resource naming"
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

variable "subnet_id" {
  description = "Subnet ID for the jumpbox"
  type        = string
}

variable "network_security_group_id" {
  description = "NSG ID to associate with the jumpbox NIC"
  type        = string
}

variable "admin_username" {
  description = "Admin username"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "vm_size" {
  description = "Jumpbox VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
