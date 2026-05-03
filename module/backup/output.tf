# Output policy ID for reference
output "daily_ami_policy_id" {
  description = "ID of daily AMI lifecycle policy"
  value       = aws_dlm_lifecycle_policy.daily_ami.id
}

output "weekly_ami_policy_id" {
  description = "ID of Weekly AMI lifecycle policy"
  value       = aws_dlm_lifecycle_policy.weekly_ami.id
}

output "monthly_ami_policy_id" {
  description = "ID of Monthly AMI lifecycle policy"
  value       = aws_dlm_lifecycle_policy.monthly_ami.id
}

output "critical_ami_policy_id" {
  description = "ID of Critical AMI lifecycle policy"
  value       = aws_dlm_lifecycle_policy.critical_ami.id
}

output "daily_snapshot_policy_id" {
  description = "ID of daily snapshot policy"
  value       = aws_dlm_lifecycle_policy.daily_snapshots.id
}

output "kms_arn" {
  description = "Primary Region KMS arn"
  value       = aws_kms_key.dlm_primary_copy.arn
}

output "dr_kms_arn" {
  description = "Disaster Recovery region KMS arn"
  value       = aws_kms_key.dlm_cross_region_copy.arn
}