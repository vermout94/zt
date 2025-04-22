output "management_resource_group_name" {
  description = "Name of the Management resources Resource Group"
  value       = module.enterprise_scale.azurerm_resource_group["management"][var.default_location].name
}

output "connectivity_resource_group_name" {
  description = "Name of the Connectivity (hub) Resource Group"
  value       = module.enterprise_scale.azurerm_resource_group["connectivity"][var.default_location].name
}

output "azure_firewall_public_ip" {
  description = "Public IP address of the Azure Firewall"
  value       = module.enterprise_scale.azurerm_public_ip["connectivity"][var.default_location].ip_address
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace"
  value       = module.enterprise_scale.azurerm_log_analytics_workspace["management"][var.default_location].id
}
