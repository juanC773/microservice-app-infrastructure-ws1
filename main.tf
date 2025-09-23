provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "microservice-app-rg" {
  name     = "microservice-app-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "main-vnet" {
  name                = "main-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.microservice-app-rg.location
  resource_group_name = azurerm_resource_group.microservice-app-rg.name
}

resource "azurerm_subnet" "micro-service-subnet" {
  name                 = "micro-service-subnet"
  resource_group_name  = azurerm_resource_group.microservice-app-rg.name
  virtual_network_name = azurerm_virtual_network.main-vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "Microsoft.App.enviroments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
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

resource "azurerm_container_app" "redis-app" {
  name                         = "redis-app"
  container_app_environment_id = azurerm_container_app_environment.microservices-env.id
  resource_group_name          = azurerm_resource_group.microservice-app-rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "redis-container"
      image  = "redis:7.0"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
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
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "SERVER_PORT"
        value = "8083"
      }

      env {
        name  = "SERVER_ADDRESS"
        value = "0.0.0.0"
      }

      env {
        name  = "JWT_SECRET"
        value = "PRFT"
      }
    }
  }

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
        name  = "AUTH_API_PORT"
        value = "8000"
      }

      env {
        name  = "JWT_SECRET"
        value = "PRFT"
      }

      env {
        name  = "USERS_API_ADDRESS"
        value = "http://users-app"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

resource "azurerm_container_app" "todos-app" {
  name                         = "todos-app"
  container_app_environment_id = azurerm_container_app_environment.microservices-env.id
  resource_group_name          = azurerm_resource_group.microservice-app-rg.name
  revision_mode                = "Single"

  depends_on = [azurerm_container_app.redis-app]

  template {
    container {
      name   = "todos-app-container"
      image  = "juanc7773/todos-api-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "TODO_API_PORT"
        value = "8082"
      }

      env {
        name  = "JWT_SECRET"
        value = "PRFT"
      }

      env {
        name  = "REDIS_HOST"
        value = "redis-app"
      }

      env {
        name  = "REDIS_PORT"
        value = "6379"
      }

      env {
        name  = "REDIS_CHANNEL"
        value = "log_channel"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8082
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

  depends_on = [azurerm_container_app.auth-app, azurerm_container_app.todos-app]

  template {
    container {
      name   = "frontend-app-container"
      image  = "juanc7773/frontend-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AUTH_API_ADDRESS"
        value = "https://auth-app.${azurerm_container_app_environment.microservices-env.default_domain}"
      }

      env {
        name  = "TODOS_API_ADDRESS"
        value = "https://todos-app.${azurerm_container_app_environment.microservices-env.default_domain}"
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
