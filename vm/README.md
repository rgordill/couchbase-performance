# Couchbase VM (Libvirt or AWS)

Terraform plan that provisions a single VM for Couchbase Server on **libvirt** (KVM) or **AWS**, using RHEL 10.1 and [Couchbase minimum production](https://docs.couchbase.com/server/current/install/pre-install.html) sizing (2 vCPU, 4 GiB RAM, 8+ GiB storage).

- **Terraform** is split into two projects under `vm/terraform/`: **libvirt/** (KVM) and **aws/** (AWS). Each has its own provider, variables, and state.
- **Ansible** assets all live under `vm/ansible/`: inventory, playbooks, roles, group_vars, ansible.cfg, requirements.yml, and the role that drives Terraform (it uses `backend` to run either `vm/terraform/libvirt` or `vm/terraform/aws`).

## Images

| Backend | Image |
|--------|--------|
| **Libvirt** | `rhel-10.1-x86_64-kvm.qcow2` (path: `/var/lib/libvirt/images/rhel-10.1-x86_64-kvm.qcow2` or set `libvirt_base_image`) |
| **AWS** | `ami-0886072325c42ee75` in **us-east-2** |

## Layout

```
vm/
├── terraform/                 # Two Terraform projects (one per provider)
│   ├── README.md
│   ├── libvirt/               # Libvirt (KVM) only
│   │   ├── main.tf, variables.tf, outputs.tf, providers.tf, versions.tf
│   │   └── terraform.tfvars.example
│   └── aws/                   # AWS only
│       ├── main.tf, variables.tf, outputs.tf, providers.tf, versions.tf
│       └── terraform.tfvars.example
├── ansible/                   # All Ansible assets (inventory, playbooks, roles, group_vars, etc.)
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/
│   │   └── hosts.yml
│   ├── group_vars/
│   │   ├── all.yml
│   │   └── vault.yml.template
│   ├── playbooks/
│   │   └── deploy.yml
│   └── roles/
│       └── vm_provision/
└── README.md
```

## Quick start

### Option A: Ansible (recommended)

Terraform is driven by Ansible using the `cloud.terraform` collection (no Jinja2 templates; variables passed via the module).

1. **Install collection and run:**

   ```bash
   cd vm/ansible
   ansible-galaxy collection install -r requirements.yml
   ansible-playbook playbooks/deploy.yml
   ```

2. **Override backend or vars** (e.g. AWS + key name):

   ```bash
   ansible-playbook playbooks/deploy.yml -e "backend=aws" -e "aws_key_name=my-key"
   ```

3. **SSH key (vault):** set **`vault_ssh_public_key`** in `group_vars/vault.yml` to the **content of the provisioner host’s** `~/.ssh/id_rsa.pub`. Ansible passes it to Terraform; libvirt injects it for **cloud-user**, AWS creates a key pair for **ec2-user**. Run with `--ask-vault-pass` (or use vault from `vault.yml.template`).

Playbook runs on `localhost`; Terraform project path is `vm/terraform/<backend>` (e.g. `vm/terraform/libvirt` or `vm/terraform/aws`). Outputs are printed after apply.

**VM SSH users:** **cloud-user** (libvirt), **ec2-user** (AWS).

### Option B: Terraform CLI

Use **either** `vm/terraform/libvirt` **or** `vm/terraform/aws` (separate state per provider).

**Libvirt:**

- Place `rhel-10.1-x86_64-kvm.qcow2` in the default pool (e.g. `/var/lib/libvirt/images/`) or set `libvirt_base_image` in tfvars.
- Ensure libvirt default pool and network exist.

  ```bash
  cd vm/terraform/libvirt
  terraform init
  terraform plan && terraform apply
  ```

**AWS:**

- Set `aws_key_name` to an existing EC2 key pair in us-east-2. Optionally set `aws_subnet_id`; otherwise the default VPC is used.

  ```bash
  cd vm/terraform/aws
  terraform init
  terraform plan && terraform apply
  ```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `backend` | `"libvirt"` | `libvirt` or `aws` |
| `libvirt_base_image` | `rhel-10.1-x86_64-kvm.qcow2` | Path or filename of RHEL 10.1 qcow2 |
| `libvirt_pool` | `default` | Libvirt storage pool name |
| `aws_region` | `us-east-2` | AWS region (AMI is in us-east-2) |
| `aws_ami_id` | `ami-0886072325c42ee75` | RHEL 10.1 AMI ID |
| `aws_instance_type` | `t3.medium` | 2 vCPU, 4 GiB (Couchbase min production) |
| `aws_key_name` | `""` | EC2 key pair name (required for SSH) |
| `vm_name` | `couchbase-vm` | VM/instance name |
| `vcpu` | `2` | vCPUs |
| `memory_mib` | `4096` | RAM (MiB) |
| `disk_gib` | `16` | Root disk (GiB) |

## Install Couchbase Server on RHEL (VM)

After the VM is up, install Couchbase Server on RHEL as per [Install on Red Hat, Oracle Linux, or Amazon Linux](https://docs.couchbase.com/server/current/install/rhel-suse-install-intro.html):

1. **Add Couchbase repo and install (root or sudo):**

   ```bash
   curl -O https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0.noarch.rpm
   sudo rpm -i ./couchbase-release-1.0.noarch.rpm
   sudo dnf install couchbase-server
   ```

2. **Process limits (recommended):** create `/etc/security/limits.d/91-couchbase.conf`:

   ```bash
   couchbase soft nproc 4096
   couchbase hard nproc 16384
   ```

3. **Open Web Console:** `http://<vm-ip>:8091` and complete cluster setup.

## Outputs

- **Libvirt:** `libvirt_domain_id`, `libvirt_domain_name`, `ssh_command` (e.g. `virsh console couchbase-vm`).
- **AWS:** `aws_instance_id`, `aws_public_ip`, `aws_public_dns`, `ssh_command` (e.g. `ssh ec2-user@<public_ip>`).
