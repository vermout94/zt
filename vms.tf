// --------------------------------------------------------------------------------
// Network Interfaces
// --------------------------------------------------------------------------------
resource "azurerm_network_interface" "web_nic" {
  name                = "webvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "webvm-ipcfg"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }
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
}

// --------------------------------------------------------------------------------
// Linux Virtual Machines (Web and DB)
// --------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                  = "WebVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web_nic.id]

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

  tags = { Role = "DatabaseServer" }
}

// --------------------------------------------------------------------------------
// Azure AD Login Extension
// --------------------------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "web_aad_login" {
  name                 = "AADLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.web_vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
  depends_on           = [azurerm_linux_virtual_machine.web_vm]
}

resource "azurerm_role_assignment" "web_vm_login_role" {
  scope                = azurerm_linux_virtual_machine.web_vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azurerm_linux_virtual_machine.web_vm.identity[0].principal_id
}
