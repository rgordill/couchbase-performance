# --- Azure ---
variable "azure_location" {
  type        = string
  description = "Azure region (e.g. East US, West Europe)"
  default     = "East US"
}

variable "azure_resource_group_name" {
  type        = string
  description = "Name of the resource group (created if not set; defaults to vm_name + '-rg')"
  default     = ""
}

variable "azure_vm_size" {
  type        = string
  description = "VM size (Couchbase min production: 2 vCPU, 4 GiB RAM; e.g. Standard_B2s)"
  default     = "Standard_B2s"
}

variable "azure_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "Azure Marketplace image for the VM (default: RHEL 9)"
  default = {
    publisher = "RedHat"
    offer     = "rhel"
    sku       = "9-lvm"
    version   = "latest"
  }
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key content (e.g. from Ansible vault: provisioner host ~/.ssh/id_rsa.pub). When set, password auth is disabled."
  default     = ""
}

variable "admin_password" {
  type        = string
  description = "Admin password for azureuser (used only when ssh_public_key is not set; avoid in production)"
  default     = ""
  sensitive   = true
}

variable "azure_subnet_id" {
  type        = string
  description = "Existing subnet ID (optional; a VNet and subnet are created if not set)"
  default     = ""
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
  description = "OS disk size in GiB (Couchbase min: 8; use 16+ for OS + data)"
  default     = 16
}
