# Monthly AMI backup policy for long-term archival
resource "aws_dlm_lifecycle_policy" "monthly_ami" {
  description        = "Monthly AMI backups for compliance and long-term retention"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["INSTANCE"]
    policy_type    = "IMAGE_MANAGEMENT"

    target_tags = {
      BackupEnabled = "true"
      BackupPolicy  = "monthly"
    }

    schedule {
      name = "Monthly AMI Backup Schedule"

      create_rule {
        cron_expression = "cron(0 4 ${var.backup_schedules.monthly_day} * ? *)"
        # Runs at 4:00 AM UTC on the 1st of each month
      }

      retain_rule {
        count = var.retention_counts.monthly_count # Keep 12 monthly backups (1 year)
      }

      tags_to_add = {
        BackupType    = "MonthlyAMI"
        CreatedBy       = "DLM"
        BackupFrequency = "Monthly"
        Environment     = var.environment
        RetentionType   = "LongTerm"
        ManagedBy       = "Terraform"
      }

      deprecate_rule {

        count = 6

      }
      copy_tags = true


      dynamic "cross_region_copy_rule" {
        for_each = var.enable_cross_region_copy ? [1] : []

        content {
          target    = var.dr_region
          encrypted = true
          cmk_arn   = aws_kms_key.dlm_cross_region_copy.arn

          retain_rule {
            interval      = 90
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
      Name       = "${var.project_name}-${var.environment}-monthly-ami-policy"
      PolicyType = "AMI"
      Frequency  = "Monthly"
    }
  )

  depends_on = [aws_kms_key.dlm_primary_copy, aws_kms_key.dlm_cross_region_copy]
}