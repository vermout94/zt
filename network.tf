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
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = local.subnet_prefixes.WebSubnet
  destination_address_prefix  = "*"
  destination_port_range      = "3306"
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.db_nsg.name
}

resource "azurerm_network_security_rule" "db_deny_web_all" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Deny-OtherFrom-Web"
  priority                    = 200
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
  priority                    = 300
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
  sku_tier            = "Basic"

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
  dns_servers = ["8.8.8.8", "8.8.4.4"] # Google's public DNS servers
  tags        = { Environment = "Demo" }
}

resource "azurerm_firewall_network_rule_collection" "allow_all_outbound" {
  resource_group_name = azurerm_resource_group.rg.name
  azure_firewall_name = azurerm_firewall.firewall.name
  name                = "AllowAllOut"
  priority            = 100
  action              = "Allow"
  #   rule {
  #     name                  = "AllowAllOutRule"
  #     protocols             = ["Any"]
  #     source_addresses      = ["*"]
  #     destination_addresses = ["*"]
  #     destination_ports     = ["*"]
  #   }
  rule {
    name                  = "Allow-DNS-Google"
    protocols             = ["UDP"]
    source_addresses      = ["*"]
    destination_addresses = ["8.8.8.8", "8.8.4.4"]
    destination_ports     = ["53"]
  }

  rule {
    name              = "Allow-Microsoft-Updates"
    protocols         = ["TCP"]
    source_addresses  = ["*"]
    destination_fqdns = ["windowsupdate.microsoft.com", "update.microsoft.com"]
    destination_ports = ["80", "443"]
  }

  rule {
    name              = "Allow-Google-Services"
    protocols         = ["TCP"]
    source_addresses  = ["*"]
    destination_fqdns = ["www.google.com", "accounts.google.com"]
    destination_ports = ["80", "443"]
  }

  rule {
    name              = "Allow-Technikum-Wien"
    protocols         = ["TCP"]
    source_addresses  = ["*"]
    destination_fqdns = ["www.technikum-wien.at"]
    destination_ports = ["80", "443"]
  }
}

resource "azurerm_firewall_nat_rule_collection" "fw_dnat" {
  resource_group_name = azurerm_resource_group.rg.name
  azure_firewall_name = azurerm_firewall.firewall.name
  name                = "DNAT-Web"
  priority            = 110
  action              = "Dnat"

  rule {
    name                  = "DNAT-HTTP"
    source_addresses      = ["*"]
    destination_addresses = [azurerm_public_ip.fw_public_ip.ip_address]
    destination_ports     = ["80"]
    protocols             = ["TCP"]
    translated_address    = azurerm_network_interface.web_nic.private_ip_address
    translated_port       = "80"
  }
  rule {
    name                  = "DNAT-SSH"
    source_addresses      = ["*"]
    destination_addresses = [azurerm_public_ip.fw_public_ip.ip_address]
    destination_ports     = ["22"]
    protocols             = ["TCP"]
    translated_address    = azurerm_network_interface.web_nic.private_ip_address
    translated_port       = "22"
  }
}

// --------------------------------------------------------------------------------
// Route Tables
// --------------------------------------------------------------------------------
resource "azurerm_route_table" "udr" {
  name                = "ZeroTrust-RouteTable"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  tags = { Purpose = "ForceTunnelToFirewall" }
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
}

resource "azurerm_subnet_route_table_association" "db_udr_assoc" {
  subnet_id      = azurerm_subnet.db.id
  route_table_id = azurerm_route_table.udr.id
}
