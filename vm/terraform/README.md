# Terraform: Libvirt and AWS

Terraform is split into two separate projects, one per provider:

| Folder      | Provider | Use when |
|------------|----------|----------|
| **libvirt/** | Libvirt (KVM) | Running the VM on a local or remote KVM host |
| **aws/**     | AWS            | Running the instance in AWS (e.g. us-east-2) |

Each folder has its own state and variables. Run `terraform init` and `terraform apply` inside the folder you need.

## Libvirt

```bash
cd vm/terraform/libvirt
terraform init
terraform plan
terraform apply
```

Variables: `vm_name`, `vcpu`, `memory_mib`, `disk_gib`, `libvirt_uri`, `libvirt_base_image`, `libvirt_pool`, `libvirt_network_name`.

## AWS

```bash
cd vm/terraform/aws
terraform init
terraform plan
terraform apply
```

Variables: `vm_name`, `vcpu`, `memory_mib`, `disk_gib`, `aws_region`, `aws_ami_id`, `aws_instance_type`, `aws_key_name`, `aws_subnet_id`.

Set `aws_key_name` for SSH access. Optionally set `aws_subnet_id`; otherwise the default VPC is used.

## Ansible

When using Ansible (`vm/ansible/playbooks/deploy.yml`), the playbook uses the value of `backend` (`libvirt` or `aws`) to run Terraform in the corresponding folder: `vm/terraform/libvirt` or `vm/terraform/aws`.
