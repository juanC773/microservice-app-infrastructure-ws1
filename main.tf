provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "microservice-app-example-rg" {
  name     = "microservice-app-example-rg"
  location = "West Europe"
}

resource "azurerm_container_group" "microservice-app-cg" {
  name                = "microservice-app-cg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  ip_address_type     = "Public"
  dns_name_label      = "aci-label"
  os_type             = "Linux"

  container {
    name   = "users-api-ws1"
    image  = "hub.docker.com/r/torres05/users-api-ws1:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 8083
      protocol = "TCP"
    }
  }

  container {
    name   = "sidecar"
    image  = "mcr.microsoft.com/azuredocs/aci-tutorial-sidecar"
    cpu    = "0.5"
    memory = "1.5"
  }

  tags = {
    environment = "testing"
  }
}
