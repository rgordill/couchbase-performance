# --- AWS ---
variable "aws_region" {
  type        = string
  description = "AWS region (AMI ami-0886072325c42ee75 is in us-east-2)"
  default     = "us-east-2"
}

variable "aws_ami_id" {
  type        = string
  description = "RHEL 10.1 AMI ID in the selected region"
  default     = "ami-0886072325c42ee75"
}

variable "aws_instance_type" {
  type        = string
  description = "EC2 instance type (Couchbase min production: 2 vCPU, 4 GiB RAM)"
  default     = "t3.medium"
}

# SSH public key content (e.g. from Ansible vault: provisioner host ~/.ssh/id_rsa.pub). When set, an EC2 key pair is created for ec2-user.
variable "ssh_public_key" {
  type        = string
  description = "SSH public key content (from vault / ~/.ssh/id_rsa.pub on provisioner); creates EC2 key pair when set"
  default     = ""
}

variable "aws_key_name" {
  type        = string
  description = "Existing EC2 key pair name (used only when ssh_public_key is not set)"
  default     = ""
}

variable "aws_subnet_id" {
  type        = string
  description = "VPC subnet ID for the instance (optional; uses default VPC if not set)"
  default     = ""
}

# --- Couchbase minimum production (pre-install docs) ---
variable "vm_name" {
  type        = string
  description = "Name of the instance"
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
