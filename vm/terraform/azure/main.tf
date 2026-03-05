# -----------------------------------------------------------------------------
# Azure: Linux VM (RHEL 9) for Couchbase
# SSH user: azureuser (when using SSH key)
# -----------------------------------------------------------------------------

locals {
  rg_name = var.azure_resource_group_name != "" ? var.azure_resource_group_name : "${var.vm_name}-rg"
}

resource "azurerm_resource_group" "couchbase" {
  name     = local.rg_name
  location = var.azure_location

  tags = {
    Project = "couchbase-performance"
    Name    = var.vm_name
  }
}

# VNet and subnet when not using an existing subnet
resource "azurerm_virtual_network" "couchbase" {
  count = var.azure_subnet_id == "" ? 1 : 0

  name                = "${var.vm_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.couchbase.location
  resource_group_name = azurerm_resource_group.couchbase.name

  tags = {
    Project = "couchbase-performance"
    Name    = var.vm_name
  }
}

resource "azurerm_subnet" "couchbase" {
  count = var.azure_subnet_id == "" ? 1 : 0

  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.couchbase.name
  virtual_network_name = azurerm_virtual_network.couchbase[0].name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network security group: SSH and Couchbase ports
resource "azurerm_network_security_group" "couchbase" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.couchbase.location
  resource_group_name = azurerm_resource_group.couchbase.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "CouchbaseAdmin"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8091"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "CouchbaseMemcached"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "11210"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  tags = {
    Project = "couchbase-performance"
    Name    = var.vm_name
  }
}

# Public IP for the VM
resource "azurerm_public_ip" "couchbase" {
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.couchbase.location
  resource_group_name = azurerm_resource_group.couchbase.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Project = "couchbase-performance"
    Name    = var.vm_name
  }
}

# Subnet ID: use provided or the one we created
locals {
  subnet_id = var.azure_subnet_id != "" ? var.azure_subnet_id : azurerm_subnet.couchbase[0].id
}

resource "azurerm_network_interface" "couchbase" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.couchbase.location
  resource_group_name = azurerm_resource_group.couchbase.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.couchbase.id
  }

  tags = {
    Project = "couchbase-performance"
    Name    = var.vm_name
  }
}

resource "azurerm_network_interface_security_group_association" "couchbase" {
  network_interface_id      = azurerm_network_interface.couchbase.id
  network_security_group_id = azurerm_network_security_group.couchbase.id
}

resource "azurerm_linux_virtual_machine" "couchbase" {
  name                = var.vm_name
  location            = azurerm_resource_group.couchbase.location
  resource_group_name = azurerm_resource_group.couchbase.name
  size                = var.azure_vm_size
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.couchbase.id,
  ]

  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key != "" ? [1] : []
    content {
      username   = "azureuser"
      public_key = var.ssh_public_key
    }
  }

  disable_password_authentication = var.ssh_public_key != ""
  admin_password                  = var.ssh_public_key == "" ? var.admin_password : null

  source_image_reference {
    publisher = var.azure_image.publisher
    offer     = var.azure_image.offer
    sku       = var.azure_image.sku
    version   = var.azure_image.version
  }

  os_disk {
    name                 = "${var.vm_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_gib
  }

  tags = {
    Project = "couchbase-performance"
    Name    = var.vm_name
  }
}
