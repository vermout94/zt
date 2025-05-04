// --------------------------------------------------------------------------------
// Azure AD Group for Demo Users (e.g., advisor)
// --------------------------------------------------------------------------------

resource "azuread_group" "demo_users" {
  display_name     = "ZeroTrustDemo-Users"
  description      = "Demo users allowed to manage Zero Trust prototype resources."
  security_enabled = true
}

// --------------------------------------------------------------------------------
// Lookup Advisor User Object ID via Azure AD
// --------------------------------------------------------------------------------

data "azuread_user" "advisor" {
  user_principal_name = var.advisor_email_backup
}

data "azuread_user" "student" {
  user_principal_name = var.student_email
  
}

// --------------------------------------------------------------------------------
// RBAC Role Assignment to Resource Group
// --------------------------------------------------------------------------------

resource "azurerm_role_assignment" "demo_users_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_user.advisor.id
}

resource "azurerm_role_assignment" "student_vm_login" {
  scope                = azurerm_linux_virtual_machine.web_vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azuread_user.student.id
}
