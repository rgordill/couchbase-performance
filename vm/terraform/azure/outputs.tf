output "vm_name" {
  value       = var.vm_name
  description = "Name of the VM"
}

output "ssh_user" {
  value       = "azureuser"
  description = "SSH login user (Azure RHEL)"
}

output "azure_vm_id" {
  value       = azurerm_linux_virtual_machine.couchbase.id
  description = "Azure VM resource ID"
}

output "azure_public_ip" {
  value       = azurerm_public_ip.couchbase.ip_address
  description = "VM public IP address"
}

output "azure_resource_group" {
  value       = azurerm_resource_group.couchbase.name
  description = "Resource group name"
}

output "ssh_command" {
  value       = "ssh azureuser@${azurerm_public_ip.couchbase.ip_address}"
  description = "Example SSH command (user: azureuser)"
}
