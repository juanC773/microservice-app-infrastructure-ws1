output "container_app_id" {
  description = "ID of the container app"
  value       = azurerm_container_app.this.id
}

output "container_app_fqdn" {
  description = "FQDN of the container app"
  value       = var.ingress != null ? azurerm_container_app.this.ingress[0].fqdn : null
}

output "container_app_url" {
  description = "URL of the container app"
  value       = var.ingress != null ? "https://${azurerm_container_app.this.ingress[0].fqdn}" : null
}
