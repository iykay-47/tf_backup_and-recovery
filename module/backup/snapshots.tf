# Daily Snap config

resource "aws_dlm_lifecycle_policy" "daily_snapshots" {
  description        = "Daily Snapshot DLM lifecycle policy"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "3 weeks of daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["01:30"]
      }

      retain_rule {
        count = 21
      }

      tags_to_add = {
        ManagedBy        = "Terraform"
        CreatedBy        = "DLM_TF"
        Backup_Frequency = "Daily"
        Environment      = var.environment
      }

      dynamic "cross_region_copy_rule" {
        for_each = var.enable_cross_region_copy ? [1] : []

        content {
          target    = var.dr_region
          encrypted = true
          cmk_arn   = aws_kms_key.dlm_cross_region_copy.arn
          copy_tags = true

          retain_rule {
            interval      = var.retention_counts.dr_retention_days
            interval_unit = "DAYS"
          }
        }
      }

      copy_tags = true

    }

    target_tags = {
      BackupEnabled = "true"
    }
  }
  tags = merge(
    var.common_tags,
    {
      Name       = "${var.project_name}-${var.environment}-standard-snapshot-policy"
      PolicyType = "Snapshot"
      Frequency  = "Daily"
    }
  )
  depends_on = [aws_kms_key.dlm_primary_copy, aws_kms_key.dlm_cross_region_copy]
}