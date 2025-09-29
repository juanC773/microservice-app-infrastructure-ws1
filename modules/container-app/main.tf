resource "azurerm_container_app" "this" {
  name                         = var.app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode
  tags                         = var.tags

  dynamic "template" {
    for_each = [var.template]
    content {
      min_replicas = template.value.min_replicas
      max_replicas = template.value.max_replicas

      dynamic "container" {
        for_each = template.value.containers
        content {
          name   = container.value.name
          image  = container.value.image
          cpu    = container.value.cpu
          memory = container.value.memory

          dynamic "env" {
            for_each = container.value.env_vars
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
        }
      }

      # Reglas de Auto Scaling basadas en HTTP
      dynamic "http_scale_rule" {
        for_each = template.value.http_scale_rules != null ? template.value.http_scale_rules : []
        content {
          name                = http_scale_rule.value.name
          concurrent_requests = http_scale_rule.value.concurrent_requests
        }
      }

      # Reglas de Auto Scaling personalizadas (CPU, Memoria, etc.)
      dynamic "custom_scale_rule" {
        for_each = template.value.custom_scale_rules != null ? template.value.custom_scale_rules : []
        content {
          name             = custom_scale_rule.value.name
          custom_rule_type = custom_scale_rule.value.custom_rule_type
          metadata         = custom_scale_rule.value.metadata

          dynamic "authentication" {
            for_each = custom_scale_rule.value.authentication != null ? [custom_scale_rule.value.authentication] : []
            content {
              secret_name       = authentication.value.secret_name
              trigger_parameter = authentication.value.trigger_parameter
            }
          }
        }
      }
    }
  }

  dynamic "ingress" {
    for_each = var.ingress != null ? [var.ingress] : []
    content {
      external_enabled = ingress.value.external_enabled
      target_port      = ingress.value.target_port
      transport        = ingress.value.transport

      traffic_weight {
        percentage      = ingress.value.traffic_percentage
        latest_revision = ingress.value.latest_revision
      }
    }
  }
}
