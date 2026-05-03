# CloudWatch Dashboard for DLM backup monitoring
resource "aws_cloudwatch_dashboard" "dlm_backup" {
  dashboard_name = "${var.environment}-dlm-backup-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Header
      {
        type = "text"
        properties = {
          markdown = "# DLM Backup Monitoring Dashboard\nEnvironment: ${var.environment} | Primary Region: ${var.primary_region} | DR Region: ${var.dr_region}"
        }
        x      = 0
        y      = 0
        width  = 24
        height = 1
      },
      
      # Snapshot Creation Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "SnapshotsCreated", { stat = "Sum", label = "Snapshots Created" }],
            [".", "SnapshotsDeleted", { stat = "Sum", label = "Snapshots Deleted" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.primary_region
          title  = "Snapshot Activity (Last 24 Hours)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        x      = 0
        y      = 1
        width  = 12
        height = 6
      },
      
      # AMI Creation Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "ImagesCreated", { stat = "Sum", label = "AMIs Created" }],
            [".", "ImagesDeleted", { stat = "Sum", label = "AMIs Deleted" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.primary_region
          title  = "AMI Activity (Last 24 Hours)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        x      = 12
        y      = 1
        width  = 12
        height = 6
      },
      
      # Policy Execution Status
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "PolicyExecutionSuccess", { stat = "Sum", label = "Successful Executions" }],
            [".", "PolicyExecutionFailure", { stat = "Sum", label = "Failed Executions", color = "#d62728" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.primary_region
          title  = "DLM Policy Execution Status"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        x      = 0
        y      = 7
        width  = 12
        height = 6
      },
      
      # Cross-Region Copy Status
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "CrossRegionCopyInitiated", { stat = "Sum", label = "DR Copies Initiated" }],
            [".", "CrossRegionCopyCompleted", { stat = "Sum", label = "DR Copies Completed" }],
            [".", "CrossRegionCopyFailed", { stat = "Sum", label = "DR Copy Failures", color = "#d62728" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.primary_region
          title  = "Cross-Region Disaster Recovery Copies"
        }
        x      = 12
        y      = 7
        width  = 12
        height = 6
      },
      
      # Current Snapshot Count by Policy
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "SnapshotCount", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.primary_region
          title  = "Current Total Snapshots Managed by DLM"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        x      = 0
        y      = 13
        width  = 8
        height = 6
      },
      
      # Fast Snapshot Restore Status
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "FastSnapshotRestoreEnabled", { stat = "Sum", label = "FSR Enabled" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.primary_region
          title  = "Fast Snapshot Restore Usage"
        }
        x      = 8
        y      = 13
        width  = 8
        height = 6
      },
      
      # Storage Size Trend
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EBS", "VolumeReadBytes", { stat = "Average", visible = false }],
            ["...", { stat = "Sum", label = "Total Snapshot Storage (approx)" }]
          ]
          period = 86400
          stat   = "Sum"
          region = var.primary_region
          title  = "Storage Trend (7 Days)"
          view   = "timeSeries"
        }
        x      = 16
        y      = 13
        width  = 8
        height = 6
      },
      
      # Protected Instances Count
      {
        type = "number"
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", { stat = "SampleCount", label = "Protected Instances" }]
          ]
          period = 300
          region = var.primary_region
          title  = "Total Protected Instances"
        }
        x      = 0
        y      = 19
        width  = 6
        height = 3
      },
      
      # Last Backup Success
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "PolicyExecutionSuccess", { stat = "Sum" }]
          ]
          period = 3600
          stat   = "Sum"
          region = var.primary_region
          title  = "Backups (Last 24h)"
          view   = "singleValue"
        }
        x      = 6
        y      = 19
        width  = 6
        height = 3
      },
      
      # Failure Count
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "PolicyExecutionFailure", { stat = "Sum", color = "#d62728" }]
          ]
          period = 86400
          stat   = "Sum"
          region = var.primary_region
          title  = "Failures (Last 7 Days)"
          view   = "singleValue"
        }
        x      = 12
        y      = 19
        width  = 6
        height = 3
      },
      
      # DR Region Status
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DLM", "CrossRegionCopyCompleted", { stat = "Sum", region = var.dr_region }]
          ]
          period = 86400
          stat   = "Sum"
          region = var.dr_region
          title  = "DR Backups (Last 7 Days)"
          view   = "singleValue"
        }
        x      = 18
        y      = 19
        width  = 6
        height = 3
      }
    ]
  })

  depends_on = [
    # Ensure dashboard is created after policies exist
  ]
}

output "dashboard_name" {
  description = "Name of CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.dlm_backup.dashboard_name
}

output "dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.primary_region}#dashboards:name=${aws_cloudwatch_dashboard.dlm_backup.dashboard_name}"
}