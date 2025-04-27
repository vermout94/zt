// --------------------------------------------------------------------------------
// Logging & Monitoring
// --------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "ZeroTrust-LogAnalytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = { Purpose = "SecurityLogs" }
}

resource "azurerm_monitor_diagnostic_setting" "fw_diagnostics" {
  name                       = "FirewallDiagnostics"
  target_resource_id         = azurerm_firewall.firewall.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "web_nsg_diagnostics" {
  name                       = "NSGDiagnostics-Web"
  target_resource_id         = azurerm_network_security_group.web_nsg.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }
  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "db_nsg_diagnostics" {
  name                       = "NSGDiagnostics-DB"
  target_resource_id         = azurerm_network_security_group.db_nsg.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }
  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "subscription_activity_logs" {
  name                       = "SendActivityLogsToLogAnalytics"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Policy"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "ServiceHealth"
  }

  enabled_log {
    category = "Alert"
  }

  enabled_log {
    category = "Recommendation"
  }

  metric {
    category = "AllMetrics"
  }
}

