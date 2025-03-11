terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.15.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "c064671c-8f74-4fec-b088-b53c568245eb"
}

# Use existing resource group
data "azurerm_resource_group" "rg" {
  name = "fe2157786"
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vm-network"
  address_space       = ["10.0.0.0/16"]
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                = "vm-public-ip"
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "nsg" {
  name                = "vm-nsg"
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Read SSH public key
data "local_file" "ssh_public_key" {
  filename = pathexpand("~/.ssh/azure_macbookpro.pub")
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "azure-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = "westeurope"
  size                = "Standard_B2ats_v2"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.local_file.ssh_public_key.content
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-noble"
    sku       = "24_04-lts"
    version   = "latest"
  }
}

# Output public IP address
output "public_ip_address" {
  value = azurerm_public_ip.publicip.ip_address
}

