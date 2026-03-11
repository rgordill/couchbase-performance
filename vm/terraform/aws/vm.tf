# -----------------------------------------------------------------------------
# AWS: EC2 instance (RHEL 10.1 AMI in us-east-2)
# SSH user: ec2-user (key from vault ~/.ssh/id_rsa.pub via key pair or aws_key_name)
# -----------------------------------------------------------------------------
resource "aws_key_pair" "couchbase" {
  count = var.ssh_public_key != "" ? 1 : 0

  key_name   = "${var.vm_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "couchbase" {
  ami                    = var.aws_ami_id
  instance_type          = var.aws_instance_type
  key_name               = var.ssh_public_key != "" ? aws_key_pair.couchbase[0].key_name : (var.aws_key_name != "" ? var.aws_key_name : null)
  subnet_id              = var.aws_subnet_id != "" ? var.aws_subnet_id : tolist(data.aws_subnets.default[0].ids)[0]
  vpc_security_group_ids = [aws_security_group.couchbase.id]

  root_block_device {
    volume_size           = var.disk_gib
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = var.vm_name
  }
}
