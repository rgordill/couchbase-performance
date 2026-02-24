output "vm_name" {
  value       = var.vm_name
  description = "Name of the instance"
}

output "ssh_user" {
  value       = "ec2-user"
  description = "SSH login user (AWS RHEL)"
}

output "aws_instance_id" {
  value       = aws_instance.couchbase.id
  description = "EC2 instance ID"
}

output "aws_public_ip" {
  value       = aws_instance.couchbase.public_ip
  description = "EC2 public IP address"
}

output "aws_public_dns" {
  value       = aws_instance.couchbase.public_dns
  description = "EC2 public DNS name"
}

output "ssh_command" {
  value       = "ssh ec2-user@${aws_instance.couchbase.public_ip}"
  description = "Example SSH command (user: ec2-user)"
}
