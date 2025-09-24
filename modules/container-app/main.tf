resource "azurerm_container_app" "this" {
  name                         = var.app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode
  tags                         = var.tags

  dynamic "template" {
    for_each = [var.template]
    content {
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
