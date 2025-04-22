// Data source to get current tenant ID if needed (not used directly since var.tenant_id is provided)
// data "azurerm_client_config" "current" {}

// Main Enterprise-Scale module configuration
module "enterprise_scale" {
  source           = "Azure/caf-enterprise-scale/azurerm"
  version          = "6.2.1"
  default_location = var.default_location

  providers = {
    azurerm              = azurerm
    azurerm.management   = azurerm.management
    azurerm.connectivity = azurerm.connectivity
    azapi                = azapi
  }

  # Management Groups hierarchy root (Tenant Root Group as parent)
  root_parent_id = var.tenant_id      // Tenant ID as the parent for the "Enterprise-Scale" root MG
  root_id        = "es"               // Management Group ID prefix (default "es")
  root_name      = "Enterprise-Scale" // Management Group display name (default provided by module)

  # Enable core platform resources in this subscription
  deploy_connectivity_resources = true // Deploy hub network (connectivity) resources in current subscription&#8203;:contentReference[oaicite:5]{index=5}
  deploy_management_resources   = true // Deploy management resources (Log Analytics, etc.) in current subscription

  subscription_id_connectivity = var.subscription_id
  # subscription_id_management is left empty, so the subscription will be treated as Connectivity by default

  # Customize Connectivity (network) resources – hub VNet, firewall, DNS, DDoS, etc.
  configure_connectivity_resources = {
    settings = {
      hub_networks = [{
        enabled = true
        config = {
          location                     = var.default_location
          address_space                = ["10.10.0.0/16"]
          link_to_ddos_protection_plan = true

          subnets = [
            {
              name             = "AzureFirewallSubnet"
              address_prefixes = ["10.10.1.0/26"]
            },
            {
              name                      = "AzureFirewallManagementSubnet"
              address_prefixes          = ["10.10.1.64/26"]
              network_security_group_id = azurerm_network_security_group.fw_mgmt.id
            }
          ]
        }
      }]

      azure_firewall = {
        enabled = true
        config = {
          address_prefix            = "10.10.1.0/26"
          address_management_prefix = "10.10.1.64/26"
          sku_tier                  = "Standard"
          enable_dns_proxy          = true
        }
      }

      ddos_protection_plan = {
        enabled  = true
        location = var.default_location
      }
      deploy_virtual_wan                       = false
      deploy_virtual_hub                       = false
      deploy_virtual_hub_connection            = false
      deploy_virtual_hub_routing_intent        = false
      deploy_virtual_hub_vpn_gateway           = false
      deploy_virtual_hub_express_route_gateway = false
      deploy_outbound_virtual_network_peering  = false
      deploy_hub_virtual_network_mesh_peering  = false

      # disable DNS automation since you're not using Private DNS or Public DNS zones
      private_dns_zones                                      = []
      public_dns_zones                                       = []
      enable_private_dns_zone_virtual_network_link_on_hubs   = false
      enable_private_dns_zone_virtual_network_link_on_spokes = false

      # *** TURN OFF ALL DNS ***
      dns = {
        enabled = false
      }
    }

    location = var.default_location
    tags     = {}
    advanced = null
  }

  # Customize Management resources – Log Analytics workspace and Azure Security Center/Defender
  configure_management_resources = {
    settings = {
      log_analytics = {
        enabled = true
        config = {
          retention_in_days = 30 // Retain logs for 30 days in Log Analytics
          # Enable essential monitoring solutions as needed (disable optional ones not used)
          enable_monitoring_for_vm                          = true // Monitor VMs (if any) via Log Analytics agent
          enable_monitoring_for_vmss                        = true
          enable_solution_for_agent_health_assessment       = true
          enable_solution_for_anti_malware                  = true
          enable_solution_for_change_tracking               = true
          enable_solution_for_service_map                   = false // Disable Service Map (not needed if no dependency agent)
          enable_solution_for_sql_assessment                = false // Disable SQL assessment solution (not required)&#8203;:contentReference[oaicite:10]{index=10}
          enable_solution_for_sql_vulnerability_assessment  = false // Disable SQL vulnerability assessment solution
          enable_solution_for_sql_advanced_threat_detection = false // Disable SQL threat detection solution (optional feature)
          enable_solution_for_updates                       = true
          enable_solution_for_vm_insights                   = true
          enable_solution_for_container_insights            = false // Disable container insights (no AKS in this minimal setup)
          enable_sentinel                                   = false // Disable Azure Sentinel (can be enabled if needed)
        }
      }
      security_center = {
        enabled = true
        config = {
          // Turn off Defender for services that are out-of-scope (SQL DB, SQL VMs, Storage)&#8203;:contentReference[oaicite:11]{index=11}&#8203;:contentReference[oaicite:12]{index=12}
          enable_defender_for_sql_servers    = false
          enable_defender_for_sql_server_vms = false
          enable_defender_for_storage        = false
          // (Other Microsoft Defender for Cloud plans remain enabled by default: e.g., Servers, KeyVault, DNS, etc.)
        }
      }
    }
    location = var.default_location
    tags     = {}
    advanced = null
  }
}
