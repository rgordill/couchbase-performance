terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source  = "terraform-provider-libvirt/libvirt"
      version = "~> 0.7"
    }
  }
}
