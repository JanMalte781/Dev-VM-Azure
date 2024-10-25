terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "dev-rg" {
  name     = "dev-resources"
  location = "germanywestcentral"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "dev-network" {
  name                = "dev-network"
  resource_group_name = azurerm_resource_group.dev-rg.name
  location            = "germanywestcentral"
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "dev-subnet" {
  name                 = "dev-subnet"
  resource_group_name  = azurerm_resource_group.dev-rg.name
  virtual_network_name = azurerm_virtual_network.dev-network.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_network_security_group" "dev-sg" {
  name                = "dev-sg"
  location            = azurerm_resource_group.dev-rg.location
  resource_group_name = azurerm_resource_group.dev-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "dev-dev-allow" {
  name                        = "dev-dev-allow"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.dev-rg.name
  network_security_group_name = azurerm_network_security_group.dev-sg.name
}

resource "azurerm_subnet_network_security_group_association" "dev-sga" {
  subnet_id                 = azurerm_subnet.dev-subnet.id
  network_security_group_id = azurerm_network_security_group.dev-sg.id
}

resource "azurerm_public_ip" "dev-ip" {
  name                = "dev-ip"
  resource_group_name = azurerm_resource_group.dev-rg.name
  location            = azurerm_resource_group.dev-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "dev-nic" {
  name                = "dev-nic"
  location            = azurerm_resource_group.dev-rg.location
  resource_group_name = azurerm_resource_group.dev-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dev-ip.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "dev-vm" {
  name                  = "dev-vm"
  resource_group_name   = azurerm_resource_group.dev-rg.name
  location              = azurerm_resource_group.dev-rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.dev-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/dev_azure_key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/azure-dev-key"
    })
    interpreter = var.host_os != "windows" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "dev-ip-data" {
  name                = azurerm_public_ip.dev-ip.name
  resource_group_name = azurerm_resource_group.dev-rg.name
}