# --- Libvirt ---
variable "libvirt_uri" {
  type        = string
  description = "Libvirt connection URI (e.g. qemu:///system)"
  default     = "qemu:///system"
}

variable "libvirt_base_image" {
  type        = string
  description = "Path or URL to RHEL 10.1 KVM qcow2 image"
  default     = "rhel-10.1-x86_64-kvm.qcow2"
}

variable "libvirt_pool" {
  type        = string
  description = "Libvirt pool name for volumes"
  default     = "default"
}

variable "libvirt_network_name" {
  type        = string
  description = "Libvirt network name for the VM"
  default     = "default"
}

# --- Couchbase minimum production (pre-install docs) ---
variable "vm_name" {
  type        = string
  description = "Name of the VM"
  default     = "couchbase-vm"
}

variable "vcpu" {
  type        = number
  description = "Number of vCPUs (Couchbase min production: 2)"
  default     = 2
}

variable "memory_mib" {
  type        = number
  description = "Memory in MiB (Couchbase min production: 4096)"
  default     = 4096
}

variable "disk_gib" {
  type        = number
  description = "Root disk size in GiB (Couchbase min: 8; use 16+ for OS + data)"
  default     = 16
}

# SSH public key content (e.g. from Ansible vault: provisioner host ~/.ssh/id_rsa.pub). Injected for cloud-user via cloud-init.
variable "ssh_public_key" {
  type        = string
  description = "SSH public key content for cloud-user (from vault / ~/.ssh/id_rsa.pub on provisioner)"
  default     = ""
}
