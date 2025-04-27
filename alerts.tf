resource "azurerm_monitor_action_group" "email_alerts" {
  name                = "EmailActionGroup"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "emailalerts"

  email_receiver {
    name                    = "admin"
    email_address           = "" # Replace with your email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "resource_delete_alert" {
  name                = "ResourceDeleteAlert"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  data_source_id = azurerm_log_analytics_workspace.logs.id
  description    = "Alert when any resource is deleted."
  enabled        = true
  severity       = 2
  frequency      = 5
  time_window    = 5

  query = <<-QUERY
    AzureActivity
    | where OperationNameValue endswith "delete"
    | where ActivityStatusValue == "Succeeded"
    | project TimeGenerated, Caller, ResourceGroup, ResourceId, OperationNameValue
  QUERY

  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }

  action {
    action_group = azurerm_monitor_action_group.email_alerts.id
  }
}
