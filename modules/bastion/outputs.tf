output "instance_id" {
  description = "ID of the bastion instance"
  value       = aws_instance.bastion.id
}

output "instance_arn" {
  description = "ARN of the bastion instance"
  value       = aws_instance.bastion.arn
}

output "private_ip" {
  description = "Private IP address of the bastion instance"
  value       = aws_instance.bastion.private_ip
}

output "public_ip" {
  description = "Public IP address of the bastion instance"
  value       = aws_instance.bastion.public_ip
}

output "elastic_ip" {
  description = "Elastic IP address (if enabled)"
  value       = var.enable_elastic_ip ? aws_eip.bastion[0].public_ip : null
}

output "security_group_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "key_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.bastion.key_name
}

output "private_key_pem" {
  description = "Private key in PEM format"
  value       = tls_private_key.bastion.private_key_pem
  sensitive   = true
}

output "public_key_openssh" {
  description = "Public key in OpenSSH format"
  value       = tls_private_key.bastion.public_key_openssh
}
