# -----------------------------------------------------------------------------
# AWS: networking (VPC, subnets, security group)
# -----------------------------------------------------------------------------
data "aws_vpc" "default" {
  count = var.aws_subnet_id == "" ? 1 : 0

  default = true
}

data "aws_subnets" "default" {
  count = var.aws_subnet_id == "" ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

resource "aws_security_group" "couchbase" {
  name        = "${var.vm_name}-sg"
  description = "SSH and Couchbase ports for ${var.vm_name}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 8091
    to_port     = 8091
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Couchbase Admin UI"
  }

  ingress {
    from_port   = 11210
    to_port     = 11210
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Couchbase memcached"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
