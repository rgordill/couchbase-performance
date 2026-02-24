provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = "couchbase-performance"
      Name    = var.vm_name
    }
  }
}
