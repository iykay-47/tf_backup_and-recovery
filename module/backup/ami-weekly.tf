# Weekly AMI backup policy
resource "aws_dlm_lifecycle_policy" "weekly_ami" {
  description        = "Weekly AMI backups for long-term retention"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["INSTANCE"]
    policy_type    = "IMAGE_MANAGEMENT"

    target_tags = {
      BackupEnabled = "true"
      BackupPolicy  = "weekly"
    }

    schedule {
      name = "Weekly AMI Backup Schedule"

      create_rule {
        cron_expression = "cron(0 3 ? * ${var.backup_schedules.weekly_day} *)"
        # Runs at 3:00 AM UTC every Sunday
      }

      retain_rule {
        count = var.retention_counts.weekly_count # Keep 4 weekly backups
      }

      tags_to_add = {
        BackupType      = "WeeklyAMI"
        CreatedBy       = "DLM"
        BackupFrequency = "Weekly"
        Environment     = var.environment
        ManagedBy       = "Terraform"
      }

      copy_tags = true

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
      Name       = "${var.project_name}-${var.environment}-weekly-ami-policy"
      PolicyType = "AMI"
      Frequency  = "Weekly"
    }
  )

  depends_on = [aws_kms_key.dlm_primary_copy, aws_kms_key.dlm_cross_region_copy]
}
