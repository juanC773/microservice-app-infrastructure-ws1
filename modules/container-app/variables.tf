variable "app_name" {
  description = "Name of the container app"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "container_app_environment_id" {
  description = "ID of the container app environment"
  type        = string
}

variable "revision_mode" {
  description = "Revision mode for the container app"
  type        = string
  default     = "Single"
}

variable "template" {
  description = "Container template configuration"
  type = object({
    containers = list(object({
      name   = string
      image  = string
      cpu    = number
      memory = string
      env_vars = list(object({
        name  = string
        value = string
      }))
    }))
  })
}

variable "ingress" {
  description = "Ingress configuration"
  type = object({
    external_enabled   = bool
    target_port        = number
    transport          = string
    traffic_percentage = number
    latest_revision    = bool
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to the container app"
  type        = map(string)
  default     = {}
}

variable "app_name" {
  description = "Name of the container app"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "container_app_environment_id" {
  description = "ID of the container app environment"
  type        = string
}

variable "revision_mode" {
  description = "Revision mode for the container app"
  type        = string
  default     = "Single"
}

variable "template" {
  description = "Container template configuration"
  type = object({
    min_replicas = optional(number, 1)  # ⬅️ AGREGAR ESTA LÍNEA
    max_replicas = optional(number, 10) # ⬅️ AGREGAR ESTA LÍNEA

    containers = list(object({
      name   = string
      image  = string
      cpu    = number
      memory = string
      env_vars = list(object({
        name  = string
        value = string
      }))
    }))

    # Reglas de auto scaling HTTP
    http_scale_rules = optional(list(object({
      name                = string
      concurrent_requests = number
    })), [])

    # Reglas de auto scaling CPU
    cpu_scale_rules = optional(list(object({
      name                     = string
      cpu_percentage_threshold = number
    })), [])

    # Reglas de auto scaling Memoria
    memory_scale_rules = optional(list(object({
      name                        = string
      memory_percentage_threshold = number
    })), [])
  })
}

variable "ingress" {
  description = "Ingress configuration"
  type = object({
    external_enabled   = bool
    target_port        = number
    transport          = string
    traffic_percentage = number
    latest_revision    = bool
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to the container app"
  type        = map(string)
  default     = {}
}
