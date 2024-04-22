terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.77.0"
    }
  }
}

provider "azurerm" {
  subscription_id = ""
  client_id = ""
  client_secret = ""
  tenant_id = ""
  features {
    
  }
}


locals {
  resource_group = "app-dozbyte"
  location = "westeurope" 
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "app_dozbyte" {
  name     = local.resource_group
  location = local.location   
}

resource "azurerm_virtual_network" "dozbyte_network" {
  name                = "dozbyte-network"
  location            = local.location
  resource_group_name = azurerm_resource_group.app_dozbyte.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]

  depends_on = [ azurerm_resource_group.app_dozbyte  ]

}

resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = azurerm_resource_group.app_dozbyte.name
  virtual_network_name = azurerm_virtual_network.dozbyte_network.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [ azurerm_virtual_network.dozbyte_network ]
}

resource "azurerm_network_interface" "dozbyte_interface" {
  name                = "dozbyte-interface"
  location            = azurerm_resource_group.app_dozbyte.location
  resource_group_name = azurerm_resource_group.app_dozbyte.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.dozbyte_public_ip.id
  }

  depends_on = [ 
    azurerm_virtual_network.dozbyte_network,
    azurerm_public_ip.dozbyte_public_ip,
    azurerm_subnet.SubnetA
  ]
}

resource "azurerm_windows_virtual_machine" "dozbyte_vm" {
  name                = "dozbyte-vm"
  resource_group_name = azurerm_resource_group.app_dozbyte.name
  location            = azurerm_resource_group.app_dozbyte.location
  size                = "Standard_D2s_v3"
  admin_username      = "dozbyte"
  admin_password      = azurerm_key_vault_secret.vmpassword.value
  network_interface_ids = [
    azurerm_network_interface.dozbyte_interface.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [ 
    azurerm_network_interface.dozbyte_interface,
    azurerm_key_vault_secret.vmpassword
     ]
}

resource "azurerm_public_ip" "dozbyte_public_ip" {
  name                = "dozbyte-public-ip"
  resource_group_name = azurerm_resource_group.app_dozbyte.name
  location            = azurerm_resource_group.app_dozbyte.location
  allocation_method   = "Static"

  depends_on = [ azurerm_resource_group.app_dozbyte ]

}

resource "azurerm_key_vault" "dozbyte_vault" {  
  name                        = "dozbytevault9087878"
  location                    = azurerm_resource_group.app_dozbyte.location
  resource_group_name         = azurerm_resource_group.app_dozbyte.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "Get",
    ]
    secret_permissions = [
      "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set",
    ]
    storage_permissions = [
      "Get",
    ]
  }
  depends_on = [
    azurerm_resource_group.app_dozbyte
  ]
}

# We are creating a secret in the key vault
resource "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmpassword"
  value        = "Pegasus1."
  key_vault_id = azurerm_key_vault.dozbyte_vault.id
  depends_on = [ azurerm_key_vault.dozbyte_vault ]
}