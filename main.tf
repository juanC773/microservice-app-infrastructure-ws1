provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "microservice-app-rg" {
  name     = "microservice-app-rg"
  location = "West Europe"
}

resource "azurerm_log_analytics_workspace" "microservice-app-law" {
  name                = "acctest-01"
  location            = azurerm_resource_group.microservice-app-rg.location
  resource_group_name = azurerm_resource_group.microservice-app-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "microservices-env" {
  name                       = "microservices-env"
  location                   = azurerm_resource_group.microservice-app-rg.location
  resource_group_name        = azurerm_resource_group.microservice-app-rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.microservice-app-law.id

  depends_on = [azurerm_resource_provider_registration.container_app]
}

resource "azurerm_container_app" "users-app" {
  name                         = "users-app"
  container_app_environment_id = azurerm_container_app_environment.microservices-env.id
  resource_group_name          = azurerm_resource_group.microservice-app-rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "users-app-container"
      image  = "torres05/users-api-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8083

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "auth-app" {
  name                         = "auth-app"
  container_app_environment_id = azurerm_container_app_environment.microservices-env.id
  resource_group_name          = azurerm_resource_group.microservice-app-rg.name
  revision_mode                = "Single"

  depends_on = [azurerm_container_app.users-app]

  template {
    container {
      name   = "auth-app-container"
      image  = "torres05/auth-api-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
