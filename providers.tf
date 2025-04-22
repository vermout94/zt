// Configure required providers (AzureRM and AzAPI) and define provider instances
terraform {
  required_version = ">=1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.107.0" // Use AzureRM provider 3.107.0 or later (no legacy azurermv2)
    }
    azapi = {
      source  = "azure/azapi"
      version = ">=1.13.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias = "management"
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias = "connectivity"
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azapi" {
  # AzAPI uses same Azure credentials (subscription/tenant) as provided above
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
