# Daily AMI backup policy for daily-tagged instances

resource "aws_dlm_lifecycle_policy" "daily_ami" {
  description        = "Daily AMI backups for production instances"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["INSTANCE"]
    policy_type    = "IMAGE_MANAGEMENT"

    target_tags = {
      BackupEnabled = "true"
      BackupPolicy  = "daily"
    }

    schedule {
      name = "Daily AMI Backup Schedule"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.backup_schedules.daily_time]
      }

      retain_rule {
        count = var.retention_counts.daily_count # Keep 7 daily backups
      }

      tags_to_add = {
        BackupType    = "DailyAMI"
        CreatedBy       = "DLM"
        BackupFrequency = "Daily"
        Environment     = var.environment
        ManagedBy       = "Terraform"
      }

      copy_tags = true # Copy instance tags to AMI

      dynamic "cross_region_copy_rule" {
        for_each = var.enable_cross_region_copy ? [1] : []

        content {
          target    = var.dr_region
          encrypted = true
          cmk_arn   = aws_kms_key.dlm_cross_region_copy.arn

          retain_rule {
            interval      = var.retention_counts.dr_retention_days
            interval_unit = "DAYS"
          }

          copy_tags = true
        }
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name       = "${var.project_name}-${var.environment}-daily-ami-policy"
      PolicyType = "AMI"
      Frequency  = "Daily"
    }
  )

  depends_on = [aws_kms_key.dlm_primary_copy, aws_kms_key.dlm_cross_region_copy]
}