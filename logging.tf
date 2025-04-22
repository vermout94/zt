// Network Security Group for Azure Firewall management subnet (attached above via ID)
resource "azurerm_network_security_group" "fw_mgmt" {
  name                = "nsg-firewall-mgmt"
  location            = var.default_location
  resource_group_name = module.enterprise_scale.azurerm_resource_group["connectivity"][var.default_location].name
  security_rule       = [] # (No custom rules here; using default NSG rules which deny unsolicited inbound traffic)
}

// Diagnostic Settings to send Azure Firewall logs to Log Analytics workspace
resource "azurerm_monitor_diagnostic_setting" "firewall_logs" {
  name                       = "diag-AzureFirewall"
  target_resource_id         = module.enterprise_scale.azurerm_firewall["connectivity"][var.default_location].id
  log_analytics_workspace_id = module.enterprise_scale.azurerm_log_analytics_workspace["management"][var.default_location].id

  enabled_log {
    category = "AzureFirewallApplicationRule" # Application rule logs
  }
  enabled_log {
    category = "AzureFirewallNetworkRule" # Network rule logs
  }
  enabled_log {
    category = "AzureFirewallDnsProxy" # DNS proxy logs (if DNS proxy is enabled on firewall)
  }
  metric {
    category = "AllMetrics" # Include firewall metrics (CPU, firewall health, etc.)
    enabled  = true
  }
  depends_on = [module.enterprise_scale] // Ensure module resources (firewall, workspace) are created first
}
