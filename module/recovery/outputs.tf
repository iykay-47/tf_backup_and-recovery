output "launch_template_ids" {
  description = "Map of instance names to launch template IDs"
  value       = { for k, v in aws_launch_template.dr_recovery : k => v.id }
}

output "launch_template_latest_versions" {
  description = "Latest versions of launch templates"
  value       = { for k, v in aws_launch_template.dr_recovery : k => v.latest_version }
}

output "vpc_id" {
  description = "DR VPC ID"
  value       = aws_vpc.dr.id
}

output "public_subnet_ids" {
  description = "DR public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "DR private subnet IDs"
  value       = [for s in aws_subnet.private : s.id]
}

output "security_group_id" {
  description = "DR security group ID"
  value       = aws_security_group.dr_instances.id
}