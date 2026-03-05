# Azure Terraform (Couchbase VM)

Deploy a single Linux VM (RHEL 9) on Azure for Couchbase, with SSH and Couchbase ports (8091, 11210) open.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- Azure CLI logged in: `az login`
- SSH public key or admin password for VM login

## Usage

1. Copy or create a `terraform.tfvars` (or pass variables via `-var` / env):

   ```hcl
   vm_name         = "couchbase-vm"
   ssh_public_key  = file("~/.ssh/id_rsa.pub")
   azure_location  = "East US"
   azure_vm_size   = "Standard_B2s"   # 2 vCPU, 4 GiB RAM (Couchbase min)
   disk_gib        = 16
   ```

2. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. SSH to the VM (from outputs):

   ```bash
   ssh azureuser@$(terraform output -raw azure_public_ip)
   ```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `azure_location` | Azure region | `East US` |
| `azure_resource_group_name` | Resource group name | `""` (uses `vm_name-rg`) |
| `azure_vm_size` | VM size (e.g. Standard_B2s) | `Standard_B2s` |
| `azure_image` | publisher/offer/sku/version for RHEL | RHEL 9 LVM |
| `ssh_public_key` | SSH public key (recommended) | `""` |
| `admin_password` | Password for azureuser when no SSH key | `""` (sensitive) |
| `azure_subnet_id` | Existing subnet ID (optional) | `""` |
| `vm_name` | VM and resource name prefix | `couchbase-vm` |
| `disk_gib` | OS disk size (GiB) | `16` |

## Outputs

- `vm_name` – VM name
- `ssh_user` – `azureuser`
- `azure_vm_id` – Azure VM resource ID
- `azure_public_ip` – Public IP address
- `azure_resource_group` – Resource group name
- `ssh_command` – Example `ssh azureuser@<ip>`

## Notes

- When `ssh_public_key` is set, password authentication is disabled.
- When `ssh_public_key` is empty, set `admin_password` (e.g. via `TF_VAR_admin_password`) so you can log in.
- To use an existing subnet, set `azure_subnet_id`; otherwise a VNet and subnet are created.
