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

      env {
        name  = "SERVER_PORT"
        value = "8083"
      }

      env {
        name = "JWT_SECRET"
        #secret_name = "jwt-secret"
        value = "PRFT"
      }
    }
  }

  #  secret {
  #    name  = "jwt-secret"
  #    value = var.jwt_secret
  #  }

  ingress {
    external_enabled = true
    target_port      = 8083
    transport        = "http"

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

      env {
        name  = "SERVER_PORT"
        value = "80"
      }

      env {
        name = "JWT_SECRET"
        #secret_name = "jwt-secret"
        value = "PRFT"
      }

      env {
        name  = "USERS_API_ADDRESS"
        value = "https://${azurerm_container_app.users-app.ingress[0].fqdn}"
      }
    }
  }

  #  secret {}

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}


resource "azurerm_container_app" "frontend-app" {
  name                         = "frontend-app"
  container_app_environment_id = azurerm_container_app_environment.microservices-env.id
  resource_group_name          = azurerm_resource_group.microservice-app-rg.name
  revision_mode                = "Single"

  depends_on = [azurerm_container_app.auth-app]

  template {
    container {
      name   = "frontend-app-container"
      image  = "juanc7773/frontend-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AUTH_API_ADDRESS"
        value = "https://${azurerm_container_app.auth-app.ingress[0].fqdn}"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}