# Bastion Module Outputs

output "instance_id" {
  description = "Bastion instance ID for SSM sessions"
  value       = aws_instance.bastion.id
}

output "security_group_id" {
  description = "Bastion security group ID"
  value       = aws_security_group.bastion.id
}

output "instance_arn" {
  description = "Bastion instance ARN"
  value       = aws_instance.bastion.arn
}
