# Resource Group Module
module "resource_group" {
  source = "./modules/resource-group"

  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.common_tags
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  vnet_name           = var.vnet_name
  address_space       = var.vnet_address_space
  subnet_name         = var.subnet_name
  address_prefixes    = var.subnet_address_prefixes
  subnet_delegation = {
    name         = "Microsoft.App.enviroments"
    service_name = "Microsoft.App/environments"
    actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
  tags = var.common_tags
}

# Container Environment Module
module "container_environment" {
  source = "./modules/container-environment"

  resource_group_name          = module.resource_group.resource_group_name
  location                     = module.resource_group.resource_group_location
  environment_name             = var.container_environment_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_sku            = var.log_analytics_sku
  log_retention_days           = var.log_retention_days
  tags                         = var.common_tags
}

# Users App
module "users_app" {
  source = "./modules/container-app"

  app_name                     = "users-app"
  resource_group_name          = module.resource_group.resource_group_name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {
    containers = [{
      name   = "users-app-container"
      image  = "torres05/users-api-ws1:latest"
      cpu    = 0.5
      memory = "1.0Gi"
      env_vars = [
        {
          name  = "SERVER_PORT"
          value = "8083"
        },
        {
          name  = "SERVER_ADDRESS"
          value = "0.0.0.0"
        },
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        }
      ]
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 8083
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags = var.common_tags
}

# Auth App
module "auth_app" {
  source = "./modules/container-app"

  app_name                     = "auth-app"
  resource_group_name          = module.resource_group.resource_group_name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {
    containers = [{
      name   = "auth-app-container"
      image  = "torres05/auth-api-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env_vars = [
        {
          name  = "AUTH_API_PORT"
          value = "8000"
        },
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        },
        {
          name  = "USERS_API_ADDRESS"
          value = "http://users-app"
        }
      ]
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 8000
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags       = var.common_tags
  depends_on = [module.users_app]
}

# Todos App
module "todos_app" {
  source = "./modules/container-app"

  app_name                     = "todos-app"
  resource_group_name          = module.resource_group.resource_group_name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {
    containers = [{
      name   = "todos-app-container"
      image  = "juanc7773/todos-api-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env_vars = [
        {
          name  = "TODO_API_PORT"
          value = "8082"
        },
        {
          name  = "JWT_SECRET"
          value = "PRFT"
        },
        {
          name  = "REDIS_HOST"
          value = "redis-app"
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        },
        {
          name  = "REDIS_CHANNEL"
          value = "log_channel"
        }
      ]
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 8082
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags = var.common_tags
}

# Frontend App
module "frontend_app" {
  source = "./modules/container-app"

  app_name                     = "frontend-app"
  resource_group_name          = module.resource_group.resource_group_name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {
    containers = [{
      name   = "frontend-app-container"
      image  = "juanc7773/frontend-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env_vars = [
        {
          name  = "AUTH_API_ADDRESS"
          value = "https://auth-app.${module.container_environment.container_app_environment_domain}"
        },
        {
          name  = "TODOS_API_ADDRESS"
          value = "https://todos-app.${module.container_environment.container_app_environment_domain}"
        }
      ]
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 80
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags       = var.common_tags
  depends_on = [module.auth_app, module.todos_app]
}
