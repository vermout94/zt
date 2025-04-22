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

// Define subnet IP prefixes (CIDRs) for each subnet in the VNet
locals {
  // Subnet IP ranges carved from 10.0.0.0/16 (adjust if vnet_address_space changes)
  subnet_prefixes = {
    AzureFirewallSubnet           = "10.0.0.0/26"  // Subnet for Azure Firewall (data traffic)
    AzureFirewallManagementSubnet = "10.0.0.64/26" // Subnet for Azure Firewall management (Basic SKU requirement)
    WebSubnet                     = "10.0.1.0/24"  // Subnet for Web server(s)
    DBSubnet                      = "10.0.2.0/24"  // Subnet for Database server(s)
  }
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.AzureFirewallSubnet]
  // No NSG on firewall subnet (not recommended to attach NSG to AzureFirewallSubnet)
}

resource "azurerm_subnet" "firewall_mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.AzureFirewallManagementSubnet]
  // No NSG on management subnet either.
}

resource "azurerm_subnet" "web" {
  name                 = "WebSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.WebSubnet]
  // Associate NSG via separate association resource below
}

resource "azurerm_subnet" "db" {
  name                 = "DBSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.subnet_prefixes.DBSubnet]
}

// --------------------------------------------------------------------------------
// Network Security Groups (NSGs) for Micro-Segmentation
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

// NSG Rules for Web subnet - allow HTTP/SSH from Internet (simulated external access via Firewall DNAT)
resource "azurerm_network_security_rule" "web_allow_http" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Allow-HTTP-In"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "*"  // ANY source (Internet) – in a real scenario, restrict to specific IPs&#8203;:contentReference[oaicite:9]{index=9}
  destination_address_prefix  = "*"  // to any IP in this subnet
  destination_port_range      = "80" // HTTP
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
  destination_port_range      = "22" // SSH
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}

// Note: The Web subnet NSG has permissive inbound rules (HTTP/SSH from any). In practice, 
// this should be paired with the Azure Firewall DNAT to limit true external exposure. 
// Azure Policy/ISO standards would flag broad "Any" inbound rules&#8203;:contentReference[oaicite:10]{index=10}, so consider 
// restricting source IPs. Here it's for demo purposes (simulating Internet access).

// NSG Rules for DB subnet - allow SQL traffic from Web subnet ONLY, deny all else
resource "azurerm_network_security_rule" "db_allow_sql" {
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "Allow-SQL-From-Web"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = local.subnet_prefixes.WebSubnet // only Web subnet as source
  destination_address_prefix  = "*"
  destination_port_range      = "3306" // Example: MariaDB port (or any app port that DB listens on)
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
  destination_port_range      = "*" // deny any other traffic from Web subnet
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
  source_address_prefix       = "*" // any source (including Internet or other subnets)
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_port_range           = "*"
  network_security_group_name = azurerm_network_security_group.db_nsg.name
}

// Attach the NSGs to the subnets
resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}
resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

// --------------------------------------------------------------------------------
// Azure Firewall (Basic SKU) and Public IPs
// --------------------------------------------------------------------------------
resource "azurerm_public_ip" "fw_public_ip" {
  name                = "AzureFirewall-PIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard" // Standard SKU PIP recommended for Firewall
}

resource "azurerm_public_ip" "fw_mgmt_public_ip" {
  name                = "AzureFirewallMgmt-PIP"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

// Create Azure Firewall (Basic SKU) in the hub VNet
resource "azurerm_firewall" "firewall" {
  name                = "ZeroTrustAzureFirewall"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku_name = "AZFW_VNet" // VNet deployment mode
  sku_tier = "Basic"     // Use Basic SKU for cost-efficiency&#8203;:contentReference[oaicite:11]{index=11}

  // Firewall IP configuration (data plane)
  ip_configuration {
    name                 = "fw-config"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw_public_ip.id
  }
  // Management IP configuration (required for Basic tier firewall)
  management_ip_configuration {
    name                 = "fw-mgmt-config"
    subnet_id            = azurerm_subnet.firewall_mgmt.id
    public_ip_address_id = azurerm_public_ip.fw_mgmt_public_ip.id
  }

  // (Optional) We could attach a Firewall Policy with rule collections, but for simplicity 
  // we will use classic rule settings below. Basic SKU supports rule collections via policy 
  // or classic rules.

  tags = { Environment = "Demo" }
}

// (Optional) Firewall rules: Here we illustrate a couple of rules via Firewall Policy and collections.
// In a real deployment, you'd define explicit allow/deny rules. For simplicity, we allow all outbound and 
// only the DNAT inbound rule (setup below). By default, Azure Firewall denies any traffic not allowed by rules.
resource "azurerm_firewall_network_rule_collection" "allow_all_outbound" {
  resource_group_name = azurerm_resource_group.rg.name
  azure_firewall_name = azurerm_firewall.firewall.name
  name                = "AllowAllOut"
  priority            = 100
  action              = "Allow"
  rule {
    name                  = "AllowAllOutRule"
    protocols             = ["Any"]
    source_addresses      = ["*"]
    destination_addresses = ["*"]
    destination_ports     = ["*"]
  }
}

// DNAT rule: Allow HTTP/SSH from Internet to the Web VM via Firewall's public IP
resource "azurerm_firewall_nat_rule_collection" "fw_dnat" {
  resource_group_name = azurerm_resource_group.rg.name
  azure_firewall_name = azurerm_firewall.firewall.name
  name                = "DNAT-Web"
  priority            = 110
  action              = "Dnat"

  rule {
    name                  = "DNAT-HTTP"
    source_addresses      = ["*"]                                       // any public source
    destination_addresses = [azurerm_public_ip.fw_public_ip.ip_address] // Firewall's public IP
    destination_ports     = ["80"]                                      // HTTP port on firewall
    protocols             = ["TCP"]
    translated_address    = azurerm_network_interface.web_nic.private_ip_address // web VM's private IP
    translated_port       = "80"                                                 // web VM HTTP port
  }
  rule {
    name                  = "DNAT-SSH"
    source_addresses      = ["*"]
    destination_addresses = [azurerm_public_ip.fw_public_ip.ip_address]
    destination_ports     = ["22"] // SSH port on firewall
    protocols             = ["TCP"]
    translated_address    = azurerm_network_interface.web_nic.private_ip_address
    translated_port       = "22" // web VM SSH port
  }
}

// Note: The Azure Firewall DNAT rules forward traffic from its public IP to the Web VM. 
// The web NSG must allow these ports (it does). We also route all outbound traffic from subnets to the firewall, ensuring 
// responses and egress go through the firewall (required for DNAT symmetry and for monitoring).

// --------------------------------------------------------------------------------
// User-Defined Route (UDR) - Force subnet traffic through Azure Firewall
// --------------------------------------------------------------------------------
resource "azurerm_route_table" "udr" {
  name                = "ZeroTrust-RouteTable"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  tags = { Purpose = "ForceTunnelToFirewall" }
}

// Default route: send ALL traffic (0.0.0.0/0) from attached subnets to the firewall's IP
resource "azurerm_route" "default_to_firewall" {
  name                   = "DefaultToFirewall"
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  route_table_name       = azurerm_route_table.udr.name
  resource_group_name    = azurerm_resource_group.rg.name
}

// Associate the route table with the Web and DB subnets (so all their traffic goes via firewall)
resource "azurerm_subnet_route_table_association" "web_udr_assoc" {
  subnet_id      = azurerm_subnet.web.id
  route_table_id = azurerm_route_table.udr.id
}
resource "azurerm_subnet_route_table_association" "db_udr_assoc" {
  subnet_id      = azurerm_subnet.db.id
  route_table_id = azurerm_route_table.udr.id
}

// --------------------------------------------------------------------------------
// Linux Virtual Machines (Web and DB) 
// --------------------------------------------------------------------------------
resource "azurerm_network_interface" "web_nic" {
  name                = "webvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "webvm-ipcfg"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    // No public IP on NIC – external access is via Firewall DNAT only.
  }

  // Note: NSG is associated at the subnet level for Web subnet.
}

resource "azurerm_network_interface" "db_nic" {
  name                = "dbvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "dbvm-ipcfg"
    subnet_id                     = azurerm_subnet.db.id
    private_ip_address_allocation = "Dynamic"
  }
  // NSG associated at subnet level for DB subnet.
}

// Create Web VM
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                  = "WebVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web_nic.id]

  // Disable password auth, use SSH key provided
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }
  disable_password_authentication = true

  os_disk {
    name                 = "webvm_os_disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  // Use the Ubuntu image from data source
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  // Enable system-assigned managed identity (for Azure AD login)
  identity {
    type = "SystemAssigned"
  }

  // Cloud-init script to install a web server (for testing HTTP access)
  custom_data = base64encode(<<-EOT
              #!/bin/bash
              apt-get update -y
              for i in {1..5}; do
                apt-get install -y nginx mariadb-client && break
                echo "Retrying apt install..."
                sleep 5
              done
              systemctl enable nginx
              systemctl start nginx

              cat << 'EOF' > /home/${var.admin_username}/test-zero-trust.sh
              #!/bin/bash
              echo "=== Zero Trust Test Plan: \$(date) ==="
              echo "[1] Testing local web server (NGINX)..."
              curl -s http://localhost | grep -i nginx && echo "NGINX is running." || echo "NGINX check failed."

              echo "[2] Testing ping to DB VM (10.0.2.4)..."
              ping -c 2 10.0.2.4 > /dev/null && echo "Ping reachable (unexpected)" || echo "Ping blocked (expected)."

              echo "[3] Testing MariaDB connectivity from Web → DB..."
              mysql -h 10.0.2.4 -u testuser -ptestpass -e "SHOW DATABASES;" && echo "MariaDB connection successful." || echo "MariaDB connection failed."

              echo "[4] Testing SSH from Web → DB VM (should be blocked)..."
              timeout 5 nc -zv 10.0.2.4 22 && echo "SSH to DB VM succeeded (unexpected)" || echo "SSH to DB VM blocked (expected)"

              echo "[5] Testing DNS resolution..."
              dig www.microsoft.com +short || echo "DNS resolution failed"
              echo "=== Test Plan Complete ==="
              EOF

              chmod +x /home/${var.admin_username}/test-zero-trust.sh
              chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/test-zero-trust.sh
              EOT
  )

  tags = { Role = "WebServer" }
}

resource "azurerm_linux_virtual_machine" "db_vm" {
  name                  = "DBVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.db_nic.id]
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }
  disable_password_authentication = true

  os_disk {
    name                 = "dbvm_os_disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  identity {
    type = "SystemAssigned"
  }
  custom_data = base64encode(<<-EOT
              #!/bin/bash
              apt-get update -y
              apt-get install -y mariadb-server
              systemctl enable mariadb
              systemctl start mariadb
              ufw disable
              sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
              systemctl restart mariadb
              mysql -e "CREATE USER 'testuser'@'%' IDENTIFIED BY 'testpass';"
              mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'testuser'@'%' WITH GRANT OPTION;"
              EOT
  )
  // (Optional) We could install a database or listener on port 1433 for testing; omitted for simplicity.
  tags = { Role = "DatabaseServer" }
}

// Azure AD Login extension for Linux VM (allows AAD authentication to VM)
resource "azurerm_virtual_machine_extension" "web_aad_login" {
  name                 = "AADLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.web_vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
  depends_on           = [azurerm_linux_virtual_machine.web_vm] // ensure VM identity is ready
}

// Grant Azure AD login role to the VM's managed identity (so that AAD users can actually login)
resource "azurerm_role_assignment" "web_vm_login_role" {
  scope                = azurerm_linux_virtual_machine.web_vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azurerm_linux_virtual_machine.web_vm.identity[0].principal_id
}
// Note: After deployment, add your Azure AD user to the VM via Azure RBAC if needed. 
// The above assignment uses the VM's own identity (not a user). Alternatively, assign this role to your user or group at the VM scope for interactive login.

// --------------------------------------------------------------------------------
// Logging & Monitoring: Log Analytics and Diagnostic Settings
// --------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "ZeroTrust-LogAnalytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018" // Pay-as-you-go tier (suitable for low-volume demo; free tier could be used as well)
  retention_in_days   = 30          // Retain logs for 30 days (adjustable as needed)

  tags = { Purpose = "SecurityLogs" }
}

// Enable diagnostic logging for Azure Firewall to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "fw_diagnostics" {
  name                       = "FirewallDiagnostics"
  target_resource_id         = azurerm_firewall.firewall.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  // Log categories for Azure Firewall: Application, Network, and DNS proxy logs&#8203;:contentReference[oaicite:12]{index=12}
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
    category = "AllMetrics" // All metrics for Azure Firewall
  }
}

// Enable diagnostic logging for NSGs (Web and DB) to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "web_nsg_diagnostics" {
  name                       = "NSGDiagnostics-Web"
  target_resource_id         = azurerm_network_security_group.web_nsg.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id

  enabled_log {
    category = "NetworkSecurityGroupEvent" // logs for denied/allowed events
  }
  enabled_log {
    category = "NetworkSecurityGroupRuleCounter" // statistics for rule hits
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

// At this point, Azure Firewall and NSG logs will flow into Log Analytics. 
// These logs can be queried to verify Zero Trust policies (e.g., see blocked traffic attempts). 
// This supports auditing for compliance (GDPR requires monitoring access attempts, and ISO/IEC 27001 A.12/A.13 mandates logging of security events).
