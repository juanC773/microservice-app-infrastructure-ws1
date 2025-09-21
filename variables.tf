variable "subscription_id" {
  description = "The Subscription ID where resources will be created."
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret for authentication across microservices"
  type        = string
  sensitive   = true
  default     = "PRFT"
}
