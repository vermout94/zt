// --------------------------------------------------------------------------------
// Resource Group
// --------------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project = "ZeroTrustPrototype"
    Owner   = "StudentThesis"
  }
}

// --------------------------------------------------------------------------------
// Virtual Network and Subnets
// --------------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "zero-trust-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_address_space]

  tags = {
    Environment = "Demo"
  }
}

locals {
  subnet_prefixes = {
    AzureFirewallSubnet           = "10.0.0.0/26"
    AzureFirewallManagementSubnet = "10.0.0.64/26"
    WebSubnet                     = "10.0.1.0/24"
    DBSubnet                      = "10.0.2.0/24"
  }
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.AzureFirewallSubnet]
}

resource "azurerm_subnet" "firewall_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.AzureFirewallManagementSubnet]
}

resource "azurerm_subnet" "web" {
  name                 = "WebSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.WebSubnet]
}

resource "azurerm_subnet" "db" {
  name                 = "DBSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.DBSubnet]
}

// --------------------------------------------------------------------------------
// Network Security Groups (NSGs)
// --------------------------------------------------------------------------------
resource "azurerm_network_security_group" "web_nsg" {
  name                = "WebSubnet-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = { SecurityZone = "WebTier" }
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "DBSubnet-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = { SecurityZone = "DBTier" }
}

resource "azurerm_network_security_rule" "web_allow_http" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Allow-HTTP-In"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "80"
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}

resource "azurerm_network_security_rule" "web_allow_ssh" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Allow-SSH-In"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}

resource "azurerm_network_security_rule" "db_allow_sql" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Allow-SQL-From-Web"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = local.subnet_prefixes.WebSubnet
  destination_address_prefix  = "*"
  destination_port_range      = "3306"
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.db_nsg.name
}

# Uncomment this block if you want to allow SSH from Web VM to DB VM
# This is not recommended in a Zero Trust model, but included for demonstration.
# resource "azurerm_network_security_rule" "db_allow_ssh" {
#   resource_group_name         = azurerm_resource_group.rg.name
#   name                        = "Allow-SSH-From-WebVM"
#   priority                    = 130
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_address_prefix       = local.subnet_prefixes.WebSubnet
#   destination_address_prefix  = "*"
#   destination_port_range      = "22"
#   source_port_range           = "*"
#   network_security_group_name = azurerm_network_security_group.db_nsg.name
# }

resource "azurerm_network_security_rule" "db_deny_web_all" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Deny-OtherFrom-Web"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = local.subnet_prefixes.WebSubnet
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.db_nsg.name
}


resource "azurerm_network_security_rule" "db_deny_all" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Deny-All-Others"
  priority                    = 500
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.db_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

// --------------------------------------------------------------------------------
// Azure Firewall and Public IPs
// --------------------------------------------------------------------------------
resource "azurerm_public_ip" "fw_public_ip" {
  name                = "AzureFirewall-PIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "fw_mgmt_public_ip" {
  name                = "AzureFirewallMgmt-PIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "firewall" {
  name                = "ZeroTrustAzureFirewall"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  firewall_policy_id = azurerm_firewall_policy.fw_policy.id

  ip_configuration {
    name                 = "fw-config"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw_public_ip.id
  }
  management_ip_configuration {
    name                 = "fw-mgmt-config"
    subnet_id            = azurerm_subnet.firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.fw_mgmt_public_ip.id
  }
  tags = { Environment = "Demo" }
}

resource "azurerm_virtual_network_dns_servers" "vnet_dns" {
  virtual_network_id = azurerm_virtual_network.vnet.id

  dns_servers = [
    azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  ]

  depends_on = [
    azurerm_firewall.firewall
  ]
}

resource "azurerm_firewall_policy" "fw_policy" {
  name                = "ZeroTrustFirewallPolicy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku = "Standard"

  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true
    servers       = ["8.8.8.8", "8.8.4.4"]
  }

  private_ip_ranges = [
    "10.0.0.0/8"
  ]
}


resource "azurerm_firewall_policy_rule_collection_group" "fw_policy_collection" {
  name               = "ZeroTrustPolicyCollection"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 150

  network_rule_collection {
    name     = "AllowInternalMySQL"
    priority = 150
    action   = "Allow"

    rule { #Web to DB IN
      name                  = "AllowMySQLInternal"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["10.0.2.0/24"]
      destination_ports     = ["3306"]
    }
    rule { #DB to Web OUT
      name                  = "AllowMySQLOutbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.0.1.0/24"]
      destination_addresses = ["10.0.2.0/24"]
      destination_ports     = ["3306"]
    }
    rule {
      name                  = "AllowDNS"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["8.8.8.8", "8.8.4.4"]
      destination_ports     = ["53"]
    }
    # only for testing purposes
    # rule { #WebVM to DBVM
    #   name                  = "AllowSSHFromWebVM"
    #   protocols             = ["TCP"]
    #   source_addresses      = ["10.0.1.0/24"]
    #   destination_addresses = ["10.0.2.0/24"]
    #   destination_ports     = ["22"]
    # }
    # rule {
    #   name              = "Allow-Ubuntu"
    #   protocols         = ["TCP"]
    #   source_addresses  = ["*"]
    #   destination_fqdns = ["azure.archive.ubuntu.com", "security.ubuntu.com"]
    #   destination_ports = ["80", "443"]
    # }
  }

  application_rule_collection {
    name     = "AllowOutboundWeb"
    priority = 300
    action   = "Allow"

    rule {
      name              = "Allow-Google"
      source_addresses  = ["*"]
      destination_fqdns = ["www.google.com", "*.google.com"]
      protocols {
        port = "443"
        type = "Https"
      }
    }
    rule {
      name              = "Allow-Technikum"
      source_addresses  = ["*"]
      destination_fqdns = ["www.technikum-wien.at"]
      protocols {
        port = "443"
        type = "Https"
      }
    }
    rule {
      name              = "Allow-Microsoft"
      source_addresses  = ["*"]
      destination_fqdns = ["windowsupdate.microsoft.com", "update.microsoft.com"]
      protocols {
        port = "443"
        type = "Https"
      }
    }
    rule {
      name              = "Allow-MS-Packages"
      source_addresses  = ["*"]
      destination_fqdns = ["packages.microsoft.com", "download.microsoft.com", "*.azureedge.net", "login.microsoftonline.com"]
      protocols {
        port = "443"
        type = "Https"
      }
    }
    rule {
      name             = "Allow-Ubuntu-Repos"
      source_addresses = ["*"]
      destination_fqdns = [
        "azure.archive.ubuntu.com",
        "security.ubuntu.com"
      ]
      protocols {
        port = "80"
        type = "Http"
      }
      protocols {
        port = "443"
        type = "Https"
      }
    }
  }

  application_rule_collection {
    name     = "DenyAllOutboundApp"
    priority = 500
    action   = "Deny"

    rule {
      name              = "DenyAllFQDN"
      source_addresses  = ["*"]
      destination_fqdns = ["*"]
      protocols {
        type = "Http"
        port = "80"
      }
      protocols {
        type = "Https"
        port = "443"
      }
    }
  }

  nat_rule_collection {
    name     = "DNAT-Access"
    priority = 160
    action   = "Dnat"

    rule {
      name                = "DNAT-HTTP"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.fw_public_ip.ip_address
      destination_ports   = ["80"]
      translated_address  = azurerm_network_interface.web_nic.private_ip_address
      translated_port     = "80"
    }

    rule {
      name                = "DNAT-SSH"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.fw_public_ip.ip_address
      destination_ports   = ["22"]
      translated_address  = azurerm_network_interface.web_nic.private_ip_address
      translated_port     = "22"
    }
  }
}


// --------------------------------------------------------------------------------
// Route Tables
// --------------------------------------------------------------------------------
resource "azurerm_route_table" "udr" {
  name                = "ZeroTrust-RouteTable"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = { Purpose = "ForceTunnelToFirewall" }
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "DefaultToFirewall"
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  route_table_name       = azurerm_route_table.udr.name
  resource_group_name    = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_route_table_association" "web_udr_assoc" {
  subnet_id      = azurerm_subnet.web.id
  route_table_id = azurerm_route_table.udr.id
  depends_on     = [azurerm_route.default_to_firewall]
}

resource "azurerm_subnet_route_table_association" "db_udr_assoc" {
  subnet_id      = azurerm_subnet.db.id
  route_table_id = azurerm_route_table.udr.id
}
