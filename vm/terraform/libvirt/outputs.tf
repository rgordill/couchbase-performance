output "vm_name" {
  value       = var.vm_name
  description = "Name of the VM"
}

output "libvirt_domain_id" {
  value       = libvirt_domain.couchbase.id
  description = "Libvirt domain ID"
}

output "libvirt_domain_name" {
  value       = libvirt_domain.couchbase.name
  description = "Libvirt domain name"
}

output "ssh_user" {
  value       = "cloud-user"
  description = "SSH login user (libvirt)"
}

output "ssh_command" {
  value       = "virsh console ${var.vm_name}  # or: ssh cloud-user@<vm-ip>"
  description = "Example console or SSH command"
}
