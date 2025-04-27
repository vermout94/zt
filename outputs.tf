// Key outputs for verification and testing
output "firewall_public_ip" {
  description = "Public IP address of the Azure Firewall (use this to test inbound access via DNAT)."
  value       = azurerm_public_ip.fw_public_ip.ip_address
}

output "web_vm_private_ip" {
  description = "Private IP of the Web VM."
  value       = azurerm_network_interface.web_nic.private_ip_address
}

output "db_vm_private_ip" {
  description = "Private IP of the DB VM."
  value       = azurerm_network_interface.db_nic.private_ip_address
}

output "log_analytics_workspace_id" {
  description = "Resource ID of Log Analytics workspace (for querying logs)."
  value       = azurerm_log_analytics_workspace.logs.id
}

output "demo_users_group_id" {
  description = "The Object ID of the Azure AD group for demo users."
  value       = azuread_group.demo_users.id
}
