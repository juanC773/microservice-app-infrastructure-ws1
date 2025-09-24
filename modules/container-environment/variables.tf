variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment_name" {
  description = "Name of the container app environment"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the log analytics workspace"
  type        = string
}

variable "log_analytics_sku" {
  description = "SKU of the log analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
}

variable "subnet_id" {
  description = "ID of the subnet for container apps"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
