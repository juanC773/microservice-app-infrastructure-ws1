output "users_app_url" {
  description = "URL del servicio de usuarios"
  value       = "https://${azurerm_container_app.users-app.ingress[0].fqdn}"
}

output "auth_app_url" {
  description = "URL del servicio de autenticación"
  value       = "https://${azurerm_container_app.auth-app.ingress[0].fqdn}"
}

output "todos_app_url" {
  description = "URL del servicio de TODOs"
  value       = "https://${azurerm_container_app.todos-app.ingress[0].fqdn}"
}

output "frontend_app_url" {
  description = "URL del frontend"
  value       = "https://${azurerm_container_app.frontend-app.ingress[0].fqdn}"
}

output "redis_internal_url" {
  description = "URL interna de Redis"
  value       = azurerm_container_app.redis-app.ingress[0].fqdn
}