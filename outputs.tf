output "auth_app_url" {
  description = "URL del servicio de autenticación"
  value       = "https://${azurerm_container_app.auth-app.latest_revision_fqdn}"
}

