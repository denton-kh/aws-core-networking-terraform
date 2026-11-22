output "bastion_instance_id" {
  description = "ID of Bastion EC2 instance"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP of Bastion Host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_security_group_id" {
  description = "Security Group ID of Bastion Host"
  value       = aws_security_group.bastion.id
}