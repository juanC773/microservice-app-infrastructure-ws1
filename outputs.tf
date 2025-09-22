output "users_app_url" {
  description = "URL del servicio de usuarios"
  value       = "https://${azurerm_container_app.users-app.latest_revision_fqdn}"
}



output "auth_app_url" {
  description = "URL del servicio de autenticación"
  value       = "https://${azurerm_container_app.auth-app.latest_revision_fqdn}"
}

output "frontend_app_url" {
  description = "URL del frontend"
  value       = "https://${azurerm_container_app.frontend-app.ingress[0].fqdn}"
}