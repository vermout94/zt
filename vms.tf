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

  custom_data = base64encode(local.webvm_cloudinit)
  tags        = { Role = "WebServer" }
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

  custom_data = base64encode(local.dbvm_cloudinit)
  tags        = { Role = "DBServer" }
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
resource "azurerm_virtual_machine_extension" "db_aad_login" {
  name                 = "AADLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.db_vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
  depends_on           = [azurerm_linux_virtual_machine.db_vm]
}


resource "azurerm_role_assignment" "web_vm_login_role" {
  scope                = azurerm_linux_virtual_machine.web_vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azurerm_linux_virtual_machine.web_vm.identity[0].principal_id
}

resource "azurerm_role_assignment" "webvm_aad_login" {
  scope                = azurerm_linux_virtual_machine.web_vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azuread_user.advisor.id
}

resource "azurerm_role_assignment" "dbvm_aad_login" {
  scope                = azurerm_linux_virtual_machine.db_vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azuread_user.advisor.id
}
resource "azurerm_role_assignment" "db_vm_login_role" {
  scope                = azurerm_linux_virtual_machine.db_vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azurerm_linux_virtual_machine.db_vm.identity[0].principal_id
}