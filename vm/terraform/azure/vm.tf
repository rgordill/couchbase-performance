# -----------------------------------------------------------------------------
# Azure: Linux VM (RHEL 9) for Couchbase
# SSH user: azureuser (when using SSH key)
# -----------------------------------------------------------------------------

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
