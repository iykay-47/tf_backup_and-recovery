# Daily AMI backup policy for critical and daily-tagged instances
resource "aws_dlm_lifecycle_policy" "critical_ami" {
  description        = "Daily AMI backups for critical instances"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"


  policy_details {
    resource_types = ["INSTANCE"]
    policy_type    = "IMAGE_MANAGEMENT"

    target_tags = {
      BackupEnabled = "true"
      BackupPolicy  = "critical"
    }

    # Additional schedule for critical instances (12-hour backup)
    schedule {
      name = "Critical AMI Backup Schedule"

      create_rule {
        interval      = 12
        interval_unit = "HOURS"
        times         = ["02:00"] # Will run at 2 AM and 2 PM
      }
      retain_rule {
        count = 14 # Keep 7 days worth (2 per day)
      }

      tags_to_add = {
        BackupType    = "CriticalAMI"
        CreatedBy       = "DLM"
        BackupFrequency = "TwiceDaily"
        Environment     = var.environment
        ManagedBy = "Terraform"
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
      Name       = "${var.project_name}-${var.environment}-critical-ami-policy"
      PolicyType = "AMI"
      Frequency  = "TwiceDaily"
    }
  )

  depends_on = [aws_kms_key.dlm_primary_copy, aws_kms_key.dlm_cross_region_copy]
}
