# Configure backend
terraform {
  backend "azurerm" {}
}

# Configure the Azure Provider
provider "azurerm" {
  version = "=2.14.0"
  features {}
}

data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}
