output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = azurerm_subnet.this.id
}
