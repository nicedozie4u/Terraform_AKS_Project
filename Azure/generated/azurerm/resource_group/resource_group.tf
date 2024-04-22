resource "azurerm_resource_group" "tfer--DozbyteNet" {
  location = "eastus"
  name     = "DozbyteNet"
}

resource "azurerm_resource_group" "tfer--NetworkWatcherRG" {
  location = "eastus"
  name     = "NetworkWatcherRG"
}

resource "azurerm_resource_group" "tfer--cloud-shell-storage-westeurope" {
  location = "westeurope"
  name     = "cloud-shell-storage-westeurope"
}
