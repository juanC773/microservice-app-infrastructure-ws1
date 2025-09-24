output "container_app_environment_id" {
  description = "ID of the container app environment"
  value       = azurerm_container_app_environment.this.id
}

output "container_app_environment_domain" {
  description = "Default domain of the container app environment"
  value       = azurerm_container_app_environment.this.default_domain
}

output "log_analytics_workspace_id" {
  description = "ID of the log analytics workspace"
  value       = azurerm_log_analytics_workspace.this.id
}
