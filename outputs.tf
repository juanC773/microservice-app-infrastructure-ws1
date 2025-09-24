output "users_app_url" {
  description = "URL del servicio de usuarios"
  value       = module.users_app.container_app_url
}

output "auth_app_url" {
  description = "URL del servicio de autenticación"
  value       = module.auth_app.container_app_url
}

output "todos_app_url" {
  description = "URL del servicio de TODOs"
  value       = module.todos_app.container_app_url
}

output "frontend_app_url" {
  description = "URL del frontend"
  value       = module.frontend_app.container_app_url
}

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = module.resource_group.resource_group_name
}

output "container_environment_id" {
  description = "ID of the container app environment"
  value       = module.container_environment.container_app_environment_id
}
