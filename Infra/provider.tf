terraform {
  required_providers {
    azurerm = {
        source ="hashicorp/azurerm"
        version = ">=4.6.0"
    }
  }
  required_version = ">=1.14.5"
}
provider "azurerm" {
    subscription_id = "8eae94cc-2eea-4ec3-a98e-6fdae439c162"
    features {
      key_vault {
      purge_soft_delete_on_destroy = true
    }
    }
  
}