// Configure Terraform and Azure provider
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.70"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.45"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}