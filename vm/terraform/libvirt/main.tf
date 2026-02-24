# -----------------------------------------------------------------------------
# Libvirt: RHEL 10.1 VM (Couchbase minimum production: 2 vCPU, 4 GiB RAM, 8+ GiB)
# SSH user: cloud-user (key from vault ~/.ssh/id_rsa.pub via cloud-init)
# -----------------------------------------------------------------------------
locals {
  libvirt_source = length(regexall("/", var.libvirt_base_image)) > 0 ? "file://${var.libvirt_base_image}" : "file:///var/lib/libvirt/images/${var.libvirt_base_image}"
}

resource "libvirt_volume" "base" {
  name   = "${var.vm_name}-base.qcow2"
  pool   = var.libvirt_pool
  source = local.libvirt_source
  format = "qcow2"
}

resource "libvirt_volume" "disk" {
  name           = "${var.vm_name}.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_gib * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "couchbase" {
  count = var.ssh_public_key != "" ? 1 : 0

  name = "${var.vm_name}-cloudinit.iso"
  pool = var.libvirt_pool

  user_data = <<-EOF
    #cloud-config
    users:
      - name: cloud-user
        gecos: Cloud User
        groups: [wheel]
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ${replace(var.ssh_public_key, "\n", "")}
    EOF

  meta_data = <<-EOF
    instance-id: ${var.vm_name}
    local-hostname: ${var.vm_name}
  EOF
}

resource "libvirt_domain" "couchbase" {
  name   = var.vm_name
  memory = var.memory_mib
  vcpu   = var.vcpu

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.disk.id
  }

  dynamic "disk" {
    for_each = var.ssh_public_key != "" ? [1] : []
    content {
      volume_id = libvirt_cloudinit_disk.couchbase[0].id
    }
  }

  network_interface {
    network_name = var.libvirt_network_name
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
