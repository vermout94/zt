// Configure Terraform and Azure provider
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.70" // Use a recent 3.x provider version
    }
  }
}

provider "azurerm" {
  features {} // Enable AzureRM provider features (no special configuration needed)
}

// Note: Authenticate to Azure (e.g., via Azure CLI `az login` or environment credentials) 
// before running Terraform. Azure for Students accounts can be used without a credit card&#8203;:contentReference[oaicite:7]{index=7}.
