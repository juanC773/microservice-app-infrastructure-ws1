variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "microservice-app-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "main-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "Name of the subnet for microservices"
  type        = string
  default     = "micro-service-subnet"
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the subnet"
  type        = list(string)
  default     = ["10.0.0.0/23"]
}

variable "container_environment_name" {
  description = "Name of the container app environment"
  type        = string
  default     = "microservices-env"
}

variable "log_analytics_workspace_name" {
  description = "Name of the log analytics workspace"
  type        = string
  default     = "acctest-01"
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

variable "jwt_secret" {
  description = "JWT secret for authentication across microservices"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "microservices-app"
    Owner       = "DevOps Team"
  }
}
