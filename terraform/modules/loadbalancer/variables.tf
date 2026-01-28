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

variable "lb_sku" {
  description = "Load Balancer SKU (Basic or Standard)"
  type        = string
  default     = "Standard"
}

variable "availability_zones" {
  description = "Availability zones for Load Balancer"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
