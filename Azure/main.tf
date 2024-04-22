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


resource "azurerm_resource_group" "app_dozbyte" {
  name     = local.resource_group
  location = local.location   
}


resource "azurerm_virtual_network" "dozbyte_network" {
  name                = "dozbyte-network"
  location            = azurerm_resource_group.app_dozbyte.location
  resource_group_name = azurerm_resource_group.app_dozbyte.name
  address_space       = ["10.0.0.0/16"]  
  depends_on = [
    azurerm_resource_group.app_dozbyte
  ]
}

resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = azurerm_resource_group.app_dozbyte.name
  virtual_network_name = azurerm_virtual_network.dozbyte_network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [
    azurerm_virtual_network.dozbyte_network
  ]
}

// This subnet is meant for the Azure Bastion service
resource "azurerm_subnet" "Azure_Bastion_Subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.app_dozbyte.name
  virtual_network_name = azurerm_virtual_network.dozbyte_network.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on = [
    azurerm_virtual_network.dozbyte_network
  ]
}

resource "azurerm_network_interface" "dozbyte_interface" {
  name                = "dozbyte-interface"
  location            = azurerm_resource_group.app_dozbyte.location
  resource_group_name = azurerm_resource_group.app_dozbyte.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_virtual_network.dozbyte_network,
    azurerm_subnet.SubnetA
  ]
}

resource "azurerm_windows_virtual_machine" "dozbyte_vm" {
  name                = "dozbyte-vm"
  resource_group_name = azurerm_resource_group.app_dozbyte.name
  location            = azurerm_resource_group.app_dozbyte.location
  size                = "Standard_D2s_v3"
  admin_username      = ""
  admin_password      = ""  
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
    azurerm_network_interface.dozbyte_interface
  ]
}



resource "azurerm_network_security_group" "dozbyte_nsg" {
  name                = "dozbyte-nsg"
  location            = azurerm_resource_group.app_dozbyte.location
  resource_group_name = azurerm_resource_group.app_dozbyte.name

# We are creating a rule to allow traffic on port 3389
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.dozbyte_nsg.id
  depends_on = [
    azurerm_network_security_group.dozbyte_nsg
  ]
}

resource "azurerm_public_ip" "bastion_ip" {
  name                = "bastion-ip"
  location            = azurerm_resource_group.app_dozbyte.location
  resource_group_name = azurerm_resource_group.app_dozbyte.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "app_bastion" {
  name                = "app-bastion"
  location            = azurerm_resource_group.app_dozbyte.location
  resource_group_name = azurerm_resource_group.app_dozbyte.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.Azure_Bastion_Subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }

  depends_on=[
    azurerm_subnet.Azure_Bastion_Subnet,
    azurerm_public_ip.bastion_ip
  ]
}