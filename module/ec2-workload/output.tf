output "instance_ids" {
  description = "Map of instance names to IDs"
  value       = { for k, v in aws_instance.workload : k => v.id }
}

output "instance_arns" {
  description = "Map of instance names to ARNs"
  value       = { for k, v in aws_instance.workload : k => v.arn }
}

output "volume_ids" {
  description = "Map of volume keys to IDs"
  value       = { for k, v in aws_ebs_volume.additional : k => v.id }
}

output "security_group_id" {
  description = "Security group ID for instances"
  value       = aws_security_group.public_instances.id
}

output "instance_details" {
  description = "Detailed instance information"
  value = {
    for k, v in aws_instance.workload : k => {
      id            = v.id
      private_ip    = v.private_ip
      az            = v.availability_zone
      backup_policy = v.tags["BackupPolicy"]
      public_ip     = v.public_ip
    }
  }
}

output "public_ips" {
  description = "Map of instance names to Public_ips"
  value       = { for k, v in aws_instance.workload : k => v.public_ip }
}