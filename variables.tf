// Input variables for flexibility and reuse
variable "location" {
  description = "Azure Region for all resources."
  type        = string
  default     = "northeurope" // used north europe as student account has limitations for certain modules
}

variable "resource_group_name" {
  description = "Name of the Resource Group to create."
  type        = string
  default     = "zero-trust-demo-rg"
}

variable "vnet_address_space" {
  description = "IP address space (CIDR) for the Virtual Network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "admin_username" {
  description = "Admin username for VM login."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the VM admin (for Linux SSH login)."
  type        = string
  // public SSH key stored in .tfvars file
}


variable "vm_size" {
  description = "VM size for the Linux virtual machines."
  type        = string
  default     = "Standard_B1s" // use a small size to minimize cost
}

variable "subscription_id" {
  description = "Azure Subscription ID for activity logs."
  type        = string
  // subscription ID stored in .tfvars file
}

variable "advisor_email" {
  description = "Email address of the advisor user for RBAC."
  type        = string
  // advisor email stored in .tfvars file
}
variable "advisor_email_backup" {
  description = "Backup email address of the advisor user for RBAC."
  type        = string
  // backup advisor email stored in .tfvars file
}
variable "email" {
  description = "Email address for alert notifications."
  type        = string
  // email address stored in .tfvars file
}
variable "student_email" {
  description = "Email address of the student user for RBAC."
  type        = string
  // student email stored in .tfvars file
}